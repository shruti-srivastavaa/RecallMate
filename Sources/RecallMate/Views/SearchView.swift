import SwiftUI

/// Full-screen natural language search view with AI reasoning mode.
struct SearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var searchEngine: SearchEngine = SearchEngine(
        context: PersistenceController.shared.container.viewContext
    )
    @StateObject private var reasoningEngine: ReasoningEngine = ReasoningEngine(
        context: PersistenceController.shared.container.viewContext
    )
    @State private var query = ""
    @State private var selectedMemory: MemoryItem?
    @State private var useReasoning = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color(hue: 0.75, saturation: 0.7, brightness: 0.12),
                        .black
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Search bar
                    HStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: useReasoning ? "brain" : "magnifyingglass")
                                .foregroundStyle(useReasoning ? .cyan : .purple)
                            TextField(
                                useReasoning ? "Ask a complex question…" : "Ask about your memories…",
                                text: $query
                            )
                            .font(.body)
                            .foregroundStyle(.white)
                            .focused($isSearchFocused)
                            .onSubmit { performSearch() }
                            .autocorrectionDisabled()

                            if !query.isEmpty {
                                Button {
                                    query = ""
                                    searchEngine.results = []
                                    reasoningEngine.results = []
                                    reasoningEngine.reasoningSteps = []
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(12)
                        .glassBackground(cornerRadius: 14)

                        Button("Cancel") { dismiss() }
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 20)

                    // Mode toggle
                    HStack(spacing: 8) {
                        searchModeButton(title: "Search", icon: "magnifyingglass", isActive: !useReasoning) {
                            useReasoning = false
                        }
                        searchModeButton(title: "AI Reasoning", icon: "brain", isActive: useReasoning) {
                            useReasoning = true
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // Suggested queries
                    if query.isEmpty && searchEngine.results.isEmpty && reasoningEngine.results.isEmpty {
                        suggestedQueries
                    }

                    // Reasoning steps
                    if useReasoning && !reasoningEngine.reasoningSteps.isEmpty {
                        reasoningStepsView
                    }

                    // Results
                    if searchEngine.isSearching || reasoningEngine.isReasoning {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(useReasoning ? .cyan : .purple)
                        Text(useReasoning ? "AI is reasoning…" : "Searching memories…")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    } else if useReasoning && !reasoningEngine.answer.isEmpty {
                        reasoningResultView
                    } else if !searchEngine.results.isEmpty {
                        resultsList
                    } else if !query.isEmpty && !searchEngine.isSearching && !reasoningEngine.isReasoning {
                        noResults
                    }

                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationBarHidden(true)
            .onAppear { isSearchFocused = true }
            .sheet(item: $selectedMemory) { item in
                MemoryDetailView(item: item)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    // MARK: – Mode Toggle

    private func searchModeButton(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isActive ? (title == "AI Reasoning" ? Color.cyan.opacity(0.2) : Color.purple.opacity(0.2)) : .white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? (title == "AI Reasoning" ? Color.cyan.opacity(0.4) : Color.purple.opacity(0.4)) : .clear, lineWidth: 1)
            )
            .foregroundStyle(isActive ? (title == "AI Reasoning" ? .cyan : .purple) : .white.opacity(0.5))
        }
    }

    // MARK: – Reasoning Views

    private var reasoningStepsView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reasoning Chain")
                    .font(.caption)
                    .foregroundStyle(.cyan.opacity(0.6))
                    .padding(.horizontal, 20)

                ForEach(reasoningEngine.reasoningSteps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(.cyan.opacity(0.4))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.8))
                            Text(step.detail)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxHeight: 200)
        }
        .animation(.easeInOut, value: reasoningEngine.reasoningSteps.count)
    }

    private var reasoningResultView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // AI Answer
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                        Text("AI Answer")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.cyan)
                    }

                    Text(reasoningEngine.answer)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.cyan.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.cyan.opacity(0.15), lineWidth: 1)
                        )
                )

                // Related memories
                if !reasoningEngine.results.isEmpty {
                    Text("\(reasoningEngine.results.count) related memories")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))

                    ForEach(reasoningEngine.results) { item in
                        MemoryCardView(item: item) {
                            selectedMemory = item
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: – Standard Search

    private var suggestedQueries: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(useReasoning ? "Try complex questions" : "Try asking")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 20)

            let suggestions = useReasoning ? [
                "What was that place where I met Rahul?",
                "Show files related to the design meeting",
                "What did I work on yesterday morning?",
                "Find everything about the campus visit"
            ] : [
                "Where did I save that PDF?",
                "What was the address from Messages?",
                "Show my recent links",
                "Find the meeting notes",
                "What did I copy yesterday?"
            ]

            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    query = suggestion
                    performSearch()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: useReasoning ? "brain" : "sparkles")
                            .font(.caption)
                            .foregroundStyle(useReasoning ? .cyan : .purple)
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.top, 12)
    }

    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                Text("\(searchEngine.results.count) memories found")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(searchEngine.results) { item in
                    MemoryCardView(item: item) {
                        selectedMemory = item
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var noResults: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.2))
            Text("No memories found")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.5))
            Text("Try different keywords or a broader query")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: – Actions

    private func performSearch() {
        if useReasoning {
            Task { await reasoningEngine.reason(query: query) }
        } else {
            Task { _ = await searchEngine.search(query: query) }
        }
    }
}
