import Foundation
import CoreData

/// Core Data managed object representing a single captured memory.
@objc(MemoryItem)
public class MemoryItem: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var content: String
    @NSManaged public var categoryRaw: String
    @NSManaged public var timestamp: Date
    @NSManaged public var source: String
    @NSManaged public var filePath: String?
    @NSManaged public var tags: String?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var contentHash: String?

    // MARK: – Computed

    var category: MemoryCategory {
        get { MemoryCategory(rawValue: categoryRaw) ?? .manual }
        set { categoryRaw = newValue.rawValue }
    }

    var tagArray: [String] {
        get { tags?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? [] }
        set { tags = newValue.joined(separator: ", ") }
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    // MARK: – Convenience Initializer

    convenience init(
        context: NSManagedObjectContext,
        title: String,
        content: String,
        category: MemoryCategory,
        source: String = "",
        filePath: String? = nil,
        tags: [String] = []
    ) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.content = content
        self.categoryRaw = category.rawValue
        self.timestamp = Date()
        self.source = source
        self.filePath = filePath
        self.tags = tags.joined(separator: ", ")
        self.isFavorite = false
        self.contentHash = content.hashValue.description
    }
}

// MARK: – Fetch Requests

extension MemoryItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MemoryItem> {
        return NSFetchRequest<MemoryItem>(entityName: "MemoryItem")
    }

    static func recentItemsRequest(limit: Int = 20) -> NSFetchRequest<MemoryItem> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MemoryItem.timestamp, ascending: false)]
        request.fetchLimit = limit
        return request
    }

    static func searchRequest(query: String) -> NSFetchRequest<MemoryItem> {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@ OR tags CONTAINS[cd] %@",
            query, query, query
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MemoryItem.timestamp, ascending: false)]
        return request
    }

    static func categoryRequest(_ category: MemoryCategory) -> NSFetchRequest<MemoryItem> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "categoryRaw == %@", category.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MemoryItem.timestamp, ascending: false)]
        return request
    }
}
