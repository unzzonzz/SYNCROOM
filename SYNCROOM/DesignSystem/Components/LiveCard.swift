//  LiveCard.swift
//  A room in a horizontal shelf.
//
//  No border, no shadow, no container fill: the thumbnail is the only surface,
//  and everything below it is grouped by spacing and type weight alone. The
//  caller sets the width — usually with `.containerRelativeFrame` — so cards
//  peek past the screen edge at any device size.

import SwiftUI

struct LiveCard: View {
    let room: LiveRoom
    var onTapHost: (() -> Void)?

    /// The host avatar shares the chip height, so the avatar and the hashtag row
    /// below it sit on one rhythm — and stay on it as Dynamic Type grows.
    @ScaledMetric(relativeTo: .caption) private var hostAvatarSize: CGFloat = Metric.chipHeight

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: room.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Palette.surfaceStrong
            }
            .aspectRatio(Metric.thumbnail, contentMode: .fit)
            .clipShape(.rect(cornerRadius: Radius.media))

            // Up to two lines, but only as tall as the title actually is.
            // Reserving both lines unconditionally puts the slack *between* the
            // title and the meta line, which is exactly where a gap reads as a
            // mistake. A shelf takes its height from its tallest card instead,
            // so any slack lands at the bottom of the shorter ones where it is
            // simply margin.
            Text(room.title)
                .typography(.cardTitle)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.s12)

            RoomMetaLabel(participantCount: room.participantCount, viewerCount: room.viewerCount)
                .padding(.top, Space.s4)

            hostRow
                .padding(.top, Space.s12)

            if !room.hashtags.isEmpty {
                // One line that ends in a count. Two wrapped lines would make the
                // block's height depend on how many tags a room happens to have,
                // and the card's height with it.
                HashtagChipRow(tags: room.hashtags, maxLines: 1, overflow: .count)
                    .padding(.top, Space.s12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The thumbnail keeps its 2:1 ratio by absorbing whatever height is left
        // over, so without this a taller neighbour would squash it and the
        // shelf's thumbnails would come out different sizes.
        .fixedSize(horizontal: false, vertical: true)
    }

    private var hostRow: some View {
        let content = HStack(spacing: Space.s8) {
            AvatarView(artist: room.host, size: hostAvatarSize)
            NameLabel(artist: room.host, style: .metaStrong, badgeSize: 13)
        }
        .frame(height: hostAvatarSize)

        return Group {
            if let onTapHost {
                Button(action: onTapHost) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }
}

/// The compact, horizontal form used in search results.
struct LiveRowCard: View {
    let room: LiveRoom

    var body: some View {
        HStack(alignment: .top, spacing: Space.s12) {
            AsyncImage(url: room.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Palette.surfaceStrong
            }
            .frame(width: 112, height: 56)
            .clipShape(.rect(cornerRadius: Radius.media))

            VStack(alignment: .leading, spacing: Space.s4) {
                Text(room.title)
                    .typography(.bodyStrong)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                RoomMetaLabel(participantCount: room.participantCount, viewerCount: room.viewerCount)
                NameLabel(artist: room.host, style: .meta, badgeSize: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if room.status == .live {
                LiveIndicator(size: .small).padding(.top, Space.s8)
            }
        }
        .contentShape(.rect)
    }
}

/// A finished broadcast, sized for a two-column grid.
struct PastBroadcastTile: View {
    let broadcast: PastBroadcast

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            AsyncImage(url: broadcast.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Palette.surfaceStrong
            }
            .aspectRatio(Metric.thumbnail, contentMode: .fit)
            .clipShape(.rect(cornerRadius: Radius.media))

            Text(broadcast.title)
                .typography(.bodyStrong)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(Format.broadcastMeta(viewCount: broadcast.viewCount, endedAt: broadcast.endedAt))
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Shelf height follows the tallest card — 1/2-line title × 1/4/10 tags") {
    let titles = ["Title", "밤새도록 이어지는 어쿠스틱 세션 그리고 아주 긴 제목"]
    let counts = [1, 4, 10]
    ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: Space.s12) {
            ForEach(Array(titles.enumerated()), id: \.offset) { _, title in
                ForEach(counts, id: \.self) { count in
                    LiveCard(room: LiveRoom(title: title,
                                            host: Fixtures.seungchan,
                                            hashtags: Array(Fixtures.manyHashtags.prefix(count)),
                                            participantCount: 1,
                                            viewerCount: 8_304))
                        .frame(width: Metric.liveCardWidth)
                        // Tops align; the shelf is as tall as its tallest card.
                        .border(Palette.signalLive.opacity(0.35))
                }
            }
        }
        .padding(Metric.screenMargin)
    }
    .background(Palette.surface)
}

#Preview("Row + tile", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s24) {
        LiveRowCard(room: Fixtures.chansRoom)
        LiveRowCard(room: Fixtures.longformRoom)
        HStack(alignment: .top, spacing: Space.s12) {
            PastBroadcastTile(broadcast: Fixtures.pastBroadcasts[0])
            PastBroadcastTile(broadcast: Fixtures.pastBroadcasts[1])
        }
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}

#Preview("Loading") {
    LiveCard(room: Fixtures.chansRoom)
        .frame(width: 234)
        .skeleton(true)
        .padding(Metric.screenMargin)
        .background(Palette.surface)
}
