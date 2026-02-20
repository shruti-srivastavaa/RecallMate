import Foundation
import CoreSpotlight
import CoreData
#if canImport(UIKit)
import UIKit
#endif

/// Indexes MemoryItems into system Spotlight so they appear in device-wide searches.
class SpotlightIndexer {

    private static let domainIdentifier = "com.aimemory.assistant.memories"

    /// Index a single memory item into Spotlight.
    static func index(item: MemoryItem) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = item.title
        attributeSet.contentDescription = item.content
        attributeSet.keywords = item.tagArray + [item.category.displayName, item.source]

        #if canImport(UIKit)
        attributeSet.thumbnailData = UIImage(systemName: item.category.icon)?
            .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
            .pngData()
        #endif

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: item.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )

        // Keep items in Spotlight for 30 days
        searchableItem.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        CSSearchableIndex.default().indexSearchableItems([searchableItem]) { error in
            if let error {
                print("Spotlight indexing error: \(error)")
            }
        }
    }

    /// Index all items from Core Data into Spotlight.
    static func reindexAll(context: NSManagedObjectContext) {
        let request = MemoryItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MemoryItem.timestamp, ascending: false)]

        guard let items = try? context.fetch(request) else { return }

        let searchableItems = items.map { item -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            attrs.title = item.title
            attrs.contentDescription = item.content
            attrs.keywords = item.tagArray + [item.category.displayName, item.source]

            let si = CSSearchableItem(
                uniqueIdentifier: item.id.uuidString,
                domainIdentifier: domainIdentifier,
                attributeSet: attrs
            )
            si.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
            return si
        }

        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error {
                print("Spotlight reindex error: \(error)")
            }
        }
    }

    /// Remove a specific item from Spotlight.
    static func deindex(itemID: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [itemID.uuidString]) { error in
            if let error {
                print("Spotlight deindex error: \(error)")
            }
        }
    }

    /// Remove all items from Spotlight.
    static func deindexAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error {
                print("Spotlight deindex all error: \(error)")
            }
        }
    }
}
