//
//  OllamaService.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 09/12/2023.
//

import Foundation
import OllamaKit

class OllamaService: @unchecked Sendable {
    static let shared = OllamaService()
    
    var ollamaKit: OllamaKit
    
    init() {
        ollamaKit = OllamaKit(baseURL: URL(string: "http://localhost:11434")!)
        initEndpoint()
    }
    
    func initEndpoint(url: String? = nil, bearerToken: String? = "okki") {
        let defaultUrl = "http://localhost:11434"
        let localStorageUrl = UserDefaults.standard.string(forKey: "ollamaUri")
        let bearerToken = UserDefaults.standard.string(forKey: "ollamaBearerToken")
        if var ollamaUrl = [localStorageUrl, defaultUrl].compactMap({$0}).filter({$0.count > 0}).first {
            if !ollamaUrl.contains("http") {
                ollamaUrl = "http://" + ollamaUrl
            }
            
            if let url = URL(string: ollamaUrl) {
                ollamaKit =  OllamaKit(baseURL: url, bearerToken: bearerToken)
                return
            }
        }
    }
    
    func getModels() async throws -> [LanguageModel]  {
        let response = try await ollamaKit.models()
        let models = response.models.map{
            LanguageModel(
                name: $0.name,
                provider: .ollama,
                imageSupport: $0.details.families?.contains(where: { $0 == "clip" || $0 == "mllama" }) ?? false,
                // Assuming newer versions of certain models support tool calling
                toolSupport: isToolSupportedModel($0.name)
            )
        }
        return models
    }
    
    // Helper function to determine if a model likely supports tool calling
    private func isToolSupportedModel(_ name: String) -> Bool {
        let toolSupportedModels = ["llama3", "mixtral", "phi3", "gemma"]
        let lowercaseName = name.lowercased()
        
        return toolSupportedModels.contains { lowercaseName.contains($0) }
    }
    
    func reachable() async -> Bool {
        return await ollamaKit.reachable()
    }
}
