import ServiceManagement
import SwiftUI

@main
struct RotCounterApp: App {
    @State private var tracker = Tracker()

    var body: some Scene {
        MenuBarExtra("Rot Counter", systemImage: "hourglass") {
            MenuContent(tracker: tracker)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContent: View {
    let tracker: Tracker
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rot Counter").font(.headline)

            if tracker.apps.isEmpty {
                Text("Add the apps AI made you forget.").foregroundStyle(.secondary)
            }
            ForEach(tracker.apps) { app in
                HStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                        .resizable().frame(width: 20, height: 20)
                    Text(app.name)
                    Spacer()
                    Group {
                        if app.isRunning { Text("in use") }
                        else if let quit = app.lastQuit { Text(quit, style: .relative) }
                        else { Text("never") }
                    }
                    .foregroundStyle(.secondary).monospacedDigit()
                    Button { tracker.remove(app) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.tertiary)
                }
            }

            Divider()
            Button("Add App…") { tracker.pick() }
            Button("Export Image…") { exportBragCard(tracker.apps) }
                .disabled(tracker.apps.isEmpty)
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                }
            Button("Quit Rot Counter") { NSApp.terminate(nil) }
        }
        .padding()
        .frame(width: 320)
    }
}
