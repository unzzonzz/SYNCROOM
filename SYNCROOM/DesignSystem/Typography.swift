//  Typography.swift
//  The typographic scale. Hierarchy in SYNCROOM is built from type first —
//  size, weight and tracking — before any container, border or colour is used.
//
//  Every style scales with Dynamic Type. `@ScaledMetric` drives the point size
//  from a system text style, and tracking is scaled by the same factor so tight
//  display tracking stays proportional at accessibility sizes instead of
//  collapsing the letterforms together.

import SwiftUI

/// One step on the type scale.
struct TypeStyle: Equatable, Sendable {
    let size: CGFloat
    let weight: Font.Weight
    /// Letter spacing at the base size, in points. Large type is tighter.
    let tracking: CGFloat
    /// The Dynamic Type style this scales against.
    let relativeTo: Font.TextStyle
    /// Numerals stay in tabular figures so counters and timers do not jitter.
    let monospacedDigit: Bool

    init(size: CGFloat,
         weight: Font.Weight,
         tracking: CGFloat,
         relativeTo: Font.TextStyle,
         monospacedDigit: Bool = false) {
        self.size = size
        self.weight = weight
        self.tracking = tracking
        self.relativeTo = relativeTo
        self.monospacedDigit = monospacedDigit
    }
}

extension TypeStyle {

    // Display — one per screen at most. These are the focal points.

    /// Large standalone figures: follower counts, broadcast metrics.
    static let displayStat = TypeStyle(size: 40, weight: .bold, tracking: -1.8,
                                       relativeTo: .largeTitle, monospacedDigit: true)
    /// The unit that trails a display figure ("만"), set smaller to keep the number dominant.
    static let displayUnit = TypeStyle(size: 21, weight: .semibold, tracking: -0.6, relativeTo: .title2)

    // Titles.

    /// Screen-level title where the screen owns its own heading.
    static let screenTitle = TypeStyle(size: 30, weight: .bold, tracking: -1.1, relativeTo: .largeTitle)
    /// The subject of a screen: a room title on the live detail screen.
    static let roomTitle = TypeStyle(size: 28, weight: .bold, tracking: -1.1, relativeTo: .title)
    /// A person's name at identity scale.
    static let identityName = TypeStyle(size: 26, weight: .bold, tracking: -1.0, relativeTo: .title)
    /// The app wordmark.
    static let wordmark = TypeStyle(size: 26, weight: .heavy, tracking: -0.9, relativeTo: .title)
    /// Section heading inside a scrolling screen.
    static let sectionTitle = TypeStyle(size: 20, weight: .bold, tracking: -0.7, relativeTo: .title3)

    // Body.

    /// Card and cell titles.
    static let cardTitle = TypeStyle(size: 17, weight: .semibold, tracking: -0.5, relativeTo: .headline)
    /// Settings-row and list-row titles.
    static let rowTitle = TypeStyle(size: 16, weight: .semibold, tracking: -0.4, relativeTo: .body)
    /// Default reading size.
    static let body = TypeStyle(size: 15, weight: .medium, tracking: -0.35, relativeTo: .subheadline)
    /// Body weight raised for names and button labels.
    static let bodyStrong = TypeStyle(size: 15, weight: .semibold, tracking: -0.4, relativeTo: .subheadline)

    // Chat.

    static let chatMessage = TypeStyle(size: 14, weight: .medium, tracking: -0.3, relativeTo: .subheadline)
    static let chatHandle = TypeStyle(size: 14, weight: .semibold, tracking: -0.3, relativeTo: .subheadline)

    // Metadata.

    /// Secondary metadata: counts, descriptions, timestamps.
    static let meta = TypeStyle(size: 13, weight: .medium, tracking: -0.25, relativeTo: .footnote)
    /// The emphasised figures inside a metadata line, and inline text buttons.
    static let metaStrong = TypeStyle(size: 13, weight: .semibold, tracking: -0.3, relativeTo: .footnote)
    /// Chip labels and the label under a display figure.
    static let chip = TypeStyle(size: 12, weight: .semibold, tracking: -0.2, relativeTo: .caption)

    /// Elapsed broadcast time. Tabular so the digits do not shift each second.
    static let timer = TypeStyle(size: 15, weight: .semibold, tracking: -0.3,
                                 relativeTo: .subheadline, monospacedDigit: true)
}

extension View {
    /// Applies a step of the type scale, scaling both size and tracking with Dynamic Type.
    func typography(_ style: TypeStyle) -> some View {
        modifier(TypographyModifier(style))
    }
}

extension Text {
    /// `Text`-preserving variant, for composing runs inside a single paragraph.
    func typography(_ style: TypeStyle) -> Text {
        let font = Font.system(size: style.size, weight: style.weight)
        return self.font(style.monospacedDigit ? font.monospacedDigit() : font)
            .tracking(style.tracking)
    }
}

private struct TypographyModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let style: TypeStyle

    init(_ style: TypeStyle) {
        self.style = style
        _scaledSize = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        let font = Font.system(size: scaledSize, weight: style.weight)
        // Keep tracking proportional to the realised size.
        return content
            .font(style.monospacedDigit ? font.monospacedDigit() : font)
            .tracking(style.tracking * (scaledSize / style.size))
    }
}
