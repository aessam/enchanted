//
//  ChatsStore.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 10/12/2023.
//

import Foundation
import SwiftData
import OllamaKit
import Combine
import SwiftUI

@Observable
final class ConversationStore: Sendable {
    static let shared = ConversationStore(swiftDataService: SwiftDataService.shared)
    
    private var swiftDataService: SwiftDataService
    private var generation: AnyCancellable?
    
    /// For some reason (SwiftUI bug / too frequent UI updates) updating UI for each stream message sometimes freezes the UI.
    /// Throttling UI updates seem to fix the issue.
    private var currentMessageBuffer: String = ""
#if os(macOS)
    private let throttler = Throttler(delay: 0.1)
#else
    private let throttler = Throttler(delay: 0.1)
#endif
    
    @MainActor var conversationState: ConversationState = .completed
    @MainActor var conversations: [ConversationSD] = []
    @MainActor var selectedConversation: ConversationSD?
    @MainActor var messages: [MessageSD] = []
    
    init(swiftDataService: SwiftDataService) {
        self.swiftDataService = swiftDataService
    }
    
    func loadConversations() async throws {
        print("loading conversations")
        let fetchedConversations = try await swiftDataService.fetchConversations()
        DispatchQueue.main.async {
            self.conversations = fetchedConversations
        }
        print("loaded conversations")
    }
    
    func deleteAllConversations() {
        Task {
            DispatchQueue.main.async { [weak self] in
                self?.messages = []
                self?.selectedConversation = nil
            }
            try? await swiftDataService.deleteConversations()
            try? await swiftDataService.deleteMessages()
            try? await loadConversations()
        }
    }
    
    func deleteDailyConversations(_ date: Date) {
        Task {
            DispatchQueue.main.async { [self] in
                selectedConversation = nil
                messages = []
            }
            try? await swiftDataService.deleteConversations()
            try? await loadConversations()
        }
    }
    
    
    func create(_ conversation: ConversationSD) async throws {
        try await swiftDataService.createConversation(conversation)
    }
    
    func reloadConversation(_ conversation: ConversationSD) async throws {
        let (messages, selectedConversation) = try await (
            swiftDataService.fetchMessages(conversation.id),
            swiftDataService.getConversation(conversation.id)
        )
        
        DispatchQueue.main.async {
                self.messages = messages
                self.selectedConversation = selectedConversation
        }
    }
    
    func selectConversation(_ conversation: ConversationSD) async throws {
        try await reloadConversation(conversation)
    }
    
    func delete(_ conversation: ConversationSD) async throws {
        try await swiftDataService.deleteConversation(conversation)
        let fetchedConversations = try await swiftDataService.fetchConversations()
        DispatchQueue.main.async {
            self.selectedConversation = nil
            self.conversations = fetchedConversations
        }
    }
    
    @MainActor func stopGenerate() {
        generation?.cancel()
        handleComplete()
        withAnimation {
            conversationState = .completed
        }
    }
    
    @MainActor
    func sendPrompt(userPrompt: String, model: LanguageModelSD, image: Image? = nil, systemPrompt: String = "", trimmingMessageId: String? = nil) {
        guard userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 else { return }
        
        let conversation = selectedConversation ?? ConversationSD(name: userPrompt)
        conversation.updatedAt = Date.now
        conversation.model = model
        
        print("model", model.name)
        print("conversation", conversation.name)
        
        /// trim conversation if on edit mode
        if let trimmingMessageId = trimmingMessageId {
            conversation.messages = conversation.messages
                .sorted{$0.createdAt < $1.createdAt}
                .prefix(while: {$0.id.uuidString != trimmingMessageId})
        }
        
        /// add system prompt to very first message in the conversation
        if !systemPrompt.isEmpty && conversation.messages.isEmpty {
            let systemMessage = MessageSD(content: systemPrompt, role: "system")
            systemMessage.conversation = conversation
        }
        
        /// construct new message
        let userMessage = MessageSD(content: userPrompt, role: "user", image: image?.render()?.compressImageData())
        userMessage.conversation = conversation
        
        /// prepare message history for Ollama
        var messageHistory = conversation.messages
            .sorted{$0.createdAt < $1.createdAt}
            .map{OKChatRequestData.Message(role: OKChatRequestData.Message.Role(rawValue: $0.role) ?? .assistant, content: $0.content)}
        
        
        print(messageHistory.map({$0.content}))
        
        /// attach selected image to the last Message
        if let image = image?.render() {
            if let lastMessage = messageHistory.popLast() {
                let imagesBase64: [String] = [image.convertImageToBase64String()]
                let messageWithImage = OKChatRequestData.Message(role: lastMessage.role, content: lastMessage.content, images: imagesBase64)
                messageHistory.append(messageWithImage)
            }
        }
        
        let assistantMessage = MessageSD(content: "", role: "assistant")
        assistantMessage.conversation = conversation
        
        conversationState = .loading
        
        Task {
            try await swiftDataService.updateConversation(conversation)
            try await swiftDataService.createMessage(userMessage)
            try await swiftDataService.createMessage(assistantMessage)
            try await reloadConversation(conversation)
            try? await loadConversations()
            
            if await OllamaService.shared.ollamaKit.reachable() {
                DispatchQueue.global(qos: .background).async {
                    var request = OKChatRequestData(model: model.name, messages: messageHistory)
                    request.options = OKCompletionOptions(temperature: 0)
                    
                    // Add tools if the model supports them
                    if model.supportsTools {
                        request.tools = Tool.availableTools
                    }
                    
                    self.generation = OllamaService.shared.ollamaKit.chat(data: request)
                        .sink(receiveCompletion: { [weak self] completion in
                            switch completion {
                            case .finished:
                                self?.handleComplete()
                            case .failure(let error):
                                self?.handleError(error.localizedDescription)
                            }
                        }, receiveValue: { [weak self] response in
                            self?.handleReceive(response)
                        })
                    
                }
            } else {
                self.handleError("Server unreachable")
            }
        }
    }
    
