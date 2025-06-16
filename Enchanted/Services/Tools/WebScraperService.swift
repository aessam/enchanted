import Foundation

final class WebScraperService: Sendable {
    static let shared = WebScraperService()

    func scrape(url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            return ""
        }
        let withoutTags = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return withoutTags.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
