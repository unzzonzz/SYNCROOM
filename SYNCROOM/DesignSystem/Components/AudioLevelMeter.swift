//  AudioLevelMeter.swift
//  Input level, drawn as one bar. The value is the information, so the bar is
//  the whole component — no tick marks, no numeric read-out beside it.

import SwiftUI

struct AudioLevelMeter: View {
    /// 0…1.
    let level: Double
    var height: CGFloat = 8

    /// Above this, the input is close to clipping and the bar says so.
    private var isHot: Bool { level > 0.92 }

    var body: some View {
        Capsule()
            .fill(Palette.surfaceRaised)
            .frame(height: height)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(isHot ? Palette.signalLive : Palette.ink)
                    .scaleEffect(x: max(0, min(1, level)), y: 1, anchor: .leading)
            }
            .clipShape(.capsule)
            .motion(.linear(duration: 0.08), value: level)
            .accessibilityElement()
            .accessibilityLabel("입력 레벨")
            .accessibilityValue(Text(level.formatted(.percent.precision(.fractionLength(0)))))
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: Space.s16) {
        AudioLevelMeter(level: 0.0)
        AudioLevelMeter(level: 0.35)
        AudioLevelMeter(level: 0.7)
        AudioLevelMeter(level: 0.97)
        AudioLevelMeter(level: 0.6, height: 4)
    }
    .padding(Space.s24)
    .background(Palette.surface)
}

#Preview("Live") {
    @Previewable @State var source = AudioLevelSource()
    VStack(spacing: Space.s24) {
        AudioLevelMeter(level: source.level)
        Text("말하거나 연주해보세요")
            .typography(.meta)
            .foregroundStyle(Palette.inkSecondary)
    }
    .padding(Space.s24)
    .background(Palette.surface)
    .task { source.start() }
}
