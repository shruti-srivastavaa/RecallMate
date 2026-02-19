import SwiftUI

/// Detail view for a single memory item with actions.
struct MemoryDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var item: MemoryItem
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                LinearGradient(
                    colors: [
                        item.category.color.opacity(0.15),
                        Color(hue: 0.72, saturation: 0.5, brightness: 0.08),
                        .black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(item.category.color.opacity(0.2))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: item.category.icon)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(item.category.color)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    CategoryBadge(category: item.category)
                                    Text(item.source)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.4))
                                }

                                Spacer()

                                Button {
                                    item.isFavorite.toggle()
                                    try? viewContext.save()
                                } label: {
                                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                                        .font(.title3)
                                        .foregroundStyle(item.isFavorite ? .yellow : .white.opacity(0.4))
                                }
                            }

                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Text(item.timestamp, format: .dateTime.month().day().year().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        // Content
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Content")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.6))

                            Text(item.content)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.85))
                                .textSelection(.enabled)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassBackground(cornerRadius: 14)
                        }

                        // File path
                        if let path = item.filePath, !path.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("File Location")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white.opacity(0.6))

                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.orange)
                                    Text(path)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                        .lineLimit(2)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassBackground(cornerRadius: 12)
                            }
                        }

                        // Tags
                        if !item.tagArray.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white.opacity(0.6))

                                FlowLayout(spacing: 6) {
                                    ForEach(item.tagArray, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(.white.opacity(0.1)))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                            }
                        }

                        // Actions
                        VStack(spacing: 10) {
                            Button {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = item.content
                                #endif
                            } label: {
                                Label("Copy Content", systemImage: "doc.on.doc")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .glassBackground(cornerRadius: 12)
                                    .foregroundStyle(.white)
                            }

                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("Delete Memory", systemImage: "trash")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.red.opacity(0.15))
                                    )
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.purple)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .alert("Delete Memory?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    SpotlightIndexer.deindex(itemID: item.id)
                    viewContext.delete(item)
                    try? viewContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This memory will be permanently removed.")
            }
        }
    }
}

// MARK: – Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > containerWidth && currentX > 0 {
                currentX = 0
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            maxHeight = max(maxHeight, size.height)
            currentX += size.width + spacing
        }

        return CGSize(width: containerWidth, height: currentY + maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            maxHeight = max(maxHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
