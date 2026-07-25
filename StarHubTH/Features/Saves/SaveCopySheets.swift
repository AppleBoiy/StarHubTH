import SwiftUI

struct DuplicateSaveSheet: View {
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    let save: SaveGameInfo
    @Environment(\.dismiss) var dismiss

    @State private var newName: String = ""
    @State private var newFarm: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(localizationStore.L(L10n.Saves.duplicateTitle))
                .font(.headline)
            
            Form {
                TextField(localizationStore.L(L10n.Saves.newCharacterName), text: $newName)
                TextField(localizationStore.L(L10n.Saves.newFarmName), text: $newFarm)
            }
            .formStyle(.grouped)
            
            HStack(spacing: 12) {
                Spacer()
                Button(localizationStore.L(L10n.Saves.cancel)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(localizationStore.L(L10n.Saves.duplicate)) {
                    appCoordinator.duplicateSave(info: save, newName: newName, newFarm: newFarm)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350, height: 220)
        .onAppear {
            if newName.isEmpty {
                newName = "\(save.playerName) \(localizationStore.L(L10n.Saves.duplicateDefaultSuffix))"
                newFarm = save.farmName
            }
        }
    }
}

struct BranchBackupSheet: View {
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    let backup: SaveBackup
    @Environment(\.dismiss) var dismiss

    @State private var newName: String = ""
    @State private var newFarm: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(localizationStore.L(L10n.Saves.branchTitle))
                .font(.headline)
            
            Form {
                TextField(localizationStore.L(L10n.Saves.newCharacterName), text: $newName)
                TextField(localizationStore.L(L10n.Saves.newFarmName), text: $newFarm)
            }
            .formStyle(.grouped)
            
            HStack(spacing: 12) {
                Spacer()
                Button(localizationStore.L(L10n.Saves.cancel)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(localizationStore.L(L10n.Saves.branch)) {
                    appCoordinator.branchFromBackup(backup: backup, newName: newName, newFarm: newFarm)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350, height: 220)
        .onAppear {
            guard newName.isEmpty else { return }
            // Try parsing the original save name from the backup folder name
            let originalSaveName = String(backup.folderPath.lastPathComponent.split(separator: ".")[0])
            newName = "\(originalSaveName) \(localizationStore.L(L10n.Saves.branchDefaultSuffix))"

            // We don't easily have the farmName from SaveBackup directly unless we parse the XML of the backup.
            // Let's parse it! We can try reading the SaveGameInfo inside backup folder to pre-fill farm name.
            let saveGameInfoURL = backup.folderPath.appendingPathComponent("SaveGameInfo")
            var initialFarmName = localizationStore.L(L10n.Saves.branchDefaultFarm)
            if let content = try? String(contentsOf: saveGameInfoURL, encoding: .utf8) {
                let pattern = "(<farmName>)([^<]+)(</farmName>)"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..<content.endIndex, in: content)),
                   let swiftRange = Range(match.range(at: 2), in: content) {
                    initialFarmName = String(content[swiftRange])
                }
            }
            newFarm = initialFarmName
        }
    }
}
