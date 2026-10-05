import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Configuration (pick which app a small widget shows)

struct AppChoice: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "App"
    static let defaultQuery = AppChoiceQuery()
    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct AppChoiceQuery: EntityQuery {
    func entities(for ids: [String]) async throws -> [AppChoice] {
        try await suggestedEntities().filter { ids.contains($0.id) }
    }
    func suggestedEntities() async throws -> [AppChoice] {
        Store.load().map { AppChoice(id: $0.bundleID, name: $0.name) }
    }
}

struct SelectApp: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose App"
    static let description = IntentDescription("Small widgets show this app. Leave empty for the longest-rotting one.")
    @Parameter(title: "App") var app: AppChoice?
}

// MARK: - Timeline

struct Entry: TimelineEntry {
    let date: Date
    let apps: [TrackedApp]  // sorted, longest rot first
    let selected: String?
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, apps: [TrackedApp(bundleID: "x", name: "VS Code", path: "",
                                            lastQuit: .now.addingTimeInterval(-23 * 86_400 - 15_157))], selected: nil)
    }

    func snapshot(for config: SelectApp, in context: Context) async -> Entry {
        let apps = sorted(Store.load())
        return apps.isEmpty ? placeholder(in: context) : Entry(date: .now, apps: apps, selected: config.app?.id)
    }

    /// One entry now, plus one at each app's next day boundary: that's when a day count ticks over.
    /// Between entries the HH:MM:SS is a self-updating Text timer, so no per-second reloads.
    func timeline(for config: SelectApp, in context: Context) async -> Timeline<Entry> {
        let apps = sorted(Store.load())
        let boundaries = apps.filter { !$0.isRunning }.compactMap { $0.lastQuit.map { Elapsed(since: $0).nextDay } }
        let dates = [Date.now] + Set(boundaries).sorted()
        return Timeline(entries: dates.map { Entry(date: $0, apps: apps, selected: config.app?.id) }, policy: .atEnd)
    }

    private func sorted(_ apps: [TrackedApp]) -> [TrackedApp] {
        apps.sorted { rank($0) < rank($1) }
    }

    private func rank(_ a: TrackedApp) -> Date {
        a.isRunning ? .distantFuture : a.lastQuit ?? .distantPast
    }
}

// MARK: - Views

struct RotWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        Group {
            if entry.apps.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "hourglass").font(.title)
                    Text("Add apps from the menu bar").font(.caption).multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.6))
            } else if family == .systemSmall {
                Hero(app: entry.apps.first { $0.bundleID == entry.selected } ?? entry.apps[0], now: entry.date)
            } else {
                Leaderboard(apps: Array(entry.apps.prefix(family == .systemLarge ? 7 : 3)), now: entry.date,
                            showHeader: family == .systemLarge)
            }
        }
        .containerBackground(for: .widget) {
            Glow(app: family == .systemSmall ? entry.apps.first { $0.bundleID == entry.selected } ?? entry.apps.first
                                              : entry.apps.first)
        }
    }
}

/// Near-black with a soft glow in the hero app's icon color.
struct Glow: View {
    let app: TrackedApp?
    var body: some View {
        ZStack {
            Color(white: 0.06)
            if let app {
                RadialGradient(colors: [Color(hue: app.hue, saturation: app.saturation, brightness: 0.7).opacity(0.45), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 220)
            }
        }
    }
}

struct AppIcon: View {
    let app: TrackedApp
    let days: Int
    let size: CGFloat
    var body: some View {
        Group {
            if let image = NSImage(contentsOf: Store.iconURL(app.bundleID)) {
                Image(nsImage: image).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: size, height: size)
        .saturation(app.isRunning ? 1 : max(0, 1 - Double(days) / 30))  // the "rot": greys out over a month
    }
}

struct Hero: View {
    let app: TrackedApp
    let now: Date

    var body: some View {
        let elapsed = app.lastQuit.map { Elapsed(since: $0, now: now) }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                AppIcon(app: app, days: elapsed?.days ?? 0, size: 30)
                Spacer()
                if app.isRunning { Circle().fill(.red).frame(width: 7, height: 7) }
            }
            Spacer(minLength: 4)
            if app.isRunning {
                Text("IN USE").font(.system(size: 30, weight: .heavy, design: .rounded))
                Text("busted").font(.caption.weight(.medium)).foregroundStyle(.red.opacity(0.85))
            } else if let elapsed {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(elapsed.days)")
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.5)
                    Text(elapsed.days == 1 ? "DAY" : "DAYS")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.5)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text(timerInterval: elapsed.dayStart...Date.distantFuture, countsDown: false, showsHours: true)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            } else {
                Text("NEVER").font(.system(size: 30, weight: .heavy, design: .rounded))
            }
            Text("since \(app.name)")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                .lineLimit(1).padding(.top, 2)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Leaderboard: View {
    let apps: [TrackedApp]
    let now: Date
    let showHeader: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showHeader {
                Text("ROT COUNTER").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2)
                    .foregroundStyle(.white.opacity(0.45)).padding(.bottom, 10)
            }
            ForEach(apps) { app in
                row(app)
                if app.id != apps.last?.id { Divider().overlay(.white.opacity(0.08)) }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }

    private func row(_ app: TrackedApp) -> some View {
        let elapsed = app.lastQuit.map { Elapsed(since: $0, now: now) }
        return HStack(spacing: 10) {
            AppIcon(app: app, days: elapsed?.days ?? 0, size: 24)
            Text(app.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Spacer()
            if app.isRunning {
                Text("IN USE").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(.red.opacity(0.9))
            } else if let elapsed {
                Text("\(elapsed.days)d")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text(timerInterval: elapsed.dayStart...Date.distantFuture, countsDown: false, showsHours: true)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 62, alignment: .trailing)
            } else {
                Text("never").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Widget

@main
struct RotWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "RotWidget", intent: SelectApp.self, provider: Provider()) { entry in
            RotWidgetView(entry: entry)
        }
        .configurationDisplayName("Rot Counter")
        .description("Time since you last opened the apps AI replaced.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
