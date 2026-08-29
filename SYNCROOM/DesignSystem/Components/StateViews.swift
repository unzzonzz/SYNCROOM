//  StateViews.swift
//  Empty, loading and error states, plus the inline banner and toast.
//
//  Empty states are built from one large line of type, one short explanation and
//  at most one action — no decorative artwork, per the design system.

import SwiftUI

// MARK: - Empty

struct EmptyStateView: View {
    let title: LocalizedStringKey
    var message: LocalizedStringKey?
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text(title)
                .typography(.roomTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let message {
                Text(message)
                    .typography(.body)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.syncFilled)
                    .padding(.top, Space.s12)
                    .frame(maxWidth: 220, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Space.s48)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Error

struct ErrorStateView: View {
    let error: DataSourceError
    var retry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text(error.errorDescription ?? "")
                .typography(.roomTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .typography(.body)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let retry {
                Button("다시 시도", action: retry)
                    .buttonStyle(.syncFilled)
                    .padding(.top, Space.s12)
                    .frame(maxWidth: 220, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Space.s48)
    }
}

// MARK: - Loading

/// Placeholder geometry for content that has not arrived yet. Where real
/// content already exists, prefer `.skeleton(_:)` on that content instead.
struct LoadingSkeleton: View {
    var rows: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s24) {
            ForEach(0..<rows, id: \.self) { _ in
                VStack(alignment: .leading, spacing: Space.s12) {
                    RoundedRectangle(cornerRadius: Radius.media)
                        .fill(Palette.surfaceStrong)
                        .aspectRatio(Metric.thumbnail, contentMode: .fit)
                    RoundedRectangle(cornerRadius: Radius.pill(14))
                        .fill(Palette.surfaceStrong)
                        .frame(width: 160, height: 14)
                }
            }
        }
        .accessibilityHidden(true)
        .accessibilityLabel("불러오는 중")
    }
}

extension View {
    /// Redacts real content while it loads, stops it accepting input, and gives
    /// it a slow pulse so a wait reads as work in progress rather than as a
    /// frozen screen.
    func skeleton(_ isActive: Bool) -> some View {
        modifier(SkeletonModifier(isActive: isActive))
    }
}

private struct SkeletonModifier: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    /// A pulse, not a shimmer. A travelling highlight would need a gradient, and
    /// the two gradients this app allows itself are both spoken for; opacity
    /// carries the same "still loading" meaning without spending the budget.
    private var isPulsing: Bool { isActive && !reduceMotion }

    func body(content: Content) -> some View {
        content
            .redacted(reason: isActive ? .placeholder : [])
            .disabled(isActive)
            .opacity(isPulsing && dimmed ? 0.45 : 1)
            .animation(
                isPulsing
                    ? .easeInOut(duration: 0.85).repeatForever(autoreverses: true)
                    : .none,
                value: dimmed
            )
            .task(id: isActive) {
                dimmed = isActive
            }
    }
}

// MARK: - Inline banner

/// A single-line status message that belongs to the content beneath it:
/// a lost connection, a missing input signal.
struct InlineBanner: View {

    enum Kind {
        case caution, error, success

        var fill: Color {
            switch self {
            case .caution: Palette.signalCaution
            case .error: Palette.signalLive
            case .success: Palette.signalSuccess
            }
        }
    }

    let kind: Kind
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: Space.s12) {
            Text(message)
                .typography(.metaStrong)
                .foregroundStyle(Palette.onSignal)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .typography(.metaStrong)
                        .foregroundStyle(Palette.onSignal)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.s16)
        .padding(.vertical, Space.s12)
        .background(kind.fill, in: .rect(cornerRadius: Radius.panel))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Toast

struct Toast: Identifiable, Equatable, Sendable {
    let id = UUID()
    var message: String
}

private struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    /// Extra room below the safe area, for screens that already put controls at
    /// the top. Without it the toast lands on the same line as them.
    var topInset: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    Text(toast.message)
                        .typography(.bodyStrong)
                        .foregroundStyle(Palette.onSignal)
                        .padding(.horizontal, Space.s16)
                        .padding(.vertical, Space.s12)
                        .background(Palette.signalLive, in: .capsule)
                        .padding(.horizontal, Metric.screenMargin)
                        // Sit below the top edge rather than on it. Full-screen
                        // covers let their content run under the status bar, so
                        // a toast pinned flat to `.top` arrives behind the island
                        // and reads as clipped. `topInset` then clears whatever
                        // the screen already puts up there — on the broadcast and
                        // the live room that is the glass control row, which the
                        // toast would otherwise land squarely on top of.
                        .safeAreaPadding(.top)
                        .padding(.top, Space.s12 + topInset)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: toast.id) {
                            try? await Task.sleep(for: .seconds(2.5))
                            self.toast = nil
                        }
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .motion(value: toast)
    }
}

extension View {
    /// Shows a transient message that dismisses itself.
    ///
    /// `topInset` is for screens that already occupy the top of their own
    /// bounds — pass the height of that band so the toast appears under it.
    func toast(_ toast: Binding<Toast?>, topInset: CGFloat = 0) -> some View {
        modifier(ToastModifier(toast: toast, topInset: topInset))
    }
}

/// The band the live room and the broadcast screen reserve for their floating
/// glass controls, which a toast on those screens has to clear.
nonisolated enum ToastInset {
    static let belowStreamControls: CGFloat = Metric.tapTarget + Space.s16
}

#Preview("Empty") {
    EmptyStateView(title: "아직 받은 알림이 없어요",
                   message: "팔로우한 아티스트가 라이브를 시작하면 여기에 알려드릴게요.",
                   actionTitle: "아티스트 찾아보기") {}
        .padding(.horizontal, Metric.screenMargin)
        .background(Palette.surface)
}

#Preview("Error") {
    ErrorStateView(error: .offline) {}
        .padding(.horizontal, Metric.screenMargin)
        .background(Palette.surface)
}

#Preview("Loading") {
    LoadingSkeleton()
        .padding(.horizontal, Metric.screenMargin)
        .background(Palette.surface)
}

#Preview("Banners", traits: .sizeThatFitsLayout) {
    VStack(spacing: Space.s12) {
        InlineBanner(kind: .caution, message: "입력 신호가 감지되지 않습니다")
        InlineBanner(kind: .error, message: "연결이 끊어졌어요", actionTitle: "다시 시도") {}
        InlineBanner(kind: .success, message: "참여가 수락되었어요")
    }
    .padding(Space.s24)
    .background(Palette.surface)
}
