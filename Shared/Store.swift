import Foundation

struct TrackedApp: Codable, Hashable, Identifiable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
    let path: String
    var lastQuit: Date?  // nil = never seen used
    var isRunning = false
    var hue = 0.0  // dominant icon color, for the widget glow
    var saturation = 0.0
}

/// Both the app and the widget read/write the same JSON file in the shared App Group container.
enum Store {
    static let dir: URL = {
        let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as! String
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)!
    }()
    static let file = dir.appending(path: "apps.json")

    static func load() -> [TrackedApp] {
        (try? JSONDecoder().decode([TrackedApp].self, from: Data(contentsOf: file))) ?? []
    }

    static func save(_ apps: [TrackedApp]) {
        do { try JSONEncoder().encode(apps).write(to: file, options: .atomic) }
        catch { NSLog("RotCounter: save failed: \(error)") }
    }

    static func iconURL(_ bundleID: String) -> URL { dir.appending(path: "\(bundleID).png") }
    static let brandIconURL = dir.appending(path: "RotCounter.png")  // our own icon; the widget can't read the app bundle
}
