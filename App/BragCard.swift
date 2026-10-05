import SwiftUI

/// The shareable image: same look as the large widget, frozen at the moment of export.
struct BragCard: View {
    let apps: [TrackedApp]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROT COUNTER").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Since I last opened…").font(.system(size: 17, weight: .semibold))
                }
            }
            Leaderboard(apps: apps, now: now, showHeader: false, live: false)
                .frame(height: CGFloat(apps.count) * 46)
            Text("\(now.formatted(date: .abbreviated, time: .shortened)) · github.com/binikingi/rot-counter")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.35))
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(width: 460)
        .background(Glow(app: apps.first))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

@MainActor
func exportBragCard(_ apps: [TrackedApp]) {
    let renderer = ImageRenderer(content: BragCard(apps: apps.byRot, now: .now))
    renderer.scale = 2
    guard let image = renderer.cgImage,
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }

    let panel = NSSavePanel()
    panel.nameFieldStringValue = "rot-counter.png"
    panel.allowedContentTypes = [.png]
    NSApp.activate()
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do { try png.write(to: url) } catch { NSAlert(error: error).runModal() }
}
