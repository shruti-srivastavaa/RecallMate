import Foundation
import CoreData
import NaturalLanguage

/// Multi-step reasoning engine — parses complex questions and connects data across categories.
class ReasoningEngine: ObservableObject {
    @Published var reasoningSteps: [ReasoningStep] = []
    @Published var results: [MemoryItem] = []
    @Published var answer: String = ""
    @Published var isReasoning = false

    private let viewContext: NSManagedObjectContext
    private let searchEngine: SearchEngine
    private let tagger: NLTagger

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.searchEngine = SearchEngine(context: context)
        self.tagger = NLTagger(tagSchemes: [.nameType, .lemma])
    }

    /// Perform multi-step reasoning on a complex query.
    func reason(query: String) async {
        await MainActor.run {
            isReasoning = true
            reasoningSteps = []
            results = []
            answer = ""
        }

        // Step 1: Parse the query
        await addStep("🔍 Analyzing question", "Extracting entities, time, and intent…")
        let parsed = parseQuery(query)
        await addStep("📋 Query parsed",
            "People: \(parsed.people.isEmpty ? "none" : parsed.people.joined(separator: ", ")) | " +
            "Places: \(parsed.places.isEmpty ? "none" : parsed.places.joined(separator: ", ")) | " +
            "Time: \(parsed.timeHint ?? "any")"
        )

        // Step 2: Search by entities
        var allResults: [MemoryItem] = []

        if !parsed.people.isEmpty {
            await addStep("👤 Searching people", "Looking for mentions of \(parsed.people.joined(separator: ", "))…")
            for person in parsed.people {
                let personResults = keywordSearch(person)
                allResults.append(contentsOf: personResults)
            }
            await addStep("✅ People search", "Found \(allResults.count) related memories")
        }

        if !parsed.places.isEmpty {
            await addStep("📍 Searching places", "Looking for \(parsed.places.joined(separator: ", "))…")
            for place in parsed.places {
                let placeResults = keywordSearch(place)
                allResults.append(contentsOf: placeResults)
            }
            await addStep("✅ Place search", "Found \(allResults.count) total memories")
        }

        // Step 3: Time filtering
        if let timeHint = parsed.timeHint {
            await addStep("⏰ Filtering by time", "Narrowing to \(timeHint)…")
            let dateRange = resolveTimeHint(timeHint)
            allResults = allResults.filter { m in
                guard let t = m.timestamp else { return true }
                return t >= dateRange.start && t <= dateRange.end
            }
            await addStep("✅ Time filter", "\(allResults.count) memories in time range")
        }

        // Step 4: Semantic fallback
        if allResults.isEmpty {
            await addStep("🧠 Semantic search", "No keyword matches — attempting semantic similarity…")
            let semanticResults = await searchEngine.search(query: query)
            allResults = semanticResults
            await addStep("✅ Semantic results", "Found \(semanticResults.count) related memories")
        }

        // Step 5: Deduplicate and rank
        await addStep("📊 Ranking results", "Deduplicating and ranking by relevance…")
        let unique = Array(Set(allResults.map { $0.objectID }))
            .compactMap { try? viewContext.existingObject(with: $0) as? MemoryItem }
            .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
            .prefix(10)
        let finalResults = Array(unique)

        // Step 6: Generate answer
        let answerText = generateAnswer(query: query, results: finalResults, parsed: parsed)

        await MainActor.run {
            results = finalResults
            answer = answerText
            isReasoning = false
        }
        await addStep("💡 Answer ready", answerText)
    }

    // MARK: – Query Parsing

    private func parseQuery(_ query: String) -> ParsedQuery {
        var people: [String] = []
        var places: [String] = []
        var timeHint: String?

        // Extract named entities
        tagger.string = query
        tagger.enumerateTags(
            in: query.startIndex..<query.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            let value = String(query[range]).trimmingCharacters(in: .whitespaces)
            switch tag {
            case .personalName: people.append(value)
            case .placeName:    places.append(value)
            default: break
            }
            return true
        }

        // Extract time hints
        let timePhrases = [
            "yesterday", "today", "last week", "this week",
            "last month", "this morning", "last night",
            "2 days ago", "3 days ago", "a week ago"
        ]
        let lower = query.lowercased()
        for phrase in timePhrases {
            if lower.contains(phrase) {
                timeHint = phrase
                break
            }
        }

        return ParsedQuery(people: people, places: places, timeHint: timeHint)
    }

    private func resolveTimeHint(_ hint: String) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch hint.lowercased() {
        case "yesterday":
            let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
            return (start, calendar.startOfDay(for: now))
        case "today":
            return (calendar.startOfDay(for: now), now)
        case "last week":
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            return (start, now)
        case "this week":
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (start, now)
        case "last month":
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return (start, now)
        case "this morning":
            return (calendar.startOfDay(for: now), now)
        case "last night":
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            var start = calendar.dateComponents([.year, .month, .day], from: yesterday)
            start.hour = 18
            return (calendar.date(from: start)!, calendar.startOfDay(for: now))
        default:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
        }
    }

    // MARK: – Search

    private func keywordSearch(_ keyword: String) -> [MemoryItem] {
        let request = MemoryItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@",
            keyword, keyword
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MemoryItem.timestamp, ascending: false)]
        request.fetchLimit = 20
        return (try? viewContext.fetch(request)) ?? []
    }

    // MARK: – Answer Generation

    private func generateAnswer(query: String, results: [MemoryItem], parsed: ParsedQuery) -> String {
        if results.isEmpty {
            return "I couldn't find any memories matching your question. Try rephrasing or adding more details."
        }

        let top = results.first!
        var parts: [String] = []

        parts.append("Based on \(results.count) related memories:")

        // Most relevant result
        parts.append("📌 \"\(top.title)\" — \(top.content.prefix(80))…")

        if let timestamp = top.timestamp {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            parts.append("📅 \(formatter.string(from: timestamp))")
        }

        if !parsed.people.isEmpty {
            parts.append("👤 Connected to: \(parsed.people.joined(separator: ", "))")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: – Helpers

    @MainActor
    private func addStep(_ title: String, _ detail: String) {
        reasoningSteps.append(ReasoningStep(title: title, detail: detail))
    }
}

// MARK: – Models

struct ParsedQuery {
    let people: [String]
    let places: [String]
    let timeHint: String?
}

struct ReasoningStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let timestamp = Date()
}
