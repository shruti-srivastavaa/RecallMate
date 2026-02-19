import SwiftUI

/// Interactive force-directed graph showing relationships between entities in memories.
struct MemoryGraphView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var extractor: EntityExtractor
    @State private var nodes: [GraphNode] = []
    @State private var edges: [GraphEdge] = []
    @State private var selectedNode: GraphNode?
    @State private var isLoading = true
    @State private var timer: Timer?
    @State private var draggedNode: String?

    init() {
        _extractor = StateObject(wrappedValue: EntityExtractor(
            context: PersistenceController.shared.container.viewContext
        ))
    }

    private let nodeColors: [String: Color] = [
        "green": .green,
        "pink": .pink,
        "blue": .blue,
        "orange": .orange,
        "purple": .purple,
        "cyan": .cyan,
        "yellow": .yellow,
        "red": .red
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // Ambient background
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.purple.opacity(0.15), .clear],
                        center: .center, startRadius: 10, endRadius: 300
                    ))
                    .frame(width: 600, height: 600)
                    .blur(radius: 60)

                if isLoading {
                    loadingView
                } else if nodes.isEmpty {
                    emptyView
                } else {
                    graphCanvas
                }
            }
            .navigationTitle("Memory Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.purple)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear { loadGraph() }
            .onDisappear { timer?.invalidate() }
            .sheet(item: $selectedNode) { node in
                NodeDetailSheet(node: node)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: – Graph Canvas

    private var graphCanvas: some View {
        GeometryReader { geo in
            ZStack {
                // Edges
                ForEach(edges) { edge in
                    if let sourceNode = nodes.first(where: { $0.id == edge.source }),
                       let targetNode = nodes.first(where: { $0.id == edge.target }) {
                        Path { path in
                            path.move(to: CGPoint(x: sourceNode.x, y: sourceNode.y))
                            path.addLine(to: CGPoint(x: targetNode.x, y: targetNode.y))
                        }
                        .stroke(
                            LinearGradient(
                                colors: [
                                    nodeColor(sourceNode).opacity(0.3),
                                    nodeColor(targetNode).opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                    }
                }

                // Nodes
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    nodeView(node: node, index: index)
                        .position(x: node.x, y: node.y)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggedNode = node.id
                                    nodes[index].x = value.location.x
                                    nodes[index].y = value.location.y
                                    nodes[index].vx = 0
                                    nodes[index].vy = 0
                                }
                                .onEnded { _ in
                                    draggedNode = nil
                                }
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedNode = node
                            }
                        }
                }
            }
            .onAppear {
                initializePositions(in: geo.size)
                startSimulation(in: geo.size)
            }
        }
    }

    private func nodeView(node: GraphNode, index: Int) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(nodeColor(node).opacity(0.2))
                    .frame(width: node.radius, height: node.radius)
                    .overlay(
                        Circle()
                            .stroke(nodeColor(node).opacity(0.6), lineWidth: 1.5)
                    )
                    .shadow(color: nodeColor(node).opacity(0.4), radius: 8)

                Image(systemName: node.type.icon)
                    .font(.system(size: node.radius * 0.35, weight: .semibold))
                    .foregroundStyle(nodeColor(node))
            }

            Text(node.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .frame(maxWidth: 60)
        }
        .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.02), value: nodes.count)
    }

    // MARK: – Physics Simulation

    private func initializePositions(in size: CGSize) {
        let cx = size.width / 2
        let cy = size.height / 2

        for i in nodes.indices {
            let angle = (2 * .pi / Double(nodes.count)) * Double(i)
            let radius = min(size.width, size.height) * 0.3
            nodes[i].x = cx + CGFloat(cos(angle)) * radius + CGFloat.random(in: -20...20)
            nodes[i].y = cy + CGFloat(sin(angle)) * radius + CGFloat.random(in: -20...20)
        }
    }

    private func startSimulation(in size: CGSize) {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            simulationStep(in: size)
        }

        // Stop after 5 seconds to save battery
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [self] in
            timer?.invalidate()
        }
    }

    private func simulationStep(in size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let damping: CGFloat = 0.85
        let repulsion: CGFloat = 3000
        let attraction: CGFloat = 0.005
        let centerGravity: CGFloat = 0.01

        for i in nodes.indices {
            guard nodes[i].id != draggedNode else { continue }

            var fx: CGFloat = 0
            var fy: CGFloat = 0

            // Repulsion (all nodes push each other away)
            for j in nodes.indices where i != j {
                let dx = nodes[i].x - nodes[j].x
                let dy = nodes[i].y - nodes[j].y
                let dist = max(sqrt(dx * dx + dy * dy), 1)
                let force = repulsion / (dist * dist)
                fx += (dx / dist) * force
                fy += (dy / dist) * force
            }

            // Attraction (connected nodes pull toward each other)
            for edge in edges where edge.source == nodes[i].id || edge.target == nodes[i].id {
                let otherId = edge.source == nodes[i].id ? edge.target : edge.source
                guard let j = nodes.firstIndex(where: { $0.id == otherId }) else { continue }
                let dx = nodes[j].x - nodes[i].x
                let dy = nodes[j].y - nodes[i].y
                fx += dx * attraction
                fy += dy * attraction
            }

            // Center gravity
            fx += (centerX - nodes[i].x) * centerGravity
            fy += (centerY - nodes[i].y) * centerGravity

            // Apply forces
            nodes[i].vx = (nodes[i].vx + fx) * damping
            nodes[i].vy = (nodes[i].vy + fy) * damping
            nodes[i].x += nodes[i].vx
            nodes[i].y += nodes[i].vy

            // Bounds
            nodes[i].x = max(30, min(size.width - 30, nodes[i].x))
            nodes[i].y = max(30, min(size.height - 30, nodes[i].y))
        }
    }

    // MARK: – Helpers

    private func nodeColor(_ node: GraphNode) -> Color {
        nodeColors[node.color] ?? .purple
    }

    private func loadGraph() {
        Task {
            await extractor.buildGraph()
            await MainActor.run {
                nodes = extractor.nodes
                edges = extractor.edges
                isLoading = false
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.purple)
                .scaleEffect(1.2)
            Text("Building memory graph…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient(
                    colors: [.purple, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text("Not enough data for graph")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.6))
            Text("Add more memories to see connections")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// MARK: – Node Detail Sheet

struct NodeDetailSheet: View, Identifiable {
    let node: GraphNode
    var id: String { node.id }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: node.type.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.label)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(node.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Text("\(node.weight) mentions")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.purple.opacity(0.2)))
                    .foregroundStyle(.purple)
            }

            Divider().overlay(.white.opacity(0.1))

            Text("This entity appears across \(node.weight) memories. Tap to explore related files, conversations, and places.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(24)
        .background(Color(hue: 0.72, saturation: 0.5, brightness: 0.1).ignoresSafeArea())
    }
}

extension GraphNode: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
