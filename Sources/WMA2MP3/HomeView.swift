import SwiftUI

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
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("Funzionalità Video Editor")
                .font(.title)
                .bold()
            
            Text("Trascina qui i tuoi video per iniziare l'editing.")
                .foregroundColor(.secondary)
            
            Button("Seleziona Video...") {
                // Placeholder action
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("Prossimamente: Taglio, Unione e Filtri")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.orange.opacity(0.05))
    }
}
