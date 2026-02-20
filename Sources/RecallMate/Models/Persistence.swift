import CoreData

/// Manages the Core Data stack for the app.
struct PersistenceController {
    static let shared = PersistenceController()

    /// In-memory store for SwiftUI previews.
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext

        // Seed sample data
        let samples: [(String, String, MemoryCategory, String)] = [
            ("Meeting Notes", "Discussed Q3 roadmap with design team. Key decisions: new onboarding flow, dark mode priority.", .note, "Notes App"),
            ("Home Address", "1234 Elm Street, Cupertino, CA 95014", .address, "Messages"),
            ("Project Proposal PDF", "project_proposal_v3.pdf saved to Documents", .file, "Files"),
            ("API Documentation Link", "https://developer.apple.com/documentation/coreml", .link, "Safari"),
            ("Auth Token", "Bearer eyJhbGciOiJIUzI1NiIs...", .clipboard, "Clipboard"),
            ("Grocery List", "Milk, eggs, bread, avocados, organic coffee beans", .manual, "Manual Entry"),
            ("Restaurant Recommendation", "Try Tamarine in Palo Alto — great Vietnamese food!", .message, "Messages"),
            ("SSH Key Path", "~/.ssh/id_ed25519 — generated for new GitHub account", .file, "Terminal"),
            ("Flight Confirmation", "SFO → JFK, United UA 237, Mar 15, Gate B12", .clipboard, "Clipboard"),
            ("Design Feedback", "Logo looks great but try #6C5CE7 for the primary accent instead", .message, "Slack")
        ]

        for (i, sample) in samples.enumerated() {
            let item = MemoryItem(context: ctx, title: sample.0, content: sample.1, category: sample.2, source: sample.3)
            item.timestamp = Calendar.current.date(byAdding: .hour, value: -(i * 3), to: Date()) ?? Date()
            if i == 0 || i == 3 { item.isFavorite = true }
        }

        do { try ctx.save() } catch {
            fatalError("Preview Core Data save error: \(error)")
        }
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Build the model programmatically
        let model = Self.createManagedObjectModel()
        container = NSPersistentContainer(name: "RecallMate", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data store failed to load: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: – Programmatic Core Data Model

    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "MemoryItem"
        entity.managedObjectClassName = "MemoryItem"

        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false

        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = false
        titleAttr.defaultValue = ""

        let contentAttr = NSAttributeDescription()
        contentAttr.name = "content"
        contentAttr.attributeType = .stringAttributeType
        contentAttr.isOptional = false
        contentAttr.defaultValue = ""

        let categoryRawAttr = NSAttributeDescription()
        categoryRawAttr.name = "categoryRaw"
        categoryRawAttr.attributeType = .stringAttributeType
        categoryRawAttr.isOptional = false
        categoryRawAttr.defaultValue = "manual"

        let timestampAttr = NSAttributeDescription()
        timestampAttr.name = "timestamp"
        timestampAttr.attributeType = .dateAttributeType
        timestampAttr.isOptional = false

        let sourceAttr = NSAttributeDescription()
        sourceAttr.name = "source"
        sourceAttr.attributeType = .stringAttributeType
        sourceAttr.isOptional = false
        sourceAttr.defaultValue = ""

        let filePathAttr = NSAttributeDescription()
        filePathAttr.name = "filePath"
        filePathAttr.attributeType = .stringAttributeType
        filePathAttr.isOptional = true

        let tagsAttr = NSAttributeDescription()
        tagsAttr.name = "tags"
        tagsAttr.attributeType = .stringAttributeType
        tagsAttr.isOptional = true

        let isFavoriteAttr = NSAttributeDescription()
        isFavoriteAttr.name = "isFavorite"
        isFavoriteAttr.attributeType = .booleanAttributeType
        isFavoriteAttr.isOptional = false
        isFavoriteAttr.defaultValue = false

        let contentHashAttr = NSAttributeDescription()
        contentHashAttr.name = "contentHash"
        contentHashAttr.attributeType = .stringAttributeType
        contentHashAttr.isOptional = true

        entity.properties = [
            idAttr, titleAttr, contentAttr, categoryRawAttr,
            timestampAttr, sourceAttr, filePathAttr, tagsAttr,
            isFavoriteAttr, contentHashAttr
        ]

        model.entities = [entity]
        return model
    }

    // MARK: – Helpers

    func save() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
        } catch {
            print("Core Data save error: \(error)")
        }
    }
}
