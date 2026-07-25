import SwiftUI

/// macOS System Settings-style "Software Update" screen: out-of-date mods plus SMAPI
/// startup errors, both surfaced via the sidebar's alert badge in MainView.
struct UpdatesView: View {
    @EnvironmentObject var modsStore: ModsStore
    @EnvironmentObject var localizationStore: LocalizationStore
    @Binding var currentTab: String

    @State private var viewingModDetails: Mod?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Out of date mods (Software Update style)
                if !modsStore.outOfDateMods.isEmpty {
                    ForEach(modsStore.outOfDateMods) { mod in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 16) {
                                // App Icon Fake
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                    Text(String(mod.name.prefix(2)).uppercased())
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.blue.opacity(0.8))
                                }
                                .frame(width: 56, height: 56)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mod.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text(mod.version)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)

                    Text(localizationStore.L(L10n.Updates.newUpdate))
                                        .font(.system(size: 12))
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(.top, 2)
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    Button(action: {
                                        if let url = URL(string: mod.url) { NSWorkspace.shared.open(url) }
                                    }) {
                                        Text(localizationStore.L(L10n.Updates.download))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 6)
                                            .background(Color.primary.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .pointingHandCursor()

                                    Button(action: {
                                        if let modItem = modsStore.mods.first(where: { $0.name == mod.name }) {
                                            viewingModDetails = modItem
                                        }
                                    }) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(localizationStore.L(L10n.Settings.nexusChangelog))
                                }
                            }

                            VStack(alignment: .leading, spacing: 16) {
                                Text(localizationStore.L(L10n.Updates.updateDescription))
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)

                                Text("\(localizationStore.L(L10n.Updates.visitWebsite)) [\(mod.url)](\(mod.url))")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .tint(.blue)

                                Button(action: {
                                    if let modItem = modsStore.mods.first(where: { $0.name == mod.name }) {
                                        viewingModDetails = modItem
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text(localizationStore.L(L10n.Settings.nexusChangelog))
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .pointingHandCursor()
                            }
                            .padding(.top, 8)
                        }
                        .padding(20)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(12)
                    }
                }

                // SMAPI Errors (More Storage Required style)
                if !modsStore.smapiErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 16))
                            let errorText = String(format: localizationStore.L(L10n.Updates.errorsFound), modsStore.smapiErrors.count)
                            Text(errorText)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: { currentTab = "Logs" }) {
                                Text(localizationStore.L(L10n.Updates.viewLogs))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandCursor()
                        }

                        Text(localizationStore.L(L10n.Updates.errorDescription))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)

                        ForEach(modsStore.smapiErrors, id: \.self) { error in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.secondary.opacity(0.5))
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 6)
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(12)
                }

            }
            .padding(20)
        }
        .sheet(item: $viewingModDetails) { modItem in
            ModDetailView(mod: modItem, initialTab: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
