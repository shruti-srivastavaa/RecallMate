import SwiftUI

/// Small colored pill displaying a category's icon and label.
struct CategoryBadge: View {
    let category: MemoryCategory
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2)
            if !compact {
                Text(category.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(category.color.opacity(0.2))
        )
        .overlay(
            Capsule()
                .stroke(category.color.opacity(0.4), lineWidth: 0.5)
        )
        .foregroundStyle(category.color)
    }
}

#Preview {
    HStack {
        ForEach(MemoryCategory.allCases, id: \.self) { cat in
            CategoryBadge(category: cat)
        }
    }
    .padding()
    .background(.black)
}
