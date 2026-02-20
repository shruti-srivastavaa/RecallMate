import Foundation
import CoreData
import NaturalLanguage

/// On-device semantic + keyword search engine using Apple's NaturalLanguage framework.
class SearchEngine: ObservableObject {
    @Published var results: [MemoryItem] = []
    @Published var isSearching = false

    private let viewContext: NSManagedObjectContext
    private let embedding: NLEmbedding?

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        // Attempt to load the built-in sentence embedding for the user's language
        self.embedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    /// Performs a combined keyword + semantic search across all memories.
    func search(query: String) async -> [MemoryItem] {
        await MainActor.run { isSearching = true }
        defer { Task { @MainActor in isSearching = false } }

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run { results = [] }
            return []
        }

        // 1) Keyword search via Core Data
        let keywordResults = keywordSearch(query: query)

        // 2) If we have embeddings, also do semantic ranking
        let ranked: [MemoryItem]
        if embedding != nil {
            ranked = semanticRank(query: query, candidates: allItems())
        } else {
            ranked = keywordResults
        }

        // 3) Merge: keyword results first (exact matches), then semantic, deduplicated
        let merged = mergeResults(keyword: keywordResults, semantic: ranked)

        await MainActor.run { results = merged }
        return merged
    }

    // MARK: – Keyword Search

    private func keywordSearch(query: String) -> [MemoryItem] {
        let request = MemoryItem.searchRequest(query: query)
        request.fetchLimit = 50
        return (try? viewContext.fetch(request)) ?? []
    }

    // MARK: – Semantic Ranking

    private func semanticRank(query: String, candidates: [MemoryItem]) -> [MemoryItem] {
        guard let embedding else { return candidates }

        guard let queryVector = embedding.vector(for: query) else {
            return candidates
        }

        var scored: [(item: MemoryItem, score: Double)] = []

        for item in candidates {
            let text = "\(item.title) \(item.content)"
            if let itemVector = embedding.vector(for: text) {
                let similarity = cosineSimilarity(queryVector, itemVector)
                // Boost recent items
                let recencyBoost = recencyScore(item.timestamp)
                let finalScore = similarity * 0.7 + recencyBoost * 0.3
                scored.append((item, finalScore))
            }
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(20)
            .map(\.item)
    }

    private func allItems() -> [MemoryItem] {
        let request = MemoryItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MemoryItem.timestamp, ascending: false)]
        request.fetchLimit = 200
        return (try? viewContext.fetch(request)) ?? []
    }

    // MARK: – Utilities

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).reduce(0.0) { $0 + $1.0 * $1.1 }
        let magA = sqrt(a.reduce(0.0) { $0 + $1 * $1 })
        let magB = sqrt(b.reduce(0.0) { $0 + $1 * $1 })
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }

    private func recencyScore(_ date: Date) -> Double {
        let hoursAgo = Date().timeIntervalSince(date) / 3600
        return max(0, 1.0 - (hoursAgo / 168.0)) // Decays over 1 week
    }

    private func mergeResults(keyword: [MemoryItem], semantic: [MemoryItem]) -> [MemoryItem] {
        var seen = Set<UUID>()
        var merged: [MemoryItem] = []

        for item in keyword {
            if seen.insert(item.id).inserted {
                merged.append(item)
            }
        }
        for item in semantic {
            if seen.insert(item.id).inserted {
                merged.append(item)
            }
        }

        return Array(merged.prefix(20))
    }
}
