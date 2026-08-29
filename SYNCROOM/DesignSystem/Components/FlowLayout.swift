//  FlowLayout.swift
//  A wrapping row layout, used wherever chips need to fill the width and then
//  wrap — with a hard line budget so a long hashtag list clips instead of
//  pushing the rest of a card down the screen.

import SwiftUI

nonisolated struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat
    /// Rows beyond this are dropped. `nil` means no limit.
    var maxLines: Int?

    init(spacing: CGFloat = Space.s8, lineSpacing: CGFloat = Space.s8, maxLines: Int? = nil) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.maxLines = maxLines
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = resolvedWidth(proposal.width, subviews: subviews)
        let rows = rows(for: subviews, availableWidth: width)
        let widest = rows.map(\.width).max() ?? 0

        // Reserve the full line budget rather than measuring it.
        //
        // A container measures its children before it knows its own width, so
        // this can be asked for a size with an unbounded proposal and then be
        // *placed* at a real, narrower width. Measured height would then say one
        // row while placement produced two, and the overflow row would draw on
        // top of whatever sits below. A fixed budget cannot disagree with
        // placement, and it has the side effect the design wants anyway: every
        // card in a shelf reserves the same block, so the shelf lines up.
        let rowHeight = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        let lines = maxLines.map { subviews.isEmpty ? 0 : $0 } ?? rows.count
        let height = rowHeight * CGFloat(lines) + lineSpacing * CGFloat(max(0, lines - 1))

        return CGSize(width: min(width, widest), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, availableWidth: resolvedWidth(bounds.width, subviews: subviews))
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    /// A wrapping row cannot be narrower than its widest single chip, so a zero
    /// or near-zero proposal is resolved up to that floor.
    ///
    /// SwiftUI probes a layout with a zero-width proposal to discover its
    /// minimum. Answering "zero" is taken literally: the row then gets *placed*
    /// at zero width, every chip lands on its own line at natural size, and the
    /// result is a stack of overlapping chips spilling out of the card.
    private func resolvedWidth(_ proposed: CGFloat?, subviews: Subviews) -> CGFloat {
        let floor = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        // An unbounded proposal must resolve to the floor, not to the sum of every
        // chip. Reporting the full single-line width as the ideal makes every
        // ancestor — the text column, the card — size itself to fit all the chips
        // on one line, and the card then overflows its slot in the shelf. A
        // wrapping row is genuinely happy to be one chip wide; that is what it
        // should say.
        guard let proposed, proposed > 0, proposed.isFinite else { return floor }
        return max(proposed, floor)
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, availableWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if needed > availableWidth, !current.indices.isEmpty {
                rows.append(current)
                if let maxLines, rows.count == maxLines { return rows }
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        if let maxLines, rows.count > maxLines { return Array(rows.prefix(maxLines)) }
        return rows
    }
}

/// A single row of chips that runs off the edge instead of wrapping.
///
/// The important property is that it never reports a width larger than it was
/// offered. A plain `HStack` of natural-width chips inflates its ancestors until
/// the whole card is too wide to fit its shelf slot, and clipping afterwards is
/// too late — the damage is to the parent's size, not to the drawing. Here the
/// measured width is capped at the proposal, so the parent stays the size it
/// meant to be and the overflow is a clean cut.
nonisolated struct SingleLineChipLayout: Layout {
    var spacing: CGFloat

    init(spacing: CGFloat = Space.s8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        guard !sizes.isEmpty else { return .zero }
        let natural = sizes.reduce(0) { $0 + $1.width }
            + spacing * CGFloat(sizes.count - 1)
        let height = sizes.map(\.height).max() ?? 0
        // Never answer a zero-width probe with zero, and never answer an
        // unbounded one with the whole row: one chip is the floor in both cases.
        let floor = sizes.map(\.width).max() ?? 0
        let resolved: CGFloat
        if let width = proposal.width, width > 0, width.isFinite {
            resolved = max(width, floor)
        } else {
            resolved = floor
        }
        return CGSize(width: min(resolved, natural), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            // Drop a chip that would only half fit. A chip sliced through its
            // own background reads as broken rendering rather than as "there is
            // more" — the first chip is always placed so the row is never empty.
            if index != subviews.startIndex, x + size.width > bounds.maxX { return }
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
        }
    }
}
