import SwiftUI
import CoreData

/// Main dashboard with search, recent memories, and category filters.
struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MemoryItem.timestamp, ascending: false)],
        animation: .default
    ) private var memories: FetchedResults<MemoryItem>

    @State private var searchText = ""
    @State private var selectedCategory: MemoryCategory?
    @State private var showSearch = false
    @State private var showTimeline = false
    @State private var showSettings = false
    @State private var showGraph = false
    @State private var showReplay = false
    @State private var showStories = false
    @State private var selectedMemory: MemoryItem?

    private var filteredMemories: [MemoryItem] {
        var items = Array(memories)
        if let cat = selectedCategory {
            items = items.filter { $0.category == cat }
        }
        return items
    }

    private var stats: (total: Int, today: Int, favorites: Int) {
        let today = memories.filter {
            Calendar.current.isDateInToday($0.timestamp)
        }.count
        let favs = memories.filter { $0.isFavorite }.count
        return (memories.count, today, favs)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(hue: 0.72, saturation: 0.85, brightness: 0.15),
                        Color(hue: 0.78, saturation: 0.6, brightness: 0.08),
                        .black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 250
                        )
                    )
                    .frame(width: 500, height: 500)
                    .offset(x: -100, y: -200)
                    .blur(radius: 80)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: 150, y: 300)
                    .blur(radius: 60)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        searchBar
                        statsRow
                        wowFeaturesSection
                        categoriesSection
                        recentMemoriesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSearch) {
                SearchView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showTimeline) {
                TimelineView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showGraph) {
                MemoryGraphView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showReplay) {
                DayReplayView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showStories) {
                StoryBuilderView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $selectedMemory) { item in
                MemoryDetailView(item: item)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    // MARK: – Subviews

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Memory")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Your personal AI recall")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 12) {
                Button { showTimeline = true } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .glassBackground(cornerRadius: 12)
                }

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .glassBackground(cornerRadius: 12)
                }
            }
        }
    }

    private var searchBar: some View {
        Button { showSearch = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.4))
                Text("Ask anything about your memories…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Image(systemName: "mic.fill")
                    .foregroundStyle(.purple.opacity(0.6))
            }
            .padding(14)
            .glassBackground(cornerRadius: 14)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Total", value: "\(stats.total)", icon: "brain.head.profile", color: .purple)
            StatCard(title: "Today", value: "\(stats.today)", icon: "clock.fill", color: .cyan)
            StatCard(title: "Starred", value: "\(stats.favorites)", icon: "star.fill", color: .yellow)
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = nil }
                    }
                    ForEach(MemoryCategory.allCases, id: \.self) { cat in
                        CategoryChip(
                            title: cat.displayName,
                            icon: cat.icon,
                            color: cat.color,
                            isSelected: selectedCategory == cat
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                }
            }
        }
    }

    private var wowFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Features")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FeatureCard(
                        title: "Memory Graph",
                        subtitle: "Explore connections",
                        icon: "point.3.connected.trianglepath.dotted",
                        gradient: [.purple, .blue]
                    ) { showGraph = true }

                    FeatureCard(
                        title: "Rewind Day",
                        subtitle: "Replay yesterday",
                        icon: "play.circle.fill",
                        gradient: [.indigo, .purple]
                    ) { showReplay = true }

                    FeatureCard(
                        title: "Life Stories",
                        subtitle: "AI-generated journal",
                        icon: "book.pages.fill",
                        gradient: [.pink, .orange]
                    ) { showStories = true }
                }
            }
        }
    }

    private var recentMemoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Memories")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button("See All") { showTimeline = true }
                    .font(.caption)
                    .foregroundStyle(.purple)
            }

            if filteredMemories.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredMemories.prefix(15)) { item in
                        MemoryCardView(item: item) {
                            selectedMemory = item
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("No memories yet")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Text("Copy text, save files, or add notes\nand they'll appear here.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .glassBackground()
    }
}

// MARK: – Feature Card

struct FeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(width: 130, alignment: .leading)
            .padding(14)
            .glassBackground(cornerRadius: 14)
        }
    }
}

// MARK: – Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassBackground(cornerRadius: 14)
    }
}

struct CategoryChip: View {
    let title: String
    var icon: String? = nil
    var color: Color = .white
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.25) : .white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? color : .white.opacity(0.6))
        }
    }
}
