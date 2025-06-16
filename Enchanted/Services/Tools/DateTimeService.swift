import Foundation

final class DateTimeService: Sendable {
    static let shared = DateTimeService()

    func currentDateTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
}
