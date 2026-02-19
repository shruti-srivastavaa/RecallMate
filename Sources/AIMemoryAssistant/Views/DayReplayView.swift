import SwiftUI

/// Cinematic day replay — auto-scrolling timeline that plays back your day's memories.
struct DayReplayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var memories: [MemoryItem] = []
    @State private var isPlaying = false
    @State private var currentIndex = 0
    @State private var playbackSpeed: Double = 1.0
    @State private var showDatePicker = false
    @State private var revealedCards: Set<Int> = []
    @State private var timer: Timer?

    private let timeBlocks = ["🌅 Morning", "☀️ Afternoon", "🌇 Evening", "🌙 Night"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // Ambient gradient
                VStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.indigo.opacity(0.2), .clear],
                            center: .center, startRadius: 0, endRadius: 250
                        ))
                        .frame(width: 500, height: 500)
                        .offset(y: -100)
                    Spacer()
                }

                VStack(spacing: 0) {
                    // Playback controls
                    playbackControls

                    if memories.isEmpty {
                        emptyDay
                    } else {
                        // Timeline content
                        ScrollViewReader { proxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(spacing: 0) {
                                    ForEach(groupedByTimeBlock(), id: \.0) { block, items in
                                        timeBlockHeader(block)
                                        ForEach(items.indices, id: \.self) { idx in
                                            let globalIdx = globalIndex(for: block, localIndex: idx)
                                            timelineCard(memory: items[idx], index: globalIdx)
                                                .id(globalIdx)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 100)
                            }
                            .onChange(of: currentIndex) { _, newVal in
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo(newVal, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rewind My Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.indigo)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showDatePicker.toggle() } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear { loadMemories() }
            .onDisappear { stopPlayback() }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
        }
    }

    // MARK: – Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 20) {
            // Date label
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text("\(memories.count) moments")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            // Speed selector
            Menu {
                Button("0.5×") { playbackSpeed = 0.5 }
                Button("1×") { playbackSpeed = 1.0 }
                Button("2×") { playbackSpeed = 2.0 }
                Button("3×") { playbackSpeed = 3.0 }
            } label: {
                Text("\(playbackSpeed, specifier: "%.1f")×")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .foregroundStyle(.white)
            }

            // Skip back
            Button {
                currentIndex = max(0, currentIndex - 1)
                revealCard(currentIndex)
            } label: {
                Image(systemName: "backward.fill")
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Play/Pause
            Button {
                isPlaying ? stopPlayback() : startPlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .indigo.opacity(0.5), radius: 8)
            }

            // Skip forward
            Button {
                currentIndex = min(memories.count - 1, currentIndex + 1)
                revealCard(currentIndex)
            } label: {
                Image(systemName: "forward.fill")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    // MARK: – Timeline Card

    private func timeBlockHeader(_ block: String) -> some View {
        HStack {
            Text(block)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private func timelineCard(memory: MemoryItem, index: Int) -> some View {
        let isRevealed = revealedCards.contains(index)
        let isCurrent = index == currentIndex && isPlaying

        return HStack(alignment: .top, spacing: 12) {
            // Timeline line + dot
            VStack(spacing: 0) {
                Circle()
                    .fill(isCurrent ? Color.indigo : Color.white.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .shadow(color: isCurrent ? .indigo.opacity(0.8) : .clear, radius: 6)

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 10)

            // Card
            VStack(alignment: .leading, spacing: 6) {
                // Time
                if let timestamp = memory.timestamp {
                    Text(timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                }

                // Content
                HStack(spacing: 8) {
                    Image(systemName: memory.category.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.purple)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.purple.opacity(0.15)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(memory.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(memory.content.prefix(60))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(isRevealed ? 1 : 0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isCurrent ? Color.indigo.opacity(0.5) : .white.opacity(0.05),
                                lineWidth: 1
                            )
                    )
            )
            .opacity(isRevealed ? 1 : 0.2)
            .scaleEffect(isRevealed ? 1 : 0.95)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isRevealed)
        }
        .padding(.vertical, 4)
    }

    // MARK: – State

    private func startPlayback() {
        isPlaying = true
        revealCard(currentIndex)
        timer = Timer.scheduledTimer(withTimeInterval: 1.5 / playbackSpeed, repeats: true) { _ in
            guard currentIndex < memories.count - 1 else {
                stopPlayback()
                return
            }
            currentIndex += 1
            revealCard(currentIndex)
        }
    }

    private func stopPlayback() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func revealCard(_ index: Int) {
        withAnimation { revealedCards.insert(index) }
    }

    private func loadMemories() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let request = MemoryItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp < %@",
            start as NSDate, end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MemoryItem.timestamp, ascending: true)]
        memories = (try? viewContext.fetch(request)) ?? []
        currentIndex = 0
        revealedCards = []
    }

    private func groupedByTimeBlock() -> [(String, [MemoryItem])] {
        let calendar = Calendar.current
        var groups: [(String, [MemoryItem])] = []

        let morning = memories.filter { m in
            guard let t = m.timestamp else { return false }
            let h = calendar.component(.hour, from: t)
            return h >= 5 && h < 12
        }
        let afternoon = memories.filter { m in
            guard let t = m.timestamp else { return false }
            let h = calendar.component(.hour, from: t)
            return h >= 12 && h < 17
        }
        let evening = memories.filter { m in
            guard let t = m.timestamp else { return false }
            let h = calendar.component(.hour, from: t)
            return h >= 17 && h < 21
        }
        let night = memories.filter { m in
            guard let t = m.timestamp else { return false }
            let h = calendar.component(.hour, from: t)
            return h >= 21 || h < 5
        }

        if !morning.isEmpty { groups.append((timeBlocks[0], morning)) }
        if !afternoon.isEmpty { groups.append((timeBlocks[1], afternoon)) }
        if !evening.isEmpty { groups.append((timeBlocks[2], evening)) }
        if !night.isEmpty { groups.append((timeBlocks[3], night)) }

        return groups
    }

    private func globalIndex(for block: String, localIndex: Int) -> Int {
        var offset = 0
        for (b, items) in groupedByTimeBlock() {
            if b == block { return offset + localIndex }
            offset += items.count
        }
        return localIndex
    }

    // MARK: – SubViews

    private var emptyDay: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text("No memories for this day")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.6))
            Text("Try picking a different date")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxHeight: .infinity)
    }

    private var datePickerSheet: some View {
        VStack(spacing: 20) {
            Text("Pick a Day to Replay")
                .font(.headline)
                .foregroundStyle(.white)

            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.indigo)

            Button("Replay This Day") {
                showDatePicker = false
                loadMemories()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            )
            .foregroundStyle(.white)
        }
        .padding(24)
        .presentationDetents([.medium])
        .background(Color(hue: 0.72, saturation: 0.5, brightness: 0.1).ignoresSafeArea())
    }
}
