//  ButtonStyles.swift
//  Button styles for *content* controls.
//
//  Liquid Glass boundary: anything that floats over media or lives in the
//  navigation layer uses the system `.glass` / `.glassProminent` styles instead.
//  These two are for buttons that sit inside the content column, where glass
//  would be wrong — content is opaque in this design system.

import SwiftUI

/// A filled secondary action: the paired buttons on a profile, sheet actions.
struct SyncFilledButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .typography(.bodyStrong)
            .foregroundStyle(isProminent ? Palette.surface : Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: Metric.controlM)
            .background(background(pressed: configuration.isPressed),
                        in: .rect(cornerRadius: Radius.pill(Metric.controlM)))
            .contentShape(.rect(cornerRadius: Radius.pill(Metric.controlM)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }

    private func background(pressed: Bool) -> Color {
        if isProminent {
            return Palette.ink
        }
        return pressed ? Palette.surfaceStrong : Palette.surfaceRaised
    }
}

/// A text-only action. Carries no container, so it never competes with the
/// content it sits beside.
struct SyncQuietButtonStyle: ButtonStyle {
    var role: Role = .secondary

    enum Role { case secondary, destructive }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .typography(.metaStrong)
            .foregroundStyle(role == .destructive ? Palette.signalLive : Palette.inkSecondary)
            .frame(minHeight: Metric.tapTarget)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SyncFilledButtonStyle {
    /// Filled with `surfaceRaised` — the default in-content action.
    static var syncFilled: SyncFilledButtonStyle { SyncFilledButtonStyle() }
    /// Filled with ink — for the single strongest action in a content column.
    static var syncSolid: SyncFilledButtonStyle { SyncFilledButtonStyle(isProminent: true) }
}

extension ButtonStyle where Self == SyncQuietButtonStyle {
    static var syncQuiet: SyncQuietButtonStyle { SyncQuietButtonStyle() }
    static var syncDestructive: SyncQuietButtonStyle { SyncQuietButtonStyle(role: .destructive) }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: Space.s16) {
        HStack(spacing: Space.s12) {
            Button("프로필 수정") {}.buttonStyle(.syncFilled)
            Button("프로필 공유") {}.buttonStyle(.syncFilled)
        }
        Button("신청 보내기") {}.buttonStyle(.syncSolid)
        Button("전체삭제") {}.buttonStyle(.syncQuiet)
        Button("회원 탈퇴") {}.buttonStyle(.syncDestructive)
    }
    .padding(Space.s24)
    .background(Palette.surface)
}
