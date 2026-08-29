//  ArtistCard.swift
//  An artist in a horizontal shelf, and the list-row form used everywhere a
//  vertical list of people appears.

import SwiftUI

/// Shelf form: avatar beside a name and a single clipped line of hashtags.
struct ArtistCard: View {
    let artist: Artist
    var showsLiveIndicator: Bool = false

    var body: some View {
        HStack(spacing: Space.s12) {
            AvatarView(artist: artist, size: Metric.avatarL)
                .overlay(alignment: .bottomTrailing) {
                    if showsLiveIndicator, artist.isLive {
                        LiveIndicator(size: .small)
                            .padding(2)
                            .background(Palette.surface, in: .circle)
                    }
                }

            VStack(alignment: .leading, spacing: Space.s8) {
                NameLabel(artist: artist, style: .bodyStrong)
                if !artist.hashtags.isEmpty {
                    HashtagChipRow(tags: artist.hashtags, maxLines: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(.rect)
    }
}

/// List form. The trailing slot takes whatever action the screen needs — a
/// follow toggle, a remove button, a role chip — so one row serves every list.
struct ArtistRow<Trailing: View>: View {
    let artist: Artist
    var showsHashtags: Bool = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Space.s12) {
            AvatarView(artist: artist, size: Metric.avatarL)

            VStack(alignment: .leading, spacing: Space.s4) {
                HStack(spacing: Space.s8) {
                    NameLabel(artist: artist, style: .bodyStrong)
                    if artist.isLive {
                        LiveIndicator(size: .small)
                    }
                }
                Text(Format.handle(artist.handle))
                    .typography(.meta)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                if showsHashtags, !artist.hashtags.isEmpty {
                    HashtagChipRow(tags: artist.hashtags, maxLines: 1)
                        .padding(.top, Space.s4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .frame(minHeight: Metric.tapTarget)
        .contentShape(.rect)
    }
}

extension ArtistRow where Trailing == EmptyView {
    init(artist: Artist, showsHashtags: Bool = false) {
        self.init(artist: artist, showsHashtags: showsHashtags) { EmptyView() }
    }
}

/// The follow toggle. One control with two states — never a button plus a badge
/// plus a label all saying the same thing.
struct FollowButton: View {
    let isFollowing: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isFollowing ? "팔로잉" : "팔로우")
                .typography(.chip)
                .foregroundStyle(isFollowing ? Palette.ink : Palette.surface)
                .padding(.horizontal, Space.s16)
                .frame(height: 32)
                .background(isFollowing ? Palette.surfaceRaised : Palette.ink,
                            in: .rect(cornerRadius: Radius.pill(32)))
        }
        .buttonStyle(.plain)
        .frame(minHeight: Metric.tapTarget)
        .accessibilityAddTraits(isFollowing ? .isSelected : [])
    }
}

#Preview("Shelf cards") {
    ScrollView(.horizontal) {
        HStack(spacing: Space.s16) {
            ForEach(Fixtures.recommendedArtists) { artist in
                ArtistCard(artist: artist).frame(width: 262)
            }
        }
        .padding(Metric.screenMargin)
    }
    .background(Palette.surface)
}

#Preview("Rows", traits: .sizeThatFitsLayout) {
    @Previewable @State var following = false
    VStack(spacing: Space.s16) {
        ArtistRow(artist: Fixtures.seungchan, showsHashtags: true) {
            FollowButton(isFollowing: following) { following.toggle() }
        }
        ArtistRow(artist: Fixtures.longform, showsHashtags: true) {
            FollowButton(isFollowing: true) {}
        }
        ArtistRow(artist: Fixtures.brightWolf)
        ArtistRow(artist: Fixtures.user) {
            RoleChip(role: .guitar)
        }
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
