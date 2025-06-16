import Foundation

struct DuckDuckGoResponse: Decodable {
    let AbstractText: String
}

final class SearchService: Sendable {
    static let shared = SearchService()

    func search(query: String) async throws -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try? JSONDecoder().decode(DuckDuckGoResponse.self, from: data)
        return response?.AbstractText.isEmpty == false ? response!.AbstractText : "No results found."
    }
}
