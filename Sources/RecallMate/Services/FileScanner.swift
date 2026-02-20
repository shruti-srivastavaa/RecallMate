import Foundation
import CoreData

/// Scans the app's documents directory for files and creates MemoryItems.
class FileScanner: ObservableObject {
    @Published var isScanning = false
    @Published var lastScanDate: Date?

    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    /// Scans the Documents directory for new or updated files.
    func scan() async {
        await MainActor.run { isScanning = true }
        defer { Task { @MainActor in isScanning = false; lastScanDate = Date() } }

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: documentsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        let supportedExtensions: Set<String> = ["pdf", "txt", "md", "rtf", "doc", "docx", "png", "jpg", "jpeg", "json", "csv"]

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else { continue }

            let ext = fileURL.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else { continue }

            await saveFileMemory(fileURL: fileURL)
        }
    }

    private func saveFileMemory(fileURL: URL) async {
        let path = fileURL.path
        let hash = path.hashValue.description

        // Deduplicate
        let request = MemoryItem.fetchRequest()
        request.predicate = NSPredicate(format: "contentHash == %@", hash)
        request.fetchLimit = 1

        do {
            let existing = try viewContext.fetch(request)
            guard existing.isEmpty else { return }
        } catch { /* proceed */ }

        let fileName = fileURL.lastPathComponent
        let fileExt = fileURL.pathExtension.lowercased()
        let content: String

        if ["txt", "md", "rtf", "json", "csv"].contains(fileExt) {
            content = (try? String(contentsOf: fileURL, encoding: .utf8).prefix(500).description) ?? "File: \(fileName)"
        } else {
            content = "\(fileExt.uppercased()) file: \(fileName)"
        }

        await MainActor.run {
            let item = MemoryItem(
                context: viewContext,
                title: fileName,
                content: content,
                category: .file,
                source: "Files",
                filePath: path
            )
            item.contentHash = hash

            do {
                try viewContext.save()
                SpotlightIndexer.index(item: item)
            } catch {
                print("FileScanner save error: \(error)")
            }
        }
    }
}
