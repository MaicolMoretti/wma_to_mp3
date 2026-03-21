import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    enum AppSection {
        case home
        case wmaToMp3
        case editVideo
    }
    
    @State private var currentSection: AppSection = .home
    @Environment(ConversionManager.self) private var manager
    
    var body: some View {
        ZStack {
            // Background gradient for a premium feel
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            switch currentSection {
            case .home:
                mainSelectionMenu
            case .wmaToMp3:
                wmaToMp3View
            case .editVideo:
                editVideoView
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        .animation(.spring(), value: currentSection)
    }
    
    private var mainSelectionMenu: some View {
        VStack(spacing: 30) {
            Text("Benvenuto in WMA2MP3")
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 40)
            
            Text("Cosa vorresti fare oggi?")
                .font(.title3)
                .foregroundColor(.secondary)
            
            HStack(spacing: 40) {
                SelectionCard(
                    title: "WMA to MP3",
                    description: "Converti i tuoi file audio velocemente",
                    icon: "music.note.list",
                    color: .blue
                ) {
                    currentSection = .wmaToMp3
                }
                
                SelectionCard(
                    title: "Edit Video",
                    description: "Modifica e taglia i tuoi video",
                    icon: "video.fill",
                    color: .orange
                ) {
                    currentSection = .editVideo
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var wmaToMp3View: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    currentSection = .home
                } label: {
                    Label("Indietro", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .padding()
                
                Spacer()
                
                Text("Convertitore WMA to MP3")
                    .font(.headline)
                    .padding()
                
                Spacer()
                
                // Placeholder to balance the back button
                Color.clear.frame(width: 60)
            }
            .background(.ultraThinMaterial)
            
            ContentView()
        }
    }
    
    private var editVideoView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    currentSection = .home
                } label: {
                    Label("Indietro", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .padding()
                
                Spacer()
                
                Text("Editor Video")
                    .font(.headline)
                    .padding()
                
                Spacer()
                
                Color.clear.frame(width: 60)
            }
            .background(.ultraThinMaterial)
            
            VideoEditView()
        }
    }
}

struct SelectionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(color.gradient)
                            .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(height: 40)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(isHovering ? 0.15 : 0.05), radius: isHovering ? 20 : 10)
            )
            .scaleEffect(isHovering ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }
}

struct VideoEditView: View {
    @State private var segManager = VideoSegmentationManager()
    @State private var isTargeted = false
    @State private var selectedVideoURL: URL?
    
    var body: some View {
        VStack(spacing: 20) {
            if let videoURL = selectedVideoURL {
                processingView(for: videoURL)
            } else {
                dropZone
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.orange.opacity(0.05))
        .onDrop(of: [.item, .fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    @ViewBuilder
    private var dropZone: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(isTargeted ? .accentColor : .orange)
            
            Text("Segmentazione Video Automatica")
                .font(.title)
                .bold()
            
            Text("Trascina qui un video (.mp4, .mov)")
                .foregroundColor(.secondary)
            
            Button("Seleziona Video...") {
                selectVideo()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            
            Text("Rileva automaticamente le schermate blu e divide il video in capitoli.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 10)
        }
    }
    
    @ViewBuilder
    private func processingView(for url: URL) -> some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "video.fill")
                    .foregroundColor(.orange)
                Text(url.lastPathComponent)
                    .font(.headline)
                Spacer()
                if case .completed = segManager.state {
                    Button("Chiudi") {
                        selectedVideoURL = nil
                        segManager.reset()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                switch segManager.state {
                case .idle:
                    Button("Avvia Segmentazione") {
                        Task {
                            await segManager.processVideo(url: url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .frame(maxWidth: .infinity)
                    
                case .scanning(let progress):
                    VStack(alignment: .leading, spacing: 12) {
                        ProgressSection(title: "Scansione fotogrammi...", progress: progress, icon: "magnifyingglass")
                        
                        if segManager.estimatedTotalSeconds > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text("Tempo stimato")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(VideoSegmentationManager.formatDuration(segManager.elapsedSeconds)) / ~\(VideoSegmentationManager.formatDuration(segManager.estimatedTotalSeconds))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                                let timeProgress = segManager.estimatedTotalSeconds > 0
                                    ? min(segManager.elapsedSeconds / segManager.estimatedTotalSeconds, 1.0)
                                    : 0.0
                                ProgressView(value: timeProgress)
                                    .progressViewStyle(.linear)
                                    .tint(.orange.opacity(0.6))
                            }
                        }
                        
                        Text(segManager.statusMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                case .cutting(let progress):
                    VStack(spacing: 8) {
                        ProgressSection(title: "Taglio segmenti con FFmpeg...", progress: progress, icon: "scissors")
                        Text(segManager.statusMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                case .completed(let count):
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("Operazione Completata!")
                            .font(.title2).bold()
                        Text("Sono stati generati \(count) file nel percorso originale.")
                            .foregroundColor(.secondary)
                        
                        Button("Mostra nel Finder") {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                        }
                        .buttonStyle(.link)
                    }
                    .padding()
                    
                case .error(let message):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text("Errore nella segmentazione")
                            .font(.title2).bold()
                        Text(message)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Riprova") {
                            segManager.reset()
                            Task {
                                await segManager.processVideo(url: url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(30)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 10)
            
            if !segManager.log.isEmpty {
                ScrollView {
                    Text(segManager.log)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 120)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
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
                let ext = url.pathExtension.lowercased()
                if ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) {
                    Task { @MainActor in
                        self.selectedVideoURL = url
                    }
                }
            }
        }
        return true
    }
    
    private func selectVideo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .video]
        
        if panel.runModal() == .OK {
            self.selectedVideoURL = panel.url
        }
    }
}

struct ProgressSection: View {
    let title: String
    let progress: Double
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
