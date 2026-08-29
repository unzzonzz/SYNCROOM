//  VerifiedBadge.swift
//  The verification mark that follows a name. Built from a circle and a check
//  rather than a symbol so it keeps the same geometric weight as the rest of the
//  design language at every size.

import SwiftUI

struct VerifiedBadge: View {
    var size: CGFloat = 14

    var body: some View {
        Circle()
            .fill(Palette.ink)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(Palette.surface)
            }
            .accessibilityLabel("인증된 아티스트")
    }
}

/// A name with its verification mark, so the pairing is identical everywhere a
/// name appears.
struct NameLabel: View {
    let artist: Artist
    var style: TypeStyle = .bodyStrong
    var badgeSize: CGFloat = 14

    var body: some View {
        HStack(spacing: Space.s4) {
            Text(artist.displayName)
                .typography(style)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            if artist.isVerified {
                VerifiedBadge(size: badgeSize)
            }
        }
    }
}

#Preview("Badge sizes", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s16) {
        NameLabel(artist: Fixtures.seungchan, style: .identityName, badgeSize: 20)
        NameLabel(artist: Fixtures.seungchan, style: .cardTitle, badgeSize: 15)
        NameLabel(artist: Fixtures.seungchan, style: .meta, badgeSize: 13)
        NameLabel(artist: Fixtures.user, style: .bodyStrong)
    }
    .padding(Space.s24)
    .background(Palette.surface)
}
