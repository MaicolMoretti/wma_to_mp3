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
                VideoEditView(onBack: { currentSection = .home })
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .animation(.spring(), value: currentSection)
    }
}

extension HomeView {
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
            header(title: "Convertitore WMA to MP3", onBack: { currentSection = .home })
            ContentView()
        }
    }
    
    private func header(title: String, onBack: @escaping () -> Void) -> some View {
        HStack {
            Button(action: onBack) {
                Label("Indietro", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .padding()
            
            Spacer()
            Text(title).font(.headline).padding()
            Spacer()
            
            Color.clear.frame(width: 60)
        }
        .background(.ultraThinMaterial)
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
    var onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Label("Indietro", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .padding()
                
                Spacer()
                Text("Editor Video").font(.headline).padding()
                Spacer()
                Color.clear.frame(width: 60)
            }
            .background(.ultraThinMaterial)
            
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
    }
    
    @ViewBuilder
    private var dropZone: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(isTargeted ? .accentColor : .orange)
            
            Text("Segmentazione Video Automatica")
                .font(.title2)
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
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .stroke(isTargeted ? Color.accentColor : Color.orange.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [10]))
        )
        .padding(40)
    }
    
    @ViewBuilder
    private func processingView(for url: URL) -> some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "video.fill")
                    .foregroundColor(.orange)
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
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
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            
            VStack(spacing: 20) {
                statusSection(for: url)
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 10)
            
            if !segManager.log.isEmpty {
                logView
            }
            
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private func statusSection(for url: URL) -> some View {
        switch segManager.state {
        case .idle:
            Button("Avvia Analisi e Taglio") {
                Task { await segManager.processVideo(url: url) }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            
        case .scanning(let progress):
            ProgressSection(title: "Analisi video...", progress: progress, icon: "magnifyingglass")
            timerInfo
            statusMessage
            
        case .cutting(let progress):
            ProgressSection(title: "Esportazione capitoli...", progress: progress, icon: "scissors")
            statusMessage
            
        case .completed(let count):
            completionView(count: count, url: url)
            
        case .error(let message):
            errorView(message: message, url: url)
        }
    }
    
    private var timerInfo: some View {
        Group {
            if segManager.estimatedTotalSeconds > 0 {
                HStack {
                    Image(systemName: "clock")
                    Text("Tempo stimato: \(VideoSegmentationManager.formatDuration(segManager.elapsedSeconds)) / ~\(VideoSegmentationManager.formatDuration(segManager.estimatedTotalSeconds))")
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            }
        }
    }
    
    private var statusMessage: some View {
        Text(segManager.statusMessage)
            .font(.caption)
            .foregroundColor(.orange)
            .bold()
            .multilineTextAlignment(.center)
    }
    
    private func completionView(count: Int, url: URL) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            Text("Completato!").font(.headline)
            Text("Creati \(count) video nella cartella originale.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Mostra nel Finder") {
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            }
            .buttonStyle(.link)
        }
    }
    
    private func errorView(message: String, url: URL) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.octagon.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("Errore").font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Riprova") {
                segManager.reset()
                Task { await segManager.processVideo(url: url) }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var logView: some View {
        ScrollView {
            Text(segManager.log)
                .font(.system(.caption2, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .frame(height: 100)
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data = data,
                      let path = NSString(data: data, encoding: 4),
                      let url = URL(string: path as String) else { return }
                
                let ext = url.pathExtension.lowercased()
                let validExts = ["mp4", "mov", "m4v", "avi", "mkv"]
                if validExts.contains(ext) {
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
