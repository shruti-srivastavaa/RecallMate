import AppIntents
import CoreData

/// Siri / Shortcuts intent that lets users recall memories via natural language.
///
/// Example: "Recall meeting notes in Memory Assistant"
struct RecallMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Recall a Memory"
    static var description = IntentDescription("Search your memories using natural language.")

    @Parameter(title: "Query", description: "What are you looking for?")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Recall \(\.$query)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let context = PersistenceController.shared.container.viewContext
        let engine = SearchEngine(context: context)
        let results = await engine.search(query: query)

        if let top = results.first {
            return .result(
                dialog: "Here's what I found: \(top.title)",
                view: MemorySnippetView(item: top)
            )
        } else {
            return .result(
                dialog: "I couldn't find any memories matching \"\(query)\". Try a different search.",
                view: EmptySnippetView()
            )
        }
    }
}

// MARK: – Snippet Views for Siri Results

import SwiftUI

struct MemorySnippetView: View {
    let item: MemoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.category.icon)
                    .foregroundStyle(item.category.color)
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
            }
            Text(item.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            HStack {
                Text(item.source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(item.relativeTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptySnippetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No memories found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
