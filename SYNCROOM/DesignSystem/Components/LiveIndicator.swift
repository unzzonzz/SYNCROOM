//  LiveIndicator.swift
//  "On air" — the app's single most important state, and the only place the
//  accent is allowed to appear at full strength.

import SwiftUI

struct LiveIndicator: View {

    enum Size {
        /// A bare dot, for overlaying on an avatar in a dense list.
        case small
        /// The default mark: a filled capsule reading LIVE.
        case medium
        /// The broadcast overlay mark.
        case large
    }

    var size: Size = .medium

    var body: some View {
        switch size {
        case .small:
            Circle()
                .fill(Palette.signalLive)
                .frame(width: 8, height: 8)
                .accessibilityLabel("라이브 중")
        case .medium:
            label(type: .chip, horizontal: Space.s8, vertical: Space.s4)
        case .large:
            label(type: .metaStrong, horizontal: Space.s12, vertical: Space.s8)
        }
    }

    private func label(type: TypeStyle, horizontal: CGFloat, vertical: CGFloat) -> some View {
        Text("LIVE")
            .typography(type)
            .foregroundStyle(Palette.onSignal)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(Palette.signalLive, in: .capsule)
            .accessibilityLabel("라이브 중")
    }
}

#Preview("Sizes", traits: .sizeThatFitsLayout) {
    HStack(spacing: Space.s16) {
        LiveIndicator(size: .small)
        LiveIndicator(size: .medium)
        LiveIndicator(size: .large)
    }
    .padding(Space.s24)
    .background(Palette.surface)
}
