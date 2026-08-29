//  AuthFlowView.swift  (S5 → S8)
//
//  Liquid Glass: the whole onboarding flow shares one `NavigationStack`, so the
//  four steps inherit the system navigation bar and their back buttons are real
//  `.toolbar` items that the platform draws the glass capsule around. Nothing in
//  this folder paints a bar, a material or a translucent pane of its own — the
//  content column is opaque, which is what lets the system glass read as glass.

import SwiftUI

/// The signed-out half of the app. `RootView` shows this whenever
/// `session.isSignedIn` is false, and each step advances by moving
/// `session.stage` — there is no separate flow state to keep in sync.
struct AuthFlowView: View {
    @Environment(SessionModel.self) private var session

    var body: some View {
        NavigationStack {
            step
        }
        .motion(value: session.stage)
    }

    @ViewBuilder
    private var step: some View {
        switch session.stage {
        case .signedOut:
            SignInView()
        case .signUp:
            SignUpView()
        case .profileSetup:
            ProfileSetupView()
        case .followSuggestions:
            FollowSuggestionsView()
        case .signedIn:
            // `RootView` swaps this whole flow out for the tab shell; this arm
            // only covers the frame between the last step finishing and that
            // swap, so it is the ground colour and nothing else.
            Palette.surface
        }
    }
}

// MARK: - Shared parts

/// A quiet label above a field or a picker. Every onboarding screen carries one
/// navigation title and nothing else at title weight, so field labels stay on
/// the metadata step of the scale rather than competing with it. `detail` is the
/// trailing note a field sometimes needs — a limit, a count.
struct AuthFieldLabel: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
            Text(title)
                .typography(.metaStrong)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let detail {
                Spacer(minLength: Space.s8)
                Text(detail)
                    .typography(.meta)
                    .foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The opaque box every text field in the flow sits in. Fields are content, not
/// chrome, so this is a plain `surfaceRaised` fill — no material, no border.
///
/// It sets the horizontal inset and the minimum control height only; the vertical
/// inset belongs to whatever is inside, because a row that carries a 44pt control
/// beside its field needs no padding of its own to clear that height.
struct AuthFieldBox<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: Metric.controlM)
            .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.surface))
    }
}

/// A status line: a small filled mark carrying the signal, and an ordinary ink
/// label carrying the words. The signal is always the fill and never the text —
/// a signal colour is not legible as small type on `surface`.
struct AuthSignalMark: View {

    enum Kind {
        /// Not satisfied yet, and not a problem — a requirement still to meet.
        case pending
        /// In flight: a check that has not come back.
        case caution
        case success
        case error

        var fill: Color {
            switch self {
            case .pending: Palette.surfaceStrong
            case .caution: Palette.signalCaution
            case .success: Palette.signalSuccess
            case .error: Palette.signalLive
            }
        }

        /// `nil` for `.pending`, which is an unfilled state rather than a verdict.
        var symbol: String? {
            switch self {
            case .pending: nil
            case .caution: "ellipsis"
            case .success: "checkmark"
            case .error: "xmark"
            }
        }
    }

    let kind: Kind
    let message: LocalizedStringKey

    /// Sized off the spacing scale so the mark stays proportional to the
    /// metadata line it sits on.
    private let markSize = Space.s16

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
            Circle()
                .fill(kind.fill)
                .frame(width: markSize, height: markSize)
                .overlay {
                    if let symbol = kind.symbol {
                        Image(systemName: symbol)
                            .font(.system(size: markSize * 0.55, weight: .bold))
                            .foregroundStyle(Palette.onSignal)
                    }
                }
                // Baseline-align the mark with the first line of the label.
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - $0.height * 0.15 }

            Text(message)
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The bottom-pinned action of an onboarding step, for `.safeAreaInset(edge:)`.
///
/// It carries an opaque ground because the content beneath it scrolls: the
/// design system keeps content opaque, so this is a `surface` fill rather than a
/// pane of imitation glass.
struct AuthStepFooter<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: Space.s8) {
            content
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.vertical, Space.s16)
        .frame(maxWidth: .infinity)
        .background(Palette.surface)
    }
}

// MARK: - Previews

private func previewAuthFlow(_ stage: SessionModel.Stage) -> some View {
    let session = SessionModel()
    session.stage = stage
    return AuthFlowView()
        .environment(AppRouter())
        .environment(session)
        .environment(PlaybackController())
        .environment(SettingsStore())
}

#Preview("로그인 — 라이트") {
    previewAuthFlow(.signedOut).preferredColorScheme(.light)
}

#Preview("로그인 — 다크") {
    previewAuthFlow(.signedOut).preferredColorScheme(.dark)
}

#Preview("회원가입") {
    previewAuthFlow(.signUp)
}

#Preview("프로필 설정") {
    previewAuthFlow(.profileSetup)
}

#Preview("팔로우 추천") {
    previewAuthFlow(.followSuggestions)
}

#Preview("Dynamic Type — accessibility3") {
    previewAuthFlow(.signedOut).environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("공통 부품", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s24) {
        AuthFieldLabel(title: "해시태그", detail: "최대 5개")

        AuthFieldBox {
            Text("이메일 주소")
                .typography(.body)
                .foregroundStyle(Palette.inkTertiary)
                .padding(.vertical, Space.s12)
        }

        VStack(alignment: .leading, spacing: Space.s8) {
            AuthSignalMark(kind: .pending, message: "8자 이상")
            AuthSignalMark(kind: .caution, message: "확인중")
            AuthSignalMark(kind: .success, message: "사용 가능")
            AuthSignalMark(kind: .error, message: "이미 사용 중이에요")
        }

        AuthStepFooter {
            Button("다음") {}
                .buttonStyle(.syncSolid)
        }
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
