import AppKit
import CoreServices
import ServiceManagement
import WidgetKit

@MainActor @Observable
final class Tracker {
    private(set) var apps = Store.load()

    init() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let id = Self.bundleID(n)
            MainActor.assumeIsolated { self?.update(id) { $0.isRunning = true } }
        }
        ws.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let id = Self.bundleID(n)
            MainActor.assumeIsolated { self?.update(id) { $0.isRunning = false; $0.lastQuit = .now } }
        }
        // ponytail: if we quit before a tracked app does, we stamp "now" as its quit time
        // (exact on logout/shutdown, slightly early if the user quits Rot Counter alone).
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                for i in self.apps.indices where self.apps[i].isRunning { self.apps[i].lastQuit = .now }
                Store.save(self.apps)
            }
        }
        reconcile()

        // A tracker that isn't running can't track: enable launch-at-login on first run.
        if !UserDefaults.standard.bool(forKey: "didSetupLogin") {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: "didSetupLogin")
        }
    }

    func pick() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(filePath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.prompt = "Track"
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(add)
        reconcile()
    }

    func remove(_ app: TrackedApp) {
        apps.removeAll { $0.bundleID == app.bundleID }
        try? FileManager.default.removeItem(at: Store.iconURL(app.bundleID))
        commit()
    }

    private func add(_ url: URL) {
        guard let id = Bundle(url: url)?.bundleIdentifier, !apps.contains(where: { $0.bundleID == id }) else { return }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        try? bitmap(icon, size: 128).representation(using: .png, properties: [:])?.write(to: Store.iconURL(id))
        let avg = bitmap(icon, size: 1).colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB)
        apps.append(TrackedApp(
            bundleID: id,
            name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
            path: url.path,
            hue: avg.map { Double($0.hueComponent) } ?? 0,
            saturation: avg.map { Double($0.saturationComponent) } ?? 0))
    }

    /// Syncs running state with reality and backfills quit times from Spotlight's "last used" date,
    /// so a freshly added app starts at its true count instead of zero.
    private func reconcile() {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        for i in apps.indices {
            apps[i].isRunning = running.contains(apps[i].bundleID)
            guard !apps[i].isRunning, let used = Self.lastUsed(apps[i].path) else { continue }
            apps[i].lastQuit = max(apps[i].lastQuit ?? .distantPast, used)
        }
        commit()
    }

    private func update(_ bundleID: String?, _ change: (inout TrackedApp) -> Void) {
        guard let i = apps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        change(&apps[i])
        commit()
    }

    private func commit() {
        Store.save(apps)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private nonisolated static func bundleID(_ n: Notification) -> String? {
        (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
    }

    private static func lastUsed(_ path: String) -> Date? {
        guard let item = MDItemCreate(nil, path as CFString) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }

    private func bitmap(_ image: NSImage, size: Int) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }
}
