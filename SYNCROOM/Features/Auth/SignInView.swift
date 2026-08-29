//  SignInView.swift  (S5)
//
//  Liquid Glass: the navigation bar is hidden here — the wordmark is the screen's
//  own heading and an empty glass bar above it would be chrome with nothing in
//  it. Every control is in the content column, so they use the opaque
//  `.syncFilled` style rather than glass; the one exception is Apple's own
//  `SignInWithAppleButton`, which is a system control and draws itself.

import AuthenticationServices
import SwiftUI

@MainActor
@Observable
final class SignInModel {

    /// The three social routes offered on this screen.
    enum Provider: String, Identifiable, Hashable, CaseIterable, Sendable {
        case apple, google, kakao
        var id: String { rawValue }
    }

    /// Which provider is being talked to right now; `nil` while idle. Every
    /// button on the screen is disabled while this is set, so two sign-ins can
    /// never be in flight at once.
    var pending: Provider?
    /// A provider sheet came back with something other than success.
    var failed = false

    var isBusy: Bool { pending != nil }

    init(pending: Provider? = nil, failed: Bool = false) {
        self.pending = pending
        self.failed = failed
    }

    /// Runs the Google / Kakao round trip. There is no backend in this build, so
    /// the wait stands in for the provider sheet — and, exactly as with Apple
    /// below, **no password is ever asked for and no credential is kept**.
    /// Returns whether the caller should advance the session.
    func signIn(with provider: Provider) async -> Bool {
        guard pending == nil else { return false }
        failed = false
        pending = provider
        defer { pending = nil }
        do {
            try await Task.sleep(for: .milliseconds(700))
        } catch {
            return false
        }
        return true
    }

    func beginAppleSignIn() {
        failed = false
        pending = .apple
    }

    /// Reads the *outcome* of the Apple sheet and nothing else: the
    /// `ASAuthorization` credential is deliberately never opened, copied or
    /// persisted anywhere in this app.
    func finishAppleSignIn(_ result: Result<ASAuthorization, any Error>) -> Bool {
        pending = nil
        switch result {
        case .success:
            return true
        case .failure(let error):
            // A dismissed sheet is a choice, not a failure worth reporting.
            if (error as? ASAuthorizationError)?.code == .canceled { return false }
            failed = true
            return false
        }
    }
}

struct SignInView: View {
    @Environment(SessionModel.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    @State private var model: SignInModel

    init(model: SignInModel = SignInModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s48) {
                brand
                providers
                terms
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Space.s96)
            .padding(.bottom, Space.s48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .motion(value: model.pending)
    }

    // MARK: - Brand

    private var brand: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Wordmark()

            Text("좋아하는 아티스트와 같은 방에서, 지금 함께 연주해요")
                .typography(.body)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Providers

    private var providers: some View {
        VStack(spacing: Space.s16) {
            if model.failed {
                InlineBanner(kind: .error,
                             message: "로그인을 완료하지 못했어요",
                             actionTitle: "닫기") {
                    model.failed = false
                }
            }

            appleButton

            Button {
                advance(with: .google)
            } label: {
                Text(model.pending == .google ? "연결 중" : "Google로 계속하기")
            }
            .buttonStyle(.syncFilled)

            Button {
                advance(with: .kakao)
            } label: {
                Text(model.pending == .kakao ? "연결 중" : "카카오로 계속하기")
            }
            .buttonStyle(.syncFilled)

            separator

            Button("이메일로 계속하기") {
                session.stage = .signUp
            }
            .buttonStyle(.syncFilled)
        }
        .disabled(model.isBusy)
    }

    /// Apple's own control, so the mark, the wording and its localisation all
    /// come from the system. Only the height and the corner are matched to the
    /// buttons beneath it.
    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
            model.beginAppleSignIn()
        } onCompletion: { result in
            if model.finishAppleSignIn(result) {
                session.signInWithProvider()
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: Metric.controlM)
        .clipShape(.rect(cornerRadius: Radius.pill(Metric.controlM)))
    }

    /// "또는" between the social routes and the email route. A rule earns its
    /// place here: it is what tells the two groups apart, so it is short, one
    /// device pixel thick, and hidden from VoiceOver.
    private var separator: some View {
        HStack(spacing: Space.s12) {
            rule
            Text("또는")
                .typography(.meta)
                .foregroundStyle(Palette.inkTertiary)
            rule
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    /// A hairline is a physical thing, not a step on the spacing scale, so it is
    /// measured in the display's own pixels.
    private var rule: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(width: Space.s32, height: 1 / displayScale)
    }

    // MARK: - Terms

    private var terms: some View {
        Text("계속하면 SYNCROOM의 이용약관과 개인정보 처리방침에 동의하는 것으로 봐요.")
            .typography(.meta)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Actions

    private func advance(with provider: SignInModel.Provider) {
        Task {
            if await model.signIn(with: provider) {
                session.signInWithProvider()
            }
        }
    }
}

// MARK: - Previews

private func previewSignIn(pending: SignInModel.Provider? = nil,
                           failed: Bool = false) -> some View {
    NavigationStack {
        SignInView(model: SignInModel(pending: pending, failed: failed))
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewSignIn().preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewSignIn().preferredColorScheme(.dark)
}

#Preview("로그인 진행 중") {
    previewSignIn(pending: .google)
}

#Preview("오류") {
    previewSignIn(failed: true)
}

#Preview("Dynamic Type — accessibility3") {
    previewSignIn().environment(\.dynamicTypeSize, .accessibility3)
}
