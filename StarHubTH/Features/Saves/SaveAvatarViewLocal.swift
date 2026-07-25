import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Same rendering as `SaveAvatarView`, but the icon path comes from local `@State` instead
/// of `SavesStore` — used while editing, before a change is committed.
struct SaveAvatarViewLocal: View {
    let iconPath: String
    let size: CGFloat

    private let presets: [(String, String)] = [
        ("preset:person", "person.crop.circle.fill"),
        ("preset:star", "star.fill"),
        ("preset:leaf", "leaf.fill"),
        ("preset:heart", "heart.fill"),
        ("preset:cat", "cat.fill"),
        ("preset:dog", "dog.fill"),
        ("preset:hare", "hare.fill"),
        ("preset:ant", "ant.fill"),
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))

            if iconPath.hasPrefix("preset:") {
                let sfName = presets.first(where: { $0.0 == iconPath })?.1 ?? "person.crop.circle.fill"
                Image(systemName: sfName)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(Color.accentColor.opacity(0.8))
                    .padding(size * 0.18)
            } else if !iconPath.isEmpty, let img = NSImage(contentsOfFile: iconPath) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(Color.accentColor.opacity(0.8))
                    .frame(width: size * 0.8, height: size * 0.8)
            }
        }
        .frame(width: size, height: size)
    }
}
