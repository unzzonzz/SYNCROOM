//  Tokens.swift
//  Design-system constants. Every colour, spacing, radius and dimension used by
//  SYNCROOM lives here — views never hardcode a value.
//
//  Liquid Glass note: this file deliberately contains NO glass or material tokens.
//  Glass is a *system* material owned by the platform (tab bar, toolbar, sheets,
//  `.glassEffect` controls). The content surfaces below are opaque, so content
//  never competes with — or imitates — the system glass layer.

import SwiftUI

// MARK: - Colour

/// Semantic colour tokens, backed by asset-catalog colour sets that carry
/// light / dark **and** high-contrast variants. Dark Mode and Increase Contrast
/// are therefore resolved by the system, not by branching in view code.
enum Palette {

    // Surfaces — the opaque ground content sits on.
    static let surface = Color(.surface)
    /// Chips, search fields, secondary buttons — a quiet step up from `surface`.
    static let surfaceRaised = Color(.surfaceRaised)
    /// Media placeholders: thumbnails, avatars, hero banners.
    static let surfaceStrong = Color(.surfaceStrong)

    // Ink — three text levels, measured against `surface`:
    //   ink 19.2:1 · inkSecondary 4.70:1 (AA body) · inkTertiary 3.14:1
    /// Primary text and primary geometry.
    static let ink = Color(.ink)
    /// Secondary text: metadata, descriptions, chat handles. Meets AA at body size.
    static let inkSecondary = Color(.inkSecondary)
    /// Non-text glyphs (chevrons, dismiss marks) and placeholder text.
    /// Meets the 3:1 floor for non-text UI; never use it for essential prose.
    static let inkTertiary = Color(.inkTertiary)
    /// Chip labels, which sit on `surfaceRaised` rather than on `surface`.
    static let inkChip = Color(.inkChip)
    /// The rare structural rule, and the `·` separator in metadata lines.
    static let hairline = Color(.hairline)

    // Signals — colour as information, never as decoration.
    // Each is a FILL that carries `onSignal` text. None is legible as small text
    // on `surface`, so none is ever used that way.
    /// Broadcasting right now. Also the app's single accent, and destructive actions.
    static let signalLive = Color(.signalLive)
    /// Needs attention but is not an error: marginal latency, no input detected.
    static let signalCaution = Color(.signalCaution)
    /// Confirmed good: healthy latency, an accepted request.
    static let signalSuccess = Color(.signalSuccess)
    /// A distinct participant state: currently performing in the room.
    static let signalSpecial = Color(.signalSpecial)
    /// Text and glyphs drawn on top of any signal fill.
    static let onSignal = Color(.onSignal)

    // Video. Footage is dark in both colour schemes — it is content, not chrome.
    static let stream = Color(.stream)
    static let onStream = Color(.onStream)

    /// Tints for the default avatar. A palette of its own, deliberately *not*
    /// the signal colours: an avatar identifies a person, it does not signal
    /// anything, and it must never compete with the one accent. Low-chroma on
    /// purpose so a screen full of them stays quiet.
    ///
    /// Pick with `avatarTint(for:)` — never at random, or the same person would
    /// change colour between screens.
    static let avatarTints: [Color] = [
        Color(.avatarTint1), Color(.avatarTint2), Color(.avatarTint3),
        Color(.avatarTint4), Color(.avatarTint5), Color(.avatarTint6),
    ]

    /// The tint for a given identity, stable for the life of the app and across
    /// launches.
    ///
    /// `String.hashValue` is seeded per process, so it would give the same
    /// person a different colour on every launch. This is an explicit FNV-1a so
    /// the mapping is genuinely deterministic.
    static func avatarTint(for identity: String) -> Color {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in identity.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return avatarTints[Int(hash % UInt64(avatarTints.count))]
    }
}

// MARK: - Spacing

/// The spacing scale. Named by value so a wrong step is hard to write by accident.
/// Whitespace is the primary grouping device here — reach for a larger step
/// before reaching for a divider.
nonisolated enum Space {
    static let s4: CGFloat = 4
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32
    static let s40: CGFloat = 40
    static let s48: CGFloat = 48
    static let s64: CGFloat = 64
    static let s80: CGFloat = 80
    static let s96: CGFloat = 96
    static let s120: CGFloat = 120
    static let s160: CGFloat = 160
}

// MARK: - Radius

nonisolated enum Radius {
    /// Thumbnails and video tiles.
    static let media: CGFloat = 16
    /// Inline emphasis containers, e.g. a highlighted donation message.
    static let panel: CGFloat = 18
    /// Grouped blocks and bottom accessories.
    static let surface: CGFloat = 20
    /// Hero banners and other large surfaces.
    static let hero: CGFloat = 24

    /// Small controls are full pills: radius = height / 2.
    static func pill(_ height: CGFloat) -> CGFloat { height / 2 }
}

// MARK: - Metric

nonisolated enum Metric {
    /// The single horizontal alignment line every screen shares.
    static let screenMargin: CGFloat = 24
    /// Minimum interactive area, per HIG.
    static let tapTarget: CGFloat = 44

    // Avatars.
    static let avatarXL: CGFloat = 80   // profile identity
    static let avatarL: CGFloat = 48    // artist rows
    static let avatarM: CGFloat = 32    // host row, list rows
    static let avatarS: CGFloat = 26    // chat messages
    static let avatarXS: CGFloat = 20   // card host line

    // Aspect ratios.
    static let thumbnail: CGFloat = 2.0        // live card thumbnail
    static let hero: CGFloat = 2.9             // home hero banner
    static let stream: CGFloat = 16.0 / 9.0    // video

    // Control heights.
    static let controlM: CGFloat = 48          // primary / secondary buttons, search field
    /// Chip height — and the diameter of any avatar sitting on the same line as
    /// a chip, so the two share one rhythm at every Dynamic Type size.
    static let chipHeight: CGFloat = 26
    static let settingsRow: CGFloat = 52

    // Shelf cards carry a fixed width rather than a fraction of their container.
    // A card whose width comes from the parent proposal cannot have a constant
    // height, because everything inside it re-wraps as the proposal changes.
    static let liveCardWidth: CGFloat = 240
    static let artistCardWidth: CGFloat = 264

    /// Hashtag rows clip after two lines rather than pushing the layout around.
    static let hashtagMaxLines: Int = 2
}

// MARK: - Motion

/// Motion carries information (a panel opened, a list reordered). It is never
/// decorative, and it always yields to Reduce Motion.
nonisolated enum Motion {
    static let standard: Animation = .snappy(duration: 0.28)
    static let quick: Animation = .snappy(duration: 0.18)
}

extension View {
    /// Animates `value` with `animation`, honouring the Reduce Motion setting.
    func motion<V: Equatable>(_ animation: Animation = Motion.standard, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
