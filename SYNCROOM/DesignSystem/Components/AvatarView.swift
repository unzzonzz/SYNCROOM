//  AvatarView.swift
//  A person, drawn as a circle.
//
//  There is no native API that generates a portrait for someone who has not
//  uploaded one, so the default is the platform's own person symbol rather than
//  an invented illustration. Its tint is derived from the person's identity, so
//  the same person is the same colour on every screen and after every relaunch —
//  the colour is a recognition aid, not decoration, which is why it is never
//  random.

import SwiftUI

struct AvatarView: View {
    /// Stable identity the tint is derived from — a handle, or any id that does
    /// not change between screens.
    let identity: String
    let url: URL?
    let size: CGFloat

    init(identity: String, url: URL? = nil, size: CGFloat = Metric.avatarM) {
        self.identity = identity
        self.url = url
        self.size = size
    }

    init(artist: Artist, size: CGFloat = Metric.avatarM) {
        self.init(identity: artist.handle, url: artist.avatarURL, size: size)
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty, .failure:
                // Loading and failure both fall back to the same mark, so a
                // slow or broken image never leaves a hole in the layout.
                placeholder
            @unknown default:
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        // The avatar always accompanies a name that is already on screen.
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFill()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Palette.avatarTint(for: identity))
    }
}

#Preview("Sizes", traits: .sizeThatFitsLayout) {
    HStack(alignment: .bottom, spacing: Space.s16) {
        AvatarView(artist: Fixtures.seungchan, size: Metric.chipHeight)
        AvatarView(artist: Fixtures.seungchan, size: Metric.avatarS)
        AvatarView(artist: Fixtures.seungchan, size: Metric.avatarM)
        AvatarView(artist: Fixtures.seungchan, size: Metric.avatarL)
        AvatarView(artist: Fixtures.seungchan, size: Metric.avatarXL)
    }
    .padding(Space.s24)
    .background(Palette.surface)
}

#Preview("Tints are per-person and stable", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s16) {
        ForEach(Fixtures.allArtists) { artist in
            HStack(spacing: Space.s12) {
                AvatarView(artist: artist, size: Metric.avatarL)
                // Rendered twice: the same person must be the same colour in
                // both places, and in every relaunch.
                AvatarView(artist: artist, size: Metric.avatarL)
                Text(artist.displayName)
                    .typography(.body)
                    .foregroundStyle(Palette.ink)
            }
        }
    }
    .padding(Space.s24)
    .background(Palette.surface)
}

#Preview("Dark") {
    VStack(spacing: Space.s16) {
        ForEach(Fixtures.allArtists.prefix(4)) { artist in
            AvatarView(artist: artist, size: Metric.avatarXL)
        }
    }
    .padding(Space.s24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}
