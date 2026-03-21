import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(ConversionManager.self) private var manager
    @State private var settings = AppSettings()
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: 0) {
            if manager.files.isEmpty {
                emptyDropZone
            } else {
                fileList
                bottomBar
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    @ViewBuilder
    private var emptyDropZone: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(isTargeted ? .accentColor : .secondary)
            
            Text("Drop WMA files here")
                .font(.title2)
                .bold()
            
            Text("or click to browse")
                .foregroundColor(.secondary)
            
            Button("Browse Files...") {
                selectFiles()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 8])
                )
                .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .padding(40)
        .onDrop(of: [.item, .fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    @ViewBuilder
    private var fileList: some View {
        Table(manager.files) {
            TableColumn("Filename", value: \.filename)
            TableColumn("Size") { file in
                Text(ByteCountFormatter.string(fromByteCount: file.originalSize, countStyle: .file))
                    .foregroundColor(.secondary)
            }
            .width(min: 60, max: 80)
            TableColumn("Status") { file in
                statusView(for: file)
            }
            .width(min: 120, max: 200)
            TableColumn("") { file in
                if !manager.isConverting {
                    Button {
                        manager.removeFile(file.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .width(24)
        }
        .onDrop(of: [.item, .fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    @ViewBuilder
    private func statusView(for file: AudioFile) -> some View {
        switch file.state {
        case .pending:
            Text("Pending").foregroundColor(.secondary)
        case .converting(let progress):
            HStack {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .done:
            Label("Done", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .error(let msg):
            Label("Error", systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
                .help(msg)
        }
    }
    
    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 12) {
            Divider()
            
            if manager.isConverting {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Converting \(manager.files.count) files...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ProgressView(value: manager.overallProgress)
                        .progressViewStyle(.linear)
                }
                .padding(.horizontal)
            }
            
            HStack {
                if !manager.isConverting && manager.files.contains(where: { $0.state == .done }) {
                    Button("Clear Done") {
                        manager.clearDone()
                    }
                    
                    Button("Reveal in Finder") {
                        revealDoneFiles()
                    }
                }
                
                Spacer()
                
                if manager.isConverting {
                    Button("Cancel") {
                        manager.cancel()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                } else {
                    Button("Add More...") {
                        selectFiles()
                    }
                    Button("Convert to MP3") {
                        manager.startConversion(settings: settings)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let supportedExtensions = ["wma", "mp3", "m4a", "wav", "aac", "flac"]
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                guard let data = data,
                      let path = NSString(data: data, encoding: 4),
                      let url = URL(string: path as String) else {
                    if let error = error {
                        print("Drop error: \(error)")
                    }
                    return
                }
                if supportedExtensions.contains(url.pathExtension.lowercased()) {
                    Task { @MainActor in
                        manager.addFile(url)
                    }
                }
            }
        }
        return true
    }
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            UTType("com.microsoft.windows-media-wma") ?? .audio,
            .mp3,
            .mpeg4Audio,
            .wav,
            UTType.audio
        ]
        
        let supportedExtensions = ["wma", "mp3", "m4a", "wav", "aac", "flac"]
        if panel.runModal() == .OK {
            for url in panel.urls {
                if supportedExtensions.contains(url.pathExtension.lowercased()) {
                    manager.addFile(url)
                }
            }
        }
    }
    
    private func revealDoneFiles() {
        let doneUrls = manager.files.filter({ $0.state == .done }).compactMap({ $0.destinationURL })
        guard !doneUrls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(doneUrls)
    }
}

