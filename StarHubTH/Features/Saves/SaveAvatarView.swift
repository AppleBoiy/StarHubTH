import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Shared avatar renderer, sourcing the icon path from `SavesStore` via `folderName`.
struct SaveAvatarView: View {
    let folderName: String
    let size: CGFloat
    @EnvironmentObject var savesStore: SavesStore

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
        let iconPath = savesStore.note(for: folderName).customIconPath ?? ""

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
