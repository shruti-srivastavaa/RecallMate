import SwiftUI

/// AI-generated life stories from memory data — daily summaries, weekly highlights, monthly reports.
struct StoryBuilderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var generator: StoryGenerator
    @State private var isLoading = true
    @State private var expandedStory: UUID?

    init() {
        _generator = StateObject(wrappedValue: StoryGenerator(
            context: PersistenceController.shared.container.viewContext
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // Ambient
                VStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.pink.opacity(0.15), Color.orange.opacity(0.1), .clear],
                            center: .center, startRadius: 0, endRadius: 300
                        ))
                        .frame(width: 600, height: 600)
                        .offset(y: -150)
                    Spacer()
                }

                if isLoading {
                    loadingView
                } else if generator.stories.isEmpty {
                    emptyView
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Hero section
                            heroCard

                            // Story cards
                            ForEach(generator.stories) { story in
                                storyCard(story)
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Life Stories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.pink)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear { loadStories() }
        }
    }

    // MARK: – Hero Card

    private var heroCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 36))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(LinearGradient(
                    colors: [.pink, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Your Life Journal")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("AI-generated stories from your memories")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.pink.opacity(0.3), .orange.opacity(0.2), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: – Story Card

    private func storyCard(_ story: LifeStory) -> some View {
        let isExpanded = expandedStory == story.id

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.35)) {
                    expandedStory = isExpanded ? nil : story.id
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: story.gradient.compactMap { Color(hex: $0) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 44, height: 44)
                        Image(systemName: story.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(story.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(story.subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Spacer()

                    Text("\(story.memoryCount)")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.7))

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(16)
            }

            if isExpanded {
                Divider().overlay(.white.opacity(0.1)).padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    // Narrative
                    Text(story.narrative)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineSpacing(4)

                    // Stats row
                    statsRow(story.stats)

                    // Categories
                    if !story.stats.categories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Activity Breakdown")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))

                            ForEach(story.stats.categories) { cat in
                                HStack(spacing: 8) {
                                    Text(cat.name)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                        .frame(width: 80, alignment: .leading)

                                    GeometryReader { geo in
                                        let ratio = CGFloat(cat.count) / CGFloat(story.stats.totalMemories)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(LinearGradient(
                                                colors: story.gradient.compactMap { Color(hex: $0) },
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            .frame(width: geo.size.width * ratio)
                                    }
                                    .frame(height: 6)

                                    Text("\(cat.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                    }

                    // Key entities
                    if !story.stats.topEntities.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Key People & Places")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))

                            FlowLayout(spacing: 6) {
                                ForEach(story.stats.topEntities) { entity in
                                    Text("\(entity.name) (\(entity.mentions))")
                                        .font(.caption2)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(.white.opacity(0.08)))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                    }

                    // Share button
                    Button {
                        // Share action
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Story")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white.opacity(0.06))
                        )
                        .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func statsRow(_ stats: StoryStats) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(stats.totalMemories)", label: "Memories", icon: "brain")
            Spacer()
            statItem(value: "\(stats.filesSaved)", label: "Files", icon: "doc.fill")
            Spacer()
            statItem(value: "\(stats.clipboardCopies)", label: "Copied", icon: "doc.on.clipboard")
            Spacer()
            statItem(value: "\(stats.linksVisited)", label: "Links", icon: "link")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.04))
        )
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.pink.opacity(0.6))
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: – Helpers

    private func loadStories() {
        Task {
            await generator.generateStories()
            await MainActor.run { isLoading = false }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.pink)
                .scaleEffect(1.2)
            Text("Crafting your stories…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient(
                    colors: [.pink, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text("No stories yet")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.6))
            Text("Add memories throughout the day to generate stories")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: – Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .init(frame.size))
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let width = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: width, height: y + rowH), frames)
    }
}

// MARK: – Color from Hex

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
