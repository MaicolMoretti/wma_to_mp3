import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    enum AppSection {
        case home
        case wmaToMp3
        case archiveDecompressor
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
            case .archiveDecompressor:
                ArchiveDecompressorView(onBack: { currentSection = .home })
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
                    title: "Estrai Archivi",
                    description: "Estrai e unisci archivi multipli",
                    icon: "doc.zipper",
                    color: .green
                ) {
                    currentSection = .archiveDecompressor
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
