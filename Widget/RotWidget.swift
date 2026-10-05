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
        let apps = Store.load().byRot
        return apps.isEmpty ? placeholder(in: context) : Entry(date: .now, apps: apps, selected: config.app?.id)
    }

    /// One entry now, plus one at each app's next day boundary: that's when a day count ticks over.
    /// Between entries the HH:MM:SS is a self-updating Text timer, so no per-second reloads.
    func timeline(for config: SelectApp, in context: Context) async -> Timeline<Entry> {
        let apps = Store.load().byRot
        let boundaries = apps.filter { !$0.isRunning }.compactMap { $0.lastQuit.map { Elapsed(since: $0).nextDay } }
        let dates = [Date.now] + Set(boundaries).sorted()
        return Timeline(entries: dates.map { Entry(date: $0, apps: apps, selected: config.app?.id) }, policy: .atEnd)
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
                            showHeader: true)
            }
        }
        .containerBackground(for: .widget) {
            Glow(app: family == .systemSmall ? entry.apps.first { $0.bundleID == entry.selected } ?? entry.apps.first
                                              : entry.apps.first)
        }
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
