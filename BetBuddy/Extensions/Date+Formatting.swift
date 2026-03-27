import Foundation

extension Date {
    var betDeadlineText: String {
        let now = Date()
        let interval = timeIntervalSince(now)

        if interval <= 0 {
            return "Closed"
        }

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 60 {
            return "\(minutes)m left"
        } else if hours < 24 {
            return "\(hours)h left"
        } else if days < 7 {
            return "\(days)d left"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: self)
        }
    }

    var relativeDateText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
