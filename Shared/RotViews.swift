import SwiftUI

extension [TrackedApp] {
    /// Longest rot first, never-seen at the top, in-use at the bottom.
    var byRot: [TrackedApp] {
        sorted { ($0.isRunning ? .distantFuture : $0.lastQuit ?? .distantPast)
               < ($1.isRunning ? .distantFuture : $1.lastQuit ?? .distantPast) }
    }
}

/// HH:MM:SS into the current day. Live in widgets; frozen at `now` in exported images.
struct Clock: View {
    let elapsed: Elapsed
    let now: Date
    let live: Bool

    var body: some View {
        if live {
            Text(timerInterval: elapsed.dayStart...Date.distantFuture, countsDown: false, showsHours: true)
        } else {
            let s = max(0, Int(now.timeIntervalSince(elapsed.dayStart)))
            Text(String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60))
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

/// The Rot Counter icon, saved to the shared container by the app at launch.
struct BrandMark: View {
    let size: CGFloat
    var body: some View {
        if let image = NSImage(contentsOf: Store.brandIconURL) {
            Image(nsImage: image).resizable().frame(width: size, height: size)
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
    var live = true

    var body: some View {
        let elapsed = app.lastQuit.map { Elapsed(since: $0, now: now) }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                AppIcon(app: app, days: elapsed?.days ?? 0, size: 30)
                Spacer()
                BrandMark(size: 18).opacity(0.85)
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
                Clock(elapsed: elapsed, now: now, live: live)
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
    var live = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showHeader {
                HStack(spacing: 6) {
                    BrandMark(size: 16)
                    Text("ROT COUNTER").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.bottom, 8)
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
                Clock(elapsed: elapsed, now: now, live: live)
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
