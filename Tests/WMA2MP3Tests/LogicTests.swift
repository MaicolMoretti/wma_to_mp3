import XCTest
@testable import WMA2MP3

/// Test unitari delle funzioni di supporto indipendenti dall'interfaccia.
final class LogicTests: XCTestCase {
    
    /// Verifica la generazione progressiva di nomi liberi sul filesystem.
    func testFilenameDeduplication() throws {
        // Usa una directory temporanea isolata e la rimuove sempre al termine.
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let targetURL = tempDir.appendingPathComponent("output.mp3")
        
        // Se il file non esiste, il percorso originale deve rimanere invariato.
        var uniqueURL = FileHelpers.generateUniqueFilename(for: targetURL)
        XCTAssertEqual(uniqueURL, targetURL)
        
        // Occupando il nome originale deve essere proposto il suffisso `_1`.
        FileManager.default.createFile(atPath: targetURL.path, contents: Data(), attributes: nil)
        uniqueURL = FileHelpers.generateUniqueFilename(for: targetURL)
        XCTAssertEqual(uniqueURL, tempDir.appendingPathComponent("output_1.mp3"))
        
        // Occupando anche il primo duplicato, il contatore deve avanzare a `_2`.
        FileManager.default.createFile(atPath: uniqueURL.path, contents: Data(), attributes: nil)
        uniqueURL = FileHelpers.generateUniqueFilename(for: targetURL)
        XCTAssertEqual(uniqueURL, tempDir.appendingPathComponent("output_2.mp3"))
    }
    
    /// Segnaposto per un futuro test pubblico del parser temporale di FFmpeg.
    func testTimeParsing() throws {
        // Il parser è privato: sarà verificabile tramite un test d'integrazione o un'API interna dedicata.
        let engine = FFmpegEngine()
        // L'istanza conferma per ora soltanto che l'actor può essere costruito nel target di test.
    }
}
