import SwiftUI

/// Pannello delle preferenze persistenti dell'applicazione.
struct SettingsView: View {
    /// Tema scelto dall'utente, memorizzato come valore testuale.
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.dark.rawValue
    /// Bitrate MP3 selezionato.
    @AppStorage("mp3Quality") var mp3Quality: Int = 192
    /// Autorizza la sostituzione di file già esistenti.
    @AppStorage("overwriteExisting") var overwriteExisting: Bool = false
    /// Abilita le notifiche al termine delle conversioni.
    @AppStorage("showNotifications") var showNotifications: Bool = true
    /// Bookmark security-scoped della cartella di output.
    @AppStorage("customOutputFolder") var customOutputFolderData: Data?
    
    /// Nome breve della destinazione mostrato nel modulo.
    @State private var outputFolderName: String = "Same as source"
    
    /// Costruisce le sezioni dedicate ad aspetto e conversione.
    var body: some View {
        Form {
            Section("Aspetto") {
                Picker("Tema", selection: $appAppearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Settings") {
                Picker("MP3 Quality", selection: $mp3Quality) {
                    ForEach(MP3Quality.allCases) { quality in
                        Text(quality.description).tag(quality.rawValue)
                    }
                }
                .pickerStyle(.menu)
                
                Toggle("Overwrite existing files", isOn: $overwriteExisting)
                    .help("If disabled, appends numbers to duplicates.")
                
                Toggle("Show notifications on completion", isOn: $showNotifications)
                
                HStack {
                    Text("Output Folder:")
                    Spacer()
                    Text(outputFolderName)
                        .foregroundColor(.secondary)
                    Button("Choose...") {
                        selectOutputFolder()
                    }
                }
            }
        }
        .padding()
        .frame(width: 420, height: 270)
        .onAppear {
            updateOutputFolderName()
        }
    }
    
    /// Mostra il selettore di directory e salva il relativo bookmark di sicurezza.
    private func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                customOutputFolderData = data
                updateOutputFolderName()
            } catch {
                print("Failed to save bookmark data: \(error)")
            }
        }
    }
    
    /// Risolve il bookmark e sincronizza l'etichetta della destinazione.
    private func updateOutputFolderName() {
        guard let data = customOutputFolderData else {
            outputFolderName = "Same as source"
            return
        }
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            outputFolderName = url.lastPathComponent
        } else {
            outputFolderName = "Same as source"
            customOutputFolderData = nil
        }
    }
}