    @MainActor
    private func handleReceive(_ response: OKChatResponse)  {
        if messages.isEmpty { return }
        
        // Check for tool calls in the response
        if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
            // Process tool calls if the message is done
            if response.done ?? false {
                guard let lastMessage = messages.last else { return }
                processToolCallsIfNeeded(lastMessage, toolCalls)
            }
        }
        
        if let responseContent = response.message?.content {
            currentMessageBuffer = currentMessageBuffer + responseContent
            
            throttler.throttle { [weak self] in
                guard let self = self else { return }
                let lastIndex = self.messages.count - 1
                self.messages[lastIndex].content.append(currentMessageBuffer)
                currentMessageBuffer = ""
            }
        }
    }
    
    @MainActor
    private func handleError(_ errorMessage: String) {
        guard let lastMesasge = messages.last else { return }
        lastMesasge.error = true
        lastMesasge.done = false
        
        Task(priority: .background) {
            try? await swiftDataService.updateMessage(lastMesasge)
        }
        
        withAnimation {
            conversationState = .error(message: errorMessage)
        }
    }
    
    @MainActor
    private func handleComplete() {
        guard let lastMesasge = messages.last else { return }
        lastMesasge.error = false
        lastMesasge.done = true
        
        Task(priority: .background) {
            try await self.swiftDataService.updateMessage(lastMesasge)
        }
        
        withAnimation {
            conversationState = .completed
        }
    }
    
    // Process any tool calls received from the model
    private func executeToolCalls(_ toolCalls: [ToolCall]) -> [ToolCallResult] {
        return toolCalls.map { toolCall in
            switch toolCall.name {
            case Tool.timeTools.name:
                let result = TimeTools.shared.handleTimeToolCall(toolCall.parsedArguments)
                return ToolCallResult(toolCall: toolCall, response: result)
                
            case Tool.dateTools.name:
                let result = DateTools.shared.handleDateToolCall(toolCall.parsedArguments)
                return ToolCallResult(toolCall: toolCall, response: result)
                
            default:
                return ToolCallResult(toolCall: toolCall, response: "Error: Unknown tool")
            }
        }
    }
    
    // Handle tool calls in the message
    @MainActor
    private func processToolCallsIfNeeded(_ message: MessageSD, _ toolCalls: [ToolCall]?) {
        guard let toolCalls = toolCalls, !toolCalls.isEmpty else { return }
        
        message.storeToolCalls(toolCalls)
        
        Task {
            // Execute tool calls
            let results = executeToolCalls(toolCalls)
            
            // Store results in the message
            message.storeToolResults(results)
            
            // Update the message in the database
            try await self.swiftDataService.updateMessage(message)
            
            // Continue the conversation with tool results
            await continueConversationWithToolResults(message.conversation!, message, results)
        }
    }
    
    // Continue the conversation by sending tool results back to the model
    @MainActor
    private func continueConversationWithToolResults(_ conversation: ConversationSD, _ previousMessage: MessageSD, _ toolResults: [ToolCallResult]) {
        guard let model = conversation.model, toolResults.count > 0 else { return }
        
        // Prepare message history including previous messages and tool results
        var messageHistory = conversation.messages
            .sorted{$0.createdAt < $1.createdAt}
            .filter{$0.id != previousMessage.id} // Filter out the message with pending tool calls
            .map{OKChatRequestData.Message(role: OKChatRequestData.Message.Role(rawValue: $0.role) ?? .assistant, content: $0.content)}
        
        // Add the previous assistant message that contains tool calls
        messageHistory.append(OKChatRequestData.Message(
            role: .assistant,
            content: previousMessage.content
        ))
        
        // Add tool call results
        for result in toolResults {
            // Add tool response
            messageHistory.append(OKChatRequestData.Message(
                role: .tool,
                content: result.response,
                name: result.toolCall.name
            ))
        }
        
        // Create a new message for the assistant's response
        let assistantMessage = MessageSD(content: "", role: "assistant")
        assistantMessage.conversation = conversation
        
        conversationState = .loading
        
        Task {
            try await swiftDataService.createMessage(assistantMessage)
            try await reloadConversation(conversation)
            
            if await OllamaService.shared.ollamaKit.reachable() {
                DispatchQueue.global(qos: .background).async {
                    // Create request with tool calling enabled
                    var request = OKChatRequestData(model: model.name, messages: messageHistory)
                    request.options = OKCompletionOptions(temperature: 0)
                    
                    // Add tools if the model supports them
                    if model.supportsTools {
                        request.tools = Tool.availableTools
                    }
                    
                    self.generation = OllamaService.shared.ollamaKit.chat(data: request)
                        .sink(receiveCompletion: { [weak self] completion in
                            switch completion {
                            case .finished:
                                self?.handleComplete()
                            case .failure(let error):
                                self?.handleError(error.localizedDescription)
                            }
                        }, receiveValue: { [weak self] response in
                            self?.handleReceive(response)
                        })
                }
            } else {
                self.handleError("Server unreachable")
            }
        }
    }
}
