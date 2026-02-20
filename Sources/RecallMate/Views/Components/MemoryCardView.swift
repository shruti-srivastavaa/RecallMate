import SwiftUI

/// Reusable card component for displaying a memory item.
struct MemoryCardView: View {
    let item: MemoryItem
    var onTap: (() -> Void)? = nil

    @State private var isPressed = false

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 10) {
                // Header row
                HStack(alignment: .top) {
                    // Category icon circle
                    ZStack {
                        Circle()
                            .fill(item.category.color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: item.category.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(item.category.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(item.source)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                // Content preview
                Text(item.content)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Footer
                HStack {
                    CategoryBadge(category: item.category, compact: true)
                    Spacer()
                    Text(item.relativeTime)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(14)
            .glassBackground(cornerRadius: 16)
        }
        .buttonStyle(CardButtonStyle())
    }
}

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
