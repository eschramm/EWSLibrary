//
//  FlowLayout.swift
//  EWSLibrary
//
//  A wrapping SwiftUI layout for chips/tags. Places subviews left-to-right,
//  wrapping to a new row when the next subview would overflow the available
//  width. Shared across apps (e.g. iQIF, StattyCaddy2) for tag clouds.
//

#if canImport(SwiftUI)
import SwiftUI

public struct FlowLayout: Layout {

    public var spacing: CGFloat

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        var size = CGSize.zero
        var rowHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            if rowWidth + viewSize.width + spacing > maxWidth {
                size.width = max(size.width, rowWidth)
                size.height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += viewSize.width + spacing
            rowHeight = max(rowHeight, viewSize.height)
        }
        size.width = max(size.width, rowWidth)
        size.height += rowHeight
        return size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        let maxWidth = bounds.width
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            if rowWidth + viewSize.width + spacing > maxWidth {
                origin.x = bounds.origin.x
                origin.y += rowHeight + spacing
                rowHeight = 0
                rowWidth = 0
            }
            view.place(at: CGPoint(x: origin.x + rowWidth, y: origin.y), proposal: ProposedViewSize(viewSize))
            rowWidth += viewSize.width + spacing
            rowHeight = max(rowHeight, viewSize.height)
        }
    }
}
#endif
