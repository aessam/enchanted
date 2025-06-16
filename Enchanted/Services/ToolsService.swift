import Foundation

struct ToolCall: Codable, Sendable {
    let tool: String
    let arguments: [String: String]?
}

final class ToolsService: @unchecked Sendable {
    static let shared = ToolsService()
    private init() {}

    func handle(toolCall: ToolCall) async throws -> String {
        switch toolCall.tool {
        case "search":
            if let query = toolCall.arguments?["query"] {
                return try await search(query: query)
            }
            return "Missing search query"
        case "scrape":
            if let url = toolCall.arguments?["url"] {
                return try await scrape(urlString: url)
            }
            return "Missing url"
        case "datetime":
            return currentDateTime()
        default:
            return "Unknown tool \(toolCall.tool)"
        }
    }

    func search(query: String) async throws -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://duckduckgo.com/?q=\(encoded)") else {
            return "Invalid search query"
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { return "" }
        return stripHTML(html)
    }

    func scrape(urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else { return "Invalid URL" }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { return "" }
        return stripHTML(html)
    }

    func currentDateTime() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: Date())
    }

    private func stripHTML(_ html: String) -> String {
        return html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    }
}
