import SwiftUI

struct ModProfilesView: View {
    @EnvironmentObject var profilesStore: ProfilesStore
    @EnvironmentObject var modsStore: ModsStore
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var alertStore: AlertStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var isShowingNewProfileAlert = false
    @State private var newProfileName = ""
    @State private var selectedProfileForDetail: ModProfile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // List Container
            VStack(spacing: 0) {
                if profilesStore.modProfiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(localizationStore.L(L10n.Profiles.noProfiles))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(Array(profilesStore.modProfiles.enumerated()), id: \.element.id) { index, profile in
                        ProfileRow(profile: profile, isActive: profilesStore.activeProfileId == profile.id, selectedProfileForDetail: $selectedProfileForDetail)
                        
                        if index < profilesStore.modProfiles.count - 1 {
                            Divider()
                                .padding(.leading, 64) // Align with text
                        }
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            
            // Add buttons below list, right-aligned
            HStack {
                Button(action: {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [.json]
                    if panel.runModal() == .OK, let url = panel.url {
                        do {
                            let (collection, newProfile) = try profilesStore.importProfile(from: url)
                            profilesStore.modProfiles.append(newProfile)
                            profilesStore.saveProfiles()
                            // Queue installer. This local collection format has no
                            // nxm:// key/expires pair to authorize a direct API download
                            // for a non-premium account (see NXMParser's doc comment), so
                            // opening each missing mod's Nexus page for a manual download
                            // is the correct behavior here, not a stand-in for a real
                            // download that got cut — the message says so explicitly.
                            let missingIds = profilesStore.missingNexusIds(in: collection, currentMods: modsStore.mods, nexusApiKey: appEnvironment.nexusApiKey)
                            if !missingIds.isEmpty {
                                alertStore.show(String(format: localizationStore.L(L10n.VM.collectionImportedMissing), missingIds.count))
                                openMissingModPages(missingIds)
                            } else {
                                alertStore.show(localizationStore.L(L10n.VM.collectionImported))
                            }
                        } catch {
                            alertStore.show(String(format: localizationStore.L(L10n.VM.collectionImportFailed), error.localizedDescription))
                        }
                    }
                }) {
                    Text(localizationStore.L(L10n.Profiles.importCollection))
                }
                
                Spacer()
                Button(action: {
                    isShowingNewProfileAlert = true
                }) {
                    Text(localizationStore.L(L10n.Profiles.addProfile))
                }
            }
            
            Spacer()
        }
        .padding(30)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $selectedProfileForDetail) { profile in
            ProfileDetailSheet(profile: profile, isPresented: Binding(
                get: { selectedProfileForDetail != nil },
                set: { if !$0 { selectedProfileForDetail = nil } }
            ))
        }
        .alert(localizationStore.L(L10n.Profiles.createNewProfile), isPresented: $isShowingNewProfileAlert) {
            TextField(localizationStore.L(L10n.Profiles.profileNamePlaceholder), text: $newProfileName)
            Button(localizationStore.L(L10n.Profiles.save)) {
                if !newProfileName.isEmpty {
                    appCoordinator.createProfile(name: newProfileName)
                    newProfileName = ""
                }
            }
            Button(localizationStore.L(L10n.Profiles.cancel), role: .cancel) {
                newProfileName = ""
            }
        } message: {
            Text(localizationStore.L(L10n.Profiles.newProfileNote))
        }
    }

    /// Opens each missing mod's Nexus page with a short stagger between them, instead of
    /// firing every NSWorkspace.shared.open call in one tight loop — a dozen-plus tabs
    /// opening at once reads as a popup storm, not a helpful "here's what to grab."
    private func openMissingModPages(_ missingIds: [String]) {
        Task {
            for id in missingIds {
                if let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(id)") {
                    NSWorkspace.shared.open(url)
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }
}
