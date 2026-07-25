import SwiftUI

struct SaveTimelineView: View {
    @EnvironmentObject var savesStore: SavesStore
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    let save: SaveGameInfo
    
    @State private var backups: [SaveBackup] = []
    @State private var backupToRestore: SaveBackup?
    @State private var showRestoreConfirm = false
    @State private var isHoveredReturn = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { savesStore.viewingSaveTimeline = nil }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text(localizationStore.L(L10n.Saves.saves))
                    }
                    .foregroundColor(isHoveredReturn ? .accentColor : .secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(isHoveredReturn ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isHoveredReturn = $0 }
                
                Spacer()
                
                Text(save.playerName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                // Backup Button
                Button(action: {
                    appCoordinator.createBackup(info: save)
                    loadBackups()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(localizationStore.L(L10n.Saves.backupLabel))
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.trailing, 8)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Content
            if backups.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(localizationStore.L(L10n.Saves.noBackups))
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(backups.indices, id: \.self) { index in
                            let backup = backups[index]
                            let isLast = index == backups.count - 1
                            
                            BackupRow(
                                backup: backup,
                                isLast: isLast,
                                onRestore: {
                                    backupToRestore = backup
                                    showRestoreConfirm = true
                                },
                                onDelete: {
                                    appCoordinator.deleteBackup(backup)
                                    loadBackups()
                                }
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            loadBackups()
        }
        .alert(isPresented: $showRestoreConfirm) {
            Alert(
                title: Text(localizationStore.L(L10n.Saves.confirmRestore)),
                message: Text(localizationStore.L(L10n.Saves.confirmRestoreMsg)),
                primaryButton: .destructive(Text(localizationStore.L(L10n.Saves.restore))) {
                    if let b = backupToRestore {
                        appCoordinator.restoreBackup(backup: b, info: save)
                    }
                },
                secondaryButton: .cancel(Text(localizationStore.L(L10n.Main.ok)))
            )
        }
        .sheet(item: $savesStore.backupToBranch) { backup in
            BranchBackupSheet(backup: backup)
        }
    }
    
    private func loadBackups() {
        backups = savesStore.listBackups(for: save)
    }
}

struct BackupRow: View {
    @EnvironmentObject var savesStore: SavesStore
    @EnvironmentObject var localizationStore: LocalizationStore
    let backup: SaveBackup
    let isLast: Bool
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var noteTag: String = ""
    @State private var noteText: String = ""
    @State private var isEditingNote = false

    let availableTags = ["", "⭐", "🏆", "🧪", "❤️", "💎", "📅"]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline line & dot
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 3)
                    .padding(.top, 4)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 2)
                }
            }
            .frame(width: 20)
            
            // Content Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if !noteTag.isEmpty && !isEditingNote {
                        Text(noteTag)
                            .font(.system(size: 14))
                    }
                    Text(relativeLabel)
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text(formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                if isEditingNote {
                    HStack {
                        Picker("", selection: $noteTag) {
                            ForEach(availableTags, id: \.self) { tag in
                                Text(tag.isEmpty ? "-" : tag).tag(tag)
                            }
                        }
                        .frame(width: 60)
                        
                        TextField(localizationStore.L(L10n.Saves.saveNote), text: $noteText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(localizationStore.L(L10n.Profiles.save)) {
                            savesStore.setNote(noteText, tag: noteTag, forSave: backup.folderPath.lastPathComponent)
                            isEditingNote = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                } else if !noteText.isEmpty {
                    Text(noteText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                }
                
                HStack {
                    Text(localizationStore.L(L10n.Saves.backupLabel))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // Actions
                    Button(action: { isEditingNote.toggle() }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
                    
                    Button(action: {
                        savesStore.backupToBranch = backup
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                            Text(localizationStore.L(L10n.Saves.branch))
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.green)
                    .padding(.trailing, 4)
                    
                    Button(action: onRestore) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                            Text(localizationStore.L(L10n.Saves.restore))
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red.opacity(0.7))
                    .padding(.leading, 8)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
            .padding(.bottom, isLast ? 20 : 16)
        }
        .onAppear {
            let note = savesStore.note(for: backup.folderPath.lastPathComponent)
            noteTag = note.tag
            noteText = note.note
        }
    }

    private var formattedDate: String {
        let formatter = localizationStore.makeDateFormatter(dateStyle: .medium)
        formatter.timeStyle = .short
        return formatter.string(from: backup.timestamp)
    }
    
    private var relativeLabel: String {
        let seconds = Date().timeIntervalSince(backup.timestamp)
        if seconds < 60 {
            return localizationStore.L(L10n.Saves.relativeJustNow)
        }
        if seconds < 3600 {
            return String(format: localizationStore.L(L10n.Saves.relativeMinutesAgo), Int64(seconds / 60))
        }
        if seconds < 86400 {
            return String(format: localizationStore.L(L10n.Saves.relativeHoursAgo), Int64(seconds / 3600))
        }
        return String(format: localizationStore.L(L10n.Saves.relativeDaysAgo), Int64(seconds / 86400))
    }
}
