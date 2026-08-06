import SwiftUI
import UniformTypeIdentifiers

/// Contenitore principale che instrada l'utente fra le funzionalità dell'app.
struct HomeView: View {
    /// Destinazioni interne disponibili nella finestra principale.
    enum AppSection {
        case home
        case wmaToMp3
        case archiveDecompressor
    }
    
    /// Sezione attualmente visibile.
    @State private var currentSection: AppSection = .home
    /// Coordinatore condiviso delle conversioni audio.
    @Environment(ConversionManager.self) private var manager
    /// Tema effettivo, usato per adattare lo sfondo.
    @Environment(\.colorScheme) private var colorScheme
    /// Preferenza persistente modificata dal menu rapido del tema.
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.dark.rawValue
    
    /// Costruisce lo sfondo comune e presenta la sezione selezionata.
    var body: some View {
        VStack(spacing: 0) {
            themeBar

            ZStack {
                // Gradiente decorativo adattato al contrasto del tema corrente.
                LinearGradient(
                    gradient: Gradient(colors: backgroundColors),
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
        }
        .frame(minWidth: 700, minHeight: 500)
        .animation(.spring(), value: currentSection)
    }

    /// Barra permanente con tre pulsanti testuali per la selezione del tema.
    private var themeBar: some View {
        HStack(spacing: 12) {
            Spacer()

            Label("Tema", systemImage: "circle.lefthalf.filled")
                .font(.callout.weight(.semibold))

            Picker("Tema", selection: $appAppearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 230)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    /// Coppia di colori dello sfondo per modalità chiara o scura.
    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.035, green: 0.055, blue: 0.10),
                Color(red: 0.10, green: 0.045, blue: 0.14)
            ]
        }
        return [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]
    }
}

extension HomeView {
    /// Menu iniziale con le due funzionalità principali.
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
    
    /// Combina intestazione di navigazione e coda del convertitore.
    private var wmaToMp3View: some View {
        VStack(spacing: 0) {
            header(title: "Convertitore WMA to MP3", onBack: { currentSection = .home })
            ContentView()
        }
    }
    
    /// Intestazione riutilizzabile con titolo centrato e pulsante Indietro.
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

/// Scheda interattiva del menu iniziale, animata al passaggio del puntatore.
struct SelectionCard: View {
    /// Titolo principale della funzionalità.
    let title: String
    /// Breve spiegazione visualizzata sotto il titolo.
    let description: String
    /// Nome SF Symbols dell'icona.
    let icon: String
    /// Colore distintivo della funzionalità.
    let color: Color
    /// Azione eseguita al clic.
    let action: () -> Void
    
    /// Controlla ingrandimento e ombra durante l'hover.
    @State private var isHovering = false
    /// Permette di regolare superficie, bordo e ombra al tema.
    @Environment(\.colorScheme) private var colorScheme
    
    /// Compone icona, testi e animazione della scheda.
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
                    .fill(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.92 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(isHovering ? 0.3 : 0.16), radius: isHovering ? 20 : 10)
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
