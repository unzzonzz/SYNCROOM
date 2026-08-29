//  Wordmark.swift
//  The app's mark. Set in the same typeface as the rest of the app at its
//  heaviest weight — the identity comes from scale and tracking, not from a
//  decorative display face. Swap the body for an `Image` to drop in a logo.

import SwiftUI

struct Wordmark: View {
    var body: some View {
        Text(verbatim: "SYNCROOM")
            .typography(.wordmark)
            .foregroundStyle(Palette.ink)
            // The toolbar hands leading items a tight width budget; without this
            // the mark truncates to "S…".
            .lineLimit(1)
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    Wordmark()
        .padding(Space.s24)
        .background(Palette.surface)
}
