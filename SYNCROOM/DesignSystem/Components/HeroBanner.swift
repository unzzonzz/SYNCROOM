//  HeroBanner.swift
//  The home carousel slide, and the bar indicator beneath it.
//
//  The slide carries the room's name rather than sitting empty: a banner that
//  says nothing is decoration, and decoration is what this design system spends
//  its budget avoiding.

import SwiftUI

struct HeroBanner: View {
    let room: LiveRoom

    var body: some View {
        AsyncImage(url: room.thumbnailURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Palette.surfaceStrong
        }
        .aspectRatio(Metric.hero, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: Space.s8) {
                if room.status == .live {
                    LiveIndicator(size: .medium)
                }
                Text(room.title)
                    .typography(.cardTitle)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }
            .padding(Space.s20)
        }
        .clipShape(.rect(cornerRadius: Radius.hero))
        .contentShape(.rect(cornerRadius: Radius.hero))
        .accessibilityElement(children: .combine)
    }
}

/// Carousel position, drawn as bars rather than dots — the active bar is longer,
/// so position reads as a measurement rather than as a row of decorations.
struct PageIndicator: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: Space.s4) {
            ForEach(0..<max(count, 0), id: \.self) { position in
                Capsule()
                    .fill(position == index ? Palette.ink : Palette.hairline)
                    .frame(width: position == index ? 28 : 12, height: 3)
            }
        }
        .motion(value: index)
        .accessibilityElement()
        .accessibilityLabel("페이지")
        .accessibilityValue(Text(verbatim: "\(index + 1) / \(count)"))
    }
}

#Preview {
    @Previewable @State var index = 0
    VStack(alignment: .leading, spacing: Space.s12) {
        HeroBanner(room: Fixtures.chansRoom)
        PageIndicator(count: 3, index: index)
    }
    .padding(.horizontal, Metric.screenMargin)
    .background(Palette.surface)
    .onTapGesture { index = (index + 1) % 3 }
}
