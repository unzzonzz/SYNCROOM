//  HashtagChipRow.swift
//  Hashtags, in the forms the app needs: read-only chips that wrap and clip,
//  a single line that ends in a "+N" count, and a selectable grid.
//
//  Tags are stored bare; the `#` is added here so the prefix can never be
//  double-applied or forgotten.
//
//  Wrapping is computed from a measured width rather than inside a custom
//  `Layout`. A `Layout` is asked for its size before its container knows how
//  wide it will be, and neither answer to an unbounded proposal is right:
//  report the whole line and every ancestor inflates to fit it, report less and
//  the row gets *placed* at a width that disagrees with what it measured, so the
//  overflow draws on top of what sits below. Reading the real width once cannot
//  disagree with itself.

import SwiftUI
import UIKit

/// One chip. A small control, so a full pill.
struct HashtagChip: View {
    let tag: String
    var isSelected: Bool = false

    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = Metric.chipHeight

    var body: some View {
        Text(Format.hashtag(tag))
            .typography(.chip)
            .foregroundStyle(isSelected ? Palette.surface : Palette.inkChip)
            .lineLimit(1)
            .padding(.horizontal, Space.s12)
            .frame(height: height)
            .background(isSelected ? Palette.ink : Palette.surfaceRaised, in: .capsule)
    }
}

/// How a row that cannot fit every tag should end.
enum HashtagOverflow: Sendable {
    /// Simply stop. Used where the tags are decoration around a name.
    case clip
    /// End with a count of what was left out. Used on the live card, where the
    /// row is one line and the card's height has to be constant.
    case count
}

/// Read-only hashtags.
struct HashtagChipRow: View {
    let tags: [String]
    var maxLines: Int? = Metric.hashtagMaxLines
    var overflow: HashtagOverflow = .clip
    /// Follows the block it belongs to — leading inside a card, centred under a
    /// centred profile identity.
    var alignment: HorizontalAlignment = .leading

    @State private var availableWidth: CGFloat = 0
    @ScaledMetric(relativeTo: .caption) private var chipHeight: CGFloat = Metric.chipHeight
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            switch overflow {
            case .count: countingLine
            case .clip: wrappingRows
            }
        }
        .frame(maxWidth: .infinity, minHeight: reservedHeight,
               alignment: Alignment(horizontal: alignment, vertical: .top))
        // Reads the width the parent actually gave us, without influencing it.
        .background {
            Color.clear
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    availableWidth = width
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(tags.map(Format.hashtag).joined(separator: ", ")))
    }

    // MARK: - One line, ending in a count

    @ViewBuilder
    private var countingLine: some View {
        let split = countingSplit
        HStack(spacing: Space.s8) {
            ForEach(split.shown, id: \.self) { tag in
                HashtagChip(tag: tag)
                    // Only bites in the extreme case where a single tag is wider
                    // than the whole row; everywhere else it is inert.
                    .frame(maxWidth: split.firstChipCap)
            }
            if split.hidden > 0 {
                OverflowCount(count: split.hidden)
            }
        }
    }

    /// How many tags fit on one line once room is left for the count that
    /// follows them.
    ///
    /// The count's own width depends on how many are hidden, which depends on
    /// how many fit — so this walks down from "all of them" and takes the first
    /// arrangement that actually fits, rather than estimating.
    private var countingSplit: (shown: [String], hidden: Int, firstChipCap: CGFloat?) {
        guard availableWidth > 0, !tags.isEmpty else { return ([], 0, nil) }

        let widths = tags.map { Self.chipWidth(for: $0, typeSize: typeSize) }

        for count in stride(from: tags.count, through: 1, by: -1) {
            let hidden = tags.count - count
            var needed = widths[0..<count].reduce(0, +) + Space.s8 * CGFloat(count - 1)
            if hidden > 0 {
                needed += Space.s8 + Self.countWidth(hidden, typeSize: typeSize)
            }
            if needed <= availableWidth {
                return (Array(tags.prefix(count)), hidden, nil)
            }
        }

        // Not even one tag fits: show one, truncated, and count the rest. A blank
        // line would be worse than a shortened tag.
        let hidden = tags.count - 1
        let countRoom = hidden > 0 ? Space.s8 + Self.countWidth(hidden, typeSize: typeSize) : 0
        return ([tags[0]], hidden, max(0, availableWidth - countRoom))
    }

    // MARK: - Wrapping rows

    @ViewBuilder
    private var wrappingRows: some View {
        VStack(alignment: alignment, spacing: Space.s8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Space.s8) {
                    ForEach(row, id: \.self) { tag in
                        HashtagChip(tag: tag)
                    }
                }
            }
        }
    }

    /// Reserving the full line budget keeps every card in a shelf the same
    /// height, and stops the block resizing as the measured width arrives.
    private var reservedHeight: CGFloat {
        guard !tags.isEmpty else { return 0 }
        let lines = overflow == .count ? 1 : (maxLines ?? 1)
        return chipHeight * CGFloat(lines) + Space.s8 * CGFloat(lines - 1)
    }

    private var rows: [[String]] {
        guard availableWidth > 0 else { return [] }

        var rows: [[String]] = []
        var current: [String] = []
        var used: CGFloat = 0

        for tag in tags {
            let width = Self.chipWidth(for: tag, typeSize: typeSize)
            let needed = current.isEmpty ? width : used + Space.s8 + width

            if needed > availableWidth, !current.isEmpty {
                rows.append(current)
                if let maxLines, rows.count == maxLines { return rows }
                current = [tag]
                used = width
            } else {
                current.append(tag)
                used = needed
            }
        }
        if !current.isEmpty { rows.append(current) }
        if let maxLines { return Array(rows.prefix(maxLines)) }
        return rows
    }

    // MARK: - Measurement

    private static func scaledChipFont(_ typeSize: DynamicTypeSize) -> UIFont {
        let size = UIFontMetrics(forTextStyle: .caption1).scaledValue(for: TypeStyle.chip.size)
        return .systemFont(ofSize: size, weight: .semibold)
    }

    /// A chip's rendered width: its text at the current Dynamic Type size, plus
    /// the horizontal padding on both sides.
    private static func chipWidth(for tag: String, typeSize: DynamicTypeSize) -> CGFloat {
        let text = Format.hashtag(tag) as NSString
        let width = text.size(withAttributes: [.font: scaledChipFont(typeSize)]).width
        return ceil(width) + Space.s12 * 2
    }

    /// The count carries no chip background, so it costs only its text.
    private static func countWidth(_ count: Int, typeSize: DynamicTypeSize) -> CGFloat {
        let text = "+\(count)" as NSString
        return ceil(text.size(withAttributes: [.font: scaledChipFont(typeSize)]).width)
    }
}

