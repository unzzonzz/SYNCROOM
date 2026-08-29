//  GlassControlBar.swift
//  Floating controls that sit over video.
//
//  Liquid Glass: every glass element in the app is wrapped in a
//  `GlassEffectContainer` so neighbouring pieces blend and morph as one system
//  rather than rendering as separate overlapping panes. Controls use
//  `.interactive()` so they respond to touch the way system glass does, and a
//  dim layer goes behind them over footage so labels stay legible on a bright
//  frame.

import SwiftUI

/// Groups floating glass controls. Always use this rather than placing
/// `.glassEffect` views next to each other directly.
struct GlassControlBar<Content: View>: View {
    var spacing: CGFloat = Space.s20
    @ViewBuilder var content: Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            HStack(spacing: spacing) {
                content
            }
        }
    }
}

/// A round glass control. The tap target is never smaller than 44pt even when
/// the glyph is.
struct GlassCircleButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: Metric.tapTarget, height: Metric.tapTarget)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? Palette.onSignal : Palette.onStream)
        .glassEffect(isActive ? .regular.tint(Palette.signalLive).interactive()
                              : .regular.interactive(),
                     in: .circle)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// The dim that goes under glass controls placed over footage, so the controls
/// keep their contrast on a bright frame.
struct StreamScrim: View {
    var edge: VerticalEdge = .top

    var body: some View {
        LinearGradient(
            colors: [Palette.stream.opacity(0.55), Palette.stream.opacity(0)],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Controls over footage") {
    ZStack {
        Palette.stream
        VStack {
            GlassControlBar {
                GlassCircleButton(systemImage: "chevron.left", label: "닫기") {}
                Spacer()
                GlassCircleButton(systemImage: "ellipsis", label: "더보기") {}
            }
            .padding(.horizontal, Metric.screenMargin)

            Spacer()

            GlassControlBar {
                GlassCircleButton(systemImage: "mic.slash", label: "마이크 음소거", isActive: true) {}
                GlassCircleButton(systemImage: "video", label: "카메라") {}
                GlassCircleButton(systemImage: "person.badge.plus", label: "참여 요청") {}
                GlassCircleButton(systemImage: "slider.horizontal.3", label: "설정") {}
            }
        }
        .padding(.vertical, Space.s48)
    }
    .ignoresSafeArea()
}
