import XCTest
@testable import WMA2MP3

final class DecompressorTests: XCTestCase {
    
    func createDummyArchive(named archiveName: String, files: [String], in directory: URL) throws -> URL {
        let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        
        for file in files {
            let fileURL = tempFolder.appendingPathComponent(file)
            if file.contains("/") {
                let dir = fileURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            try "dummy content".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        let archiveURL = directory.appendingPathComponent(archiveName)
        let process = Process()
        
        if archiveName.hasSuffix(".zip") {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.currentDirectoryURL = tempFolder
            process.arguments = ["-r", archiveURL.path, "."]
        } else if archiveName.hasSuffix(".tar.gz") {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.currentDirectoryURL = tempFolder
            process.arguments = ["-czf", archiveURL.path, "."]
        } else {
            fatalError("Unsupported test archive format")
        }
        
        try process.run()
        process.waitUntilExit()
        try? FileManager.default.removeItem(at: tempFolder)
        
        return archiveURL
    }
    
    func testDecompressorLogic() async throws {
        let testRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: testRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testRoot) }
        
        let archive1 = try createDummyArchive(named: "test1.zip", files: ["file1.txt", "file2.txt", "folderA/subfile.txt"], in: testRoot)
        let archive2 = try createDummyArchive(named: "test2.tar.gz", files: ["file2.txt", "file3.txt", "folderA/subfile2.txt"], in: testRoot)
        
        let manager = DecompressorManager()
        manager.addArchives([archive1, archive2])
        
        let outputDir = testRoot.appendingPathComponent("ExtractionResult")
        manager.outputFolder = outputDir
        
        await manager.startProcessing()
        
        XCTAssertEqual(manager.state, .completed, "Processamento non completato con successo")
        XCTAssertEqual(manager.successCount, 2, "Dovrebbero esserci 2 successi")
        XCTAssertEqual(manager.failureCount, 0, "Non dovrebbero esserci errori")
        
        // Check files in output directory
        let fm = FileManager.default
        let extractedItems = try fm.contentsOfDirectory(atPath: outputDir.path)
        
        // file1.txt, file2.txt, file3.txt, file2_(1).txt, folderA
        XCTAssertTrue(extractedItems.contains("file1.txt"))
        XCTAssertTrue(extractedItems.contains("file2.txt"))
        XCTAssertTrue(extractedItems.contains("file3.txt"))
        
        // Duplicate resolution test
        XCTAssertTrue(extractedItems.contains("file2_(1).txt") || extractedItems.contains("file2_1.txt") || fm.fileExists(atPath: outputDir.appendingPathComponent("file2_(1).txt").path), "File duplicato non rinominato correttamente")
        
        // Subfolders merge test
        let folderAPath = outputDir.appendingPathComponent("folderA")
        var isDir: ObjCBool = false
        XCTAssertTrue(fm.fileExists(atPath: folderAPath.path, isDirectory: &isDir) && isDir.boolValue, "folderA non è stata estratta come cartella")
        
        let folderAItems = try fm.contentsOfDirectory(atPath: folderAPath.path)
        XCTAssertTrue(folderAItems.contains("subfile.txt"))
        XCTAssertTrue(folderAItems.contains("subfile2.txt"), "I contenuti di folderA non sono stati uniti")
    }
}
