import Foundation

/// Splits time since `start` into whole days plus the moment the current day began,
/// so the widget can show a static day count next to a live HH:MM:SS timer.
struct Elapsed {
    let days: Int
    let dayStart: Date
    var nextDay: Date { dayStart.addingTimeInterval(86_400) }

    init(since start: Date, now: Date = .now) {
        days = max(0, Int(now.timeIntervalSince(start) / 86_400))
        dayStart = start.addingTimeInterval(Double(days) * 86_400)
    }
}
