import Foundation

enum ToolCommand {
    case search(String)
    case scrape(URL)
    case time
}

final class ToolService: Sendable {
    static let shared = ToolService()

    func parse(_ prompt: String) -> ToolCommand? {
        if prompt.hasPrefix("/search ") {
            let query = String(prompt.dropFirst(8))
            return .search(query)
        }
        if prompt.hasPrefix("/scrape ") {
            let urlString = String(prompt.dropFirst(8))
            if let url = URL(string: urlString) {
                return .scrape(url)
            }
        }
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines) == "/time" {
            return .time
        }
        return nil
    }

    func run(command: ToolCommand) async -> String {
        switch command {
        case .search(let query):
            return (try? await SearchService.shared.search(query: query)) ?? "Failed to search"
        case .scrape(let url):
            return (try? await WebScraperService.shared.scrape(url: url)) ?? "Failed to scrape"
        case .time:
            return DateTimeService.shared.currentDateTimeString()
        }
    }
}
