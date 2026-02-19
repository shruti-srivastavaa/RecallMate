import Foundation
import CoreData
#if canImport(UIKit)
import UIKit
#endif

/// Monitors the system clipboard for new content and stores it as MemoryItems.
@MainActor
class ClipboardMonitor: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var lastCaptured: String?

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        #if canImport(UIKit)
        self.lastChangeCount = UIPasteboard.general.changeCount
        #endif
    }

    func start() {
        guard isEnabled else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let text = pasteboard.string, !text.isEmpty {
            saveToCoreData(text)
        }
        #endif
    }

    private func saveToCoreData(_ text: String) {
        // Deduplicate via content hash
        let hash = String(text.hashValue)
        let request = MemoryItem.fetchRequest()
        request.predicate = NSPredicate(format: "contentHash == %@", hash)
        request.fetchLimit = 1

        do {
            let existing = try viewContext.fetch(request)
            guard existing.isEmpty else { return }
        } catch { /* proceed to save */ }

        // Determine category from content
        let category: MemoryCategory = detectCategory(text)
        let title = generateTitle(for: text, category: category)

        let item = MemoryItem(
            context: viewContext,
            title: title,
            content: text,
            category: category,
            source: "Clipboard"
        )
        item.contentHash = hash

        do {
            try viewContext.save()
            lastCaptured = title
            SpotlightIndexer.index(item: item)
        } catch {
            print("ClipboardMonitor save error: \(error)")
        }
    }

    private func detectCategory(_ text: String) -> MemoryCategory {
        if text.contains("http://") || text.contains("https://") {
            return .link
        }
        if text.range(of: #"\d{1,5}\s\w+\s(Street|St|Avenue|Ave|Road|Rd|Drive|Dr|Lane|Ln|Blvd)"#,
                       options: .regularExpression) != nil {
            return .address
        }
        return .clipboard
    }

    private func generateTitle(for text: String, category: MemoryCategory) -> String {
        switch category {
        case .link:
            if let url = URL(string: text) {
                return "Link: \(url.host ?? text.prefix(40).description)"
            }
            return "Copied Link"
        case .address:
            return "Address: \(String(text.prefix(30)))..."
        default:
            let preview = String(text.prefix(50)).replacingOccurrences(of: "\n", with: " ")
            return preview.count < text.count ? "\(preview)…" : preview
        }
    }
}
