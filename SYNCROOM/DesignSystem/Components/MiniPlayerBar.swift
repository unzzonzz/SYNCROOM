//  MiniPlayerBar.swift
//  The mini player, and the only thing that goes in `.tabViewBottomAccessory`.
//
//  Liquid Glass: this view draws NO background. The bottom accessory is a system
//  glass surface, so painting a panel behind this content would both fight the
//  platform material and break the tab-bar merge animation. It reads
//  `\.tabViewBottomAccessoryPlacement` and drops to a single line only when the
//  accessory collapses into the tab bar.

import SwiftUI

struct MiniPlayerBar: View {
    let room: LiveRoom

    /// Previews only. The real placement is system-driven and cannot be forced,
    /// so this is how both layouts get proved.
    var placementOverride: TabViewBottomAccessoryPlacement?

    @Environment(\.tabViewBottomAccessoryPlacement) private var systemPlacement
    @Environment(PlaybackController.self) private var playback

    private var placement: TabViewBottomAccessoryPlacement? {
        placementOverride ?? systemPlacement
    }


    var body: some View {
        HStack(spacing: Space.s12) {
            Button {
                playback.expand()
            } label: {
                content
            }
            .buttonStyle(.plain)

            Button {
                playback.stop()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: Metric.tapTarget, height: Metric.tapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("시청 종료")
        }
        .padding(.leading, Space.s16)
        .foregroundStyle(Palette.ink)
    }

    /// The same title and artist in every placement.
    ///
    /// The accessory changes size and position as the tab bar minimises, and
    /// swapping the layout at the same time means the player re-draws as
    /// something else mid-move. Keeping one layout lets the system simply carry
    /// it — and it sidesteps a mapping that could not be pinned down by
    /// observation, because the tab bar does not currently minimise at all.
    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(room.title)
                .typography(.chatHandle)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            HStack(spacing: Space.s4) {
                Text(room.host.displayName)
                    .typography(.chip)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                if room.host.isVerified {
                    VerifiedBadge(size: 12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("탭하면 라이브를 전체 화면으로 엽니다")
    }
}

#Preview(".expanded — title and artist, unchanged", traits: .sizeThatFitsLayout) {
    MiniPlayerBar(room: Fixtures.chansRoom, placementOverride: .expanded)
        .environment(PlaybackController())
        .padding(.vertical, Space.s8)
        .background(Palette.surfaceRaised)
}

#Preview(".inline — identical to .expanded, by design", traits: .sizeThatFitsLayout) {
    MiniPlayerBar(room: Fixtures.chansRoom, placementOverride: .inline)
        .environment(PlaybackController())
        .padding(.vertical, Space.s8)
        .background(Palette.surfaceRaised)
}

#Preview("Both, dark", traits: .sizeThatFitsLayout) {
    VStack(spacing: Space.s16) {
        MiniPlayerBar(room: Fixtures.chansRoom, placementOverride: .expanded)
        MiniPlayerBar(room: Fixtures.chansRoom, placementOverride: .inline)
    }
    .environment(PlaybackController())
    .padding(.vertical, Space.s8)
    .background(Palette.surfaceRaised)
    .preferredColorScheme(.dark)
}

#Preview("In the real accessory") {
    let playback = PlaybackController()
    playback.watch(Fixtures.chansRoom)
    playback.minimize()
    return RootView()
        .environment(SessionModel())
        .environment(AppRouter())
        .environment(playback)
        .environment(SettingsStore())
}