/// How many tags did not fit.
///
/// Deliberately not a chip: no `#`, no fill, quieter ink. It reports a number,
/// and must not read as another tag waiting to be tapped.
private struct OverflowCount: View {
    let count: Int

    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = Metric.chipHeight

    var body: some View {
        Text(verbatim: "+\(count)")
            .typography(.chip)
            .foregroundStyle(Palette.inkTertiary)
            .lineLimit(1)
            .frame(height: height)
            .fixedSize()
            .accessibilityHidden(true)
    }
}

/// Selectable hashtags, with a cap on how many can be on at once.
struct HashtagPicker: View {
    let tags: [String]
    @Binding var selection: Set<String>
    var limit: Int

    var body: some View {
        FlowLayout(spacing: Space.s8, lineSpacing: Space.s8) {
            ForEach(tags, id: \.self) { tag in
                let isSelected = selection.contains(tag)
                Button {
                    if isSelected {
                        selection.remove(tag)
                    } else if selection.count < limit {
                        selection.insert(tag)
                    }
                } label: {
                    HashtagChip(tag: tag, isSelected: isSelected)
                }
                .buttonStyle(.plain)
                // At the limit, the unselected chips genuinely cannot be used.
                .disabled(!isSelected && selection.count >= limit)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .motion(value: selection)
    }
}

#Preview("Counting line — the live card's form", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s16) {
        ForEach([1, 2, 4, 6, 10], id: \.self) { n in
            HashtagChipRow(tags: Array(Fixtures.manyHashtags.prefix(n)),
                           maxLines: 1, overflow: .count)
        }
        // A single tag wider than the row: shown truncated, never blank.
        HashtagChipRow(tags: ["아주아주긴해시태그이름입니다정말로", "B", "C"],
                       maxLines: 1, overflow: .count)
    }
    .frame(width: Metric.liveCardWidth)
    .padding(Space.s24)
    .background(Palette.surface)
}

#Preview("Wrapping — everywhere else", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s24) {
        HashtagChipRow(tags: Fixtures.seungchan.hashtags)
        HashtagChipRow(tags: Fixtures.longform.hashtags)
        HashtagChipRow(tags: Fixtures.user.hashtags, maxLines: 1)
    }
    .frame(width: 249)
    .padding(Space.s24)
    .background(Palette.surface)
}

#Preview("Counting line — accessibility3") {
    VStack(alignment: .leading, spacing: Space.s16) {
        HashtagChipRow(tags: Fixtures.manyHashtags, maxLines: 1, overflow: .count)
        HashtagChipRow(tags: Fixtures.seungchan.hashtags, maxLines: 1, overflow: .count)
    }
    .frame(width: Metric.liveCardWidth)
    .padding(Space.s24)
    .background(Palette.surface)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Centred — under a profile identity", traits: .sizeThatFitsLayout) {
    VStack(spacing: Space.s12) {
        AvatarView(artist: Fixtures.seungchan, size: Metric.avatarXL)
        NameLabel(artist: Fixtures.seungchan, style: .identityName, badgeSize: 20)
        HashtagChipRow(tags: Fixtures.seungchan.hashtags, alignment: .center)
        HashtagChipRow(tags: Fixtures.manyHashtags, alignment: .center)
    }
    .frame(width: 360)
    .padding(Space.s24)
    .background(Palette.surface)
}

#Preview("Picker — five at most", traits: .sizeThatFitsLayout) {
    @Previewable @State var selection: Set<String> = ["R&B", "CCM"]
    HashtagPicker(tags: Fixtures.selectableHashtags, selection: $selection, limit: 5)
        .frame(width: 320)
        .padding(Space.s24)
        .background(Palette.surface)
}
