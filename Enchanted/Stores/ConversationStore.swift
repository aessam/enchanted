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
    private var pendingToolCalls: [ToolCall] = []
    private var toolCallsEnabled: Bool = true
    
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
        // Load tool calling setting from UserDefaults (default to true if not set)
        if UserDefaults.standard.object(forKey: "toolCallingEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "toolCallingEnabled")
        }
        self.toolCallsEnabled = UserDefaults.standard.bool(forKey: "toolCallingEnabled")
    }
    
    @MainActor
    func toggleToolCalling(_ enabled: Bool) {
        toolCallsEnabled = enabled
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
                    if self.toolCallsEnabled {
                        // Use tool calling
                        let tools = ToolCallService.shared.getAvailableTools()
                        self.generation = OllamaService.shared.chatWithTools(
                            model: model.name,
                            messages: messageHistory,
                            tools: tools,
                            temperature: 0
                        )
                        .sink(receiveCompletion: { [weak self] completion in
                            switch completion {
                            case .finished:
                                self?.handleComplete()
                            case .failure(let error):
                                self?.handleError(error.localizedDescription)
                            }
                        }, receiveValue: { [weak self] response in
                            self?.handleReceiveWithTools(response)
                        })
                    } else {
                        // Use regular chat without tools
                        var request = OKChatRequestData(model: model.name, messages: messageHistory)
                        request.options = OKCompletionOptions(temperature: 0)
                        
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
                }
            } else {
                self.handleError("Server unreachable")
            }
        }
    }
    
    @MainActor
    private func handleReceive(_ response: OKChatResponse)  {
        if messages.isEmpty { return }
        
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
    private func handleReceiveWithTools(_ response: OKChatResponse) {
        if messages.isEmpty { return }
        
        if let responseContent = response.message?.content {
            currentMessageBuffer = currentMessageBuffer + responseContent
            
            throttler.throttle { [weak self] in
                guard let self = self else { return }
                let lastIndex = self.messages.count - 1
                self.messages[lastIndex].content.append(currentMessageBuffer)
                currentMessageBuffer = ""
                
                // Check if the response is complete (indicated by response.done)
                if response.done {
                    self.processToolCallsIfPresent()
                }
            }
        }
    }
    
    @MainActor
    private func processToolCallsIfPresent() {
        guard let lastMessage = messages.last else { return }
        
        let parsedResponse = ToolCallParser.shared.parseResponse(lastMessage.content)
        
        if parsedResponse.hasToolCalls {
            // Store the original content and tool calls
            pendingToolCalls = parsedResponse.toolCalls
            
            // Update the message content to remove tool call JSON
            lastMessage.content = parsedResponse.content
            
            // Execute tool calls
            Task {
                await executeToolCalls(parsedResponse.toolCalls)
            }
        }
    }
    
    private func executeToolCalls(_ toolCalls: [ToolCall]) async {
        var toolResults: [ToolCallResult] = []
        
        // Execute all tool calls
        for toolCall in toolCalls {
            let result = await ToolCallService.shared.executeToolCall(toolCall)
            toolResults.append(result)
        }
        
        // Create a tool result message to send back to the model
        let toolResultsMessage = createToolResultsMessage(toolResults)
        
        // Send the tool results back to the model for final response
        await sendToolResults(toolResultsMessage)
    }
    
    private func createToolResultsMessage(_ results: [ToolCallResult]) -> String {
        var resultMessage = "Tool execution results:\n\n"
        
        for result in results {
            if let error = result.error {
                resultMessage += "Tool call failed: \(error)\n"
            } else {
                resultMessage += "\(result.result)\n"
            }
        }
        
        resultMessage += "\nPlease provide a natural response based on these results."
        return resultMessage
    }
    
    @MainActor
    private func sendToolResults(_ toolResultsMessage: String) async {
        guard let conversation = selectedConversation,
              let model = conversation.model else { return }
        
        // Create a tool result message (internal, not displayed to user)
        let toolMessage = MessageSD(content: toolResultsMessage, role: "user")
        toolMessage.conversation = conversation
        
        // Prepare message history including the tool results
        var messageHistory = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { OKChatRequestData.Message(role: OKChatRequestData.Message.Role(rawValue: $0.role) ?? .assistant, content: $0.content) }
        
        // Add the tool results message
        messageHistory.append(OKChatRequestData.Message(role: .user, content: toolResultsMessage))
        
        // Create a new assistant message for the final response
        let finalAssistantMessage = MessageSD(content: "", role: "assistant")
        finalAssistantMessage.conversation = conversation
        
        do {
            try await swiftDataService.createMessage(finalAssistantMessage)
            try await reloadConversation(conversation)
            
            if await OllamaService.shared.ollamaKit.reachable() {
                DispatchQueue.global(qos: .background).async {
                    // Send without tool definitions for the final response
                    var request = OKChatRequestData(model: model.name, messages: messageHistory)
                    request.options = OKCompletionOptions(temperature: 0)
                    
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
                handleError("Server unreachable")
            }
        } catch {
            handleError("Failed to process tool results: \(error.localizedDescription)")
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
}
