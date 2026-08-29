//  RoomMetaLabel.swift
//  `1명 참여중 · 8,304명 시청중`.
//
//  The figures carry the information, so they take the ink and the weight while
//  the words around them stay secondary. On the live detail screen the
//  participant half is tappable, which is why this is a row of parts rather than
//  one string.

import SwiftUI

struct RoomMetaLabel: View {
    let participantCount: Int
    let viewerCount: Int
    /// When set, the participant half becomes a control that opens the
    /// participant list.
    var onTapParticipants: (() -> Void)?

    var body: some View {
        HStack(spacing: Space.s4) {
            if let onTapParticipants {
                Button(action: onTapParticipants) {
                    participants
                }
                .buttonStyle(.plain)
            } else {
                participants
            }

            Text(verbatim: "·")
                .typography(.meta)
                .foregroundStyle(Palette.hairline)

            viewers
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Format.roomMeta(participants: participantCount,
                                                 viewers: viewerCount)))
        .accessibilityAddTraits(onTapParticipants == nil ? [] : .isButton)
    }

    // Two adjacent `Text` views rather than one concatenated run: the figure and
    // its unit need different weights and colours, and this keeps both scaling
    // with Dynamic Type. The line never wraps, so a stack is the right shape.
    private var participants: some View {
        HStack(spacing: 0) {
            Text(Format.count(participantCount))
                .typography(.metaStrong)
                .foregroundStyle(Palette.ink)
            Text("명 참여중")
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private var viewers: some View {
        HStack(spacing: 0) {
            Text(Format.count(viewerCount))
                .typography(.metaStrong)
                .foregroundStyle(Palette.ink)
            Text("명 시청중")
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s16) {
        RoomMetaLabel(participantCount: 1, viewerCount: 8_304)
        RoomMetaLabel(participantCount: 0, viewerCount: 0)
        RoomMetaLabel(participantCount: 3, viewerCount: 1_204_392, onTapParticipants: {})
    }
    .padding(Space.s24)
    .background(Palette.surface)
}
