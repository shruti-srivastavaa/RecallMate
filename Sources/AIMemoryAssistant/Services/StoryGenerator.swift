import Foundation
import CoreData
import NaturalLanguage

/// Generates natural language daily/weekly life stories from memory data.
class StoryGenerator: ObservableObject {
    @Published var stories: [LifeStory] = []

    private let viewContext: NSManagedObjectContext
    private let tagger: NLTagger

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.tagger = NLTagger(tagSchemes: [.nameType])
    }

    func generateStories() async {
        let calendar = Calendar.current
        let now = Date()

        var generated: [LifeStory] = []

        // Yesterday's story
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            let start = calendar.startOfDay(for: yesterday)
            let end = calendar.startOfDay(for: now)
            let memories = fetchMemories(from: start, to: end)
            if !memories.isEmpty {
                generated.append(buildStory(
                    title: "Yesterday",
                    subtitle: formatDate(yesterday),
                    icon: "sun.max.fill",
                    memories: memories,
                    gradient: ["#667eea", "#764ba2"]
                ))
            }
        }

        // This week
        if let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) {
            let memories = fetchMemories(from: weekStart, to: now)
            if !memories.isEmpty {
                generated.append(buildStory(
                    title: "This Week",
                    subtitle: "\(formatDate(weekStart)) — Today",
                    icon: "calendar",
                    memories: memories,
                    gradient: ["#f093fb", "#f5576c"]
                ))
            }
        }

        // Last 30 days
        if let monthStart = calendar.date(byAdding: .day, value: -30, to: now) {
            let memories = fetchMemories(from: monthStart, to: now)
            if !memories.isEmpty {
                generated.append(buildStory(
                    title: "Last 30 Days",
                    subtitle: "Monthly Highlights",
                    icon: "chart.bar.fill",
                    memories: memories,
                    gradient: ["#4facfe", "#00f2fe"]
                ))
            }
        }

        await MainActor.run {
            self.stories = generated
        }
    }

    // MARK: – Story Construction

    private func buildStory(
        title: String,
        subtitle: String,
        icon: String,
        memories: [MemoryItem],
        gradient: [String]
    ) -> LifeStory {
        // Count by category
        var categoryCounts: [String: Int] = [:]
        for m in memories {
            categoryCounts[m.category.displayName, default: 0] += 1
        }
        let topCategories = categoryCounts.sorted { $0.value > $1.value }.prefix(3)

        // Extract entities
        var allEntities: [String: Int] = [:]
        for m in memories {
            let text = "\(m.title) \(m.content)"
            tagger.string = text
            tagger.enumerateTags(
                in: text.startIndex..<text.endIndex,
                unit: .word,
                scheme: .nameType,
                options: [.omitWhitespace, .omitPunctuation, .joinNames]
            ) { tag, range in
                guard let tag, tag == .personalName || tag == .placeName else { return true }
                let value = String(text[range]).trimmingCharacters(in: .whitespaces)
                guard value.count > 1 else { return true }
                allEntities[value, default: 0] += 1
                return true
            }
        }
        let topEntities = allEntities.sorted { $0.value > $1.value }.prefix(5)

        // Generate narrative
        let narrative = generateNarrative(
            title: title,
            memories: memories,
            categories: topCategories.map { $0.key },
            entities: topEntities.map { $0.key }
        )

        // Stats
        let stats = StoryStats(
            totalMemories: memories.count,
            categories: topCategories.map { StoryCategory(name: $0.key, count: $0.value) },
            topEntities: topEntities.map { StoryEntity(name: $0.key, mentions: $0.value) },
            filesSaved: categoryCounts["File", default: 0],
            clipboardCopies: categoryCounts["Clipboard", default: 0],
            linksVisited: categoryCounts["Link", default: 0]
        )

        return LifeStory(
            title: title,
            subtitle: subtitle,
            icon: icon,
            narrative: narrative,
            stats: stats,
            gradient: gradient,
            memoryCount: memories.count
        )
    }

    private func generateNarrative(
        title: String,
        memories: [MemoryItem],
        categories: [String],
        entities: [String]
    ) -> String {
        var parts: [String] = []

        // Opening
        let count = memories.count
        switch title {
        case "Yesterday":
            parts.append("Yesterday was a \(count > 10 ? "busy" : "productive") day with \(count) moments captured.")
        case "This Week":
            parts.append("This week you've been active with \(count) memories recorded across your devices.")
        default:
            parts.append("Over the past 30 days, you've accumulated \(count) memories.")
        }

        // Categories
        if !categories.isEmpty {
            let formatted = categories.prefix(3).joined(separator: ", ")
            parts.append("Your activity focused on \(formatted).")
        }

        // People & Places
        let people = entities.filter { $0.first?.isUppercase ?? false }.prefix(3)
        if !people.isEmpty {
            parts.append("Key people: \(people.joined(separator: ", ")).")
        }

        // Closing
        if count > 15 {
            parts.append("A highly active period — your knowledge base is growing fast! 🚀")
        } else if count > 5 {
            parts.append("Steady progress in building your personal knowledge graph. 📊")
        } else {
            parts.append("Keep capturing to build a richer memory timeline. ✨")
        }

        return parts.joined(separator: " ")
    }

    // MARK: – Data

    private func fetchMemories(from start: Date, to end: Date) -> [MemoryItem] {
        let request = MemoryItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp < %@",
            start as NSDate, end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MemoryItem.timestamp, ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: – Models

struct LifeStory: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let narrative: String
    let stats: StoryStats
    let gradient: [String]
    let memoryCount: Int
}

struct StoryStats {
    let totalMemories: Int
    let categories: [StoryCategory]
    let topEntities: [StoryEntity]
    let filesSaved: Int
    let clipboardCopies: Int
    let linksVisited: Int
}

struct StoryCategory: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct StoryEntity: Identifiable {
    let id = UUID()
    let name: String
    let mentions: Int
}
