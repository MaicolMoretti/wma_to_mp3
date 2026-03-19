import SwiftUI

struct SettingsView: View {
    @AppStorage("mp3Quality") var mp3Quality: Int = 192
    @AppStorage("overwriteExisting") var overwriteExisting: Bool = false
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("customOutputFolder") var customOutputFolderData: Data?
    
    @State private var outputFolderName: String = "Same as source"
    
    var body: some View {
        Form {
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
        .frame(width: 400, height: 200)
        .onAppear {
            updateOutputFolderName()
        }
    }
    
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
