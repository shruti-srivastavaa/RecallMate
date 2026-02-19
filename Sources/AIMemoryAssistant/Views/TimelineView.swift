import SwiftUI

/// Chronological timeline of all memories, grouped by date sections.
struct TimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MemoryItem.timestamp, ascending: false)],
        animation: .default
    ) private var memories: FetchedResults<MemoryItem>

    @State private var selectedMemory: MemoryItem?

    private var groupedMemories: [(String, [MemoryItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: Array(memories)) { item -> String in
            if calendar.isDateInToday(item.timestamp) {
                return "Today"
            } else if calendar.isDateInYesterday(item.timestamp) {
                return "Yesterday"
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()),
                      item.timestamp > weekAgo {
                return "This Week"
            } else if let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()),
                      item.timestamp > monthAgo {
                return "This Month"
            } else {
                return "Older"
            }
        }

        let order = ["Today", "Yesterday", "This Week", "This Month", "Older"]
        return order.compactMap { key in
            guard let items = grouped[key] else { return nil }
            return (key, items)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color(hue: 0.58, saturation: 0.6, brightness: 0.12),
                        .black
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedMemories, id: \.0) { section, items in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(section)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(items.count)")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.4))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(.white.opacity(0.1)))
                                }

                                ForEach(items) { item in
                                    MemoryCardView(item: item) {
                                        selectedMemory = item
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.purple)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .sheet(item: $selectedMemory) { item in
                MemoryDetailView(item: item)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}
