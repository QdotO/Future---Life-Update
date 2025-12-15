import SwiftUI

/// A layout that arranges its children in a flowing, wrapping pattern
/// similar to how text wraps to the next line.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var alignment: VerticalAlignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, placement) in result.placements.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y),
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    private struct ArrangementResult {
        var size: CGSize
        var placements: [Placement]
    }

    private struct Placement {
        var x: CGFloat
        var y: CGFloat
        var size: CGSize
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews)
        -> ArrangementResult
    {
        var placements: [Placement] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        let maxContainerWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            // Check if we need to wrap to next line
            if currentX + size.width > maxContainerWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            placements.append(Placement(x: currentX, y: currentY, size: size))

            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX - spacing)
        }

        let totalHeight = currentY + rowHeight

        return ArrangementResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            placements: placements
        )
    }
}

#Preview {
    FlowLayout(spacing: 8) {
        ForEach(
            ["Option 1", "Longer option 2", "Opt 3", "Another option here", "Short"], id: \.self
        ) { text in
            Text(text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.blue.opacity(0.2)))
        }
    }
    .padding()
}
