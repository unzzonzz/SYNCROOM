//  SignUpView.swift  (S6)
//
//  Liquid Glass: the only glass on screen is the system navigation bar the flow's
//  `NavigationStack` supplies, and the back button inside it — the platform draws
//  that capsule, so nothing here paints a bar. The form and the pinned "다음" are
//  content, and content in this design system is opaque.
//
//  The screen is a system `List`. The consent checklist is a run of like-for-like
//  rows, and a grouped list is what gives those rows their insets, their minimum
//  height and their separator inset — none of it written down here. The three text
//  fields are not list rows, so they opt out of that chrome and keep the flow's own
//  `Metric.screenMargin`, which is what the pinned button below them uses too.

import SwiftUI

// MARK: - Model

@MainActor
@Observable
final class SignUpModel {

    /// One rule the password has to satisfy, shown live as it is typed.
    enum Requirement: String, Identifiable, CaseIterable, Sendable {
        case length, letter, digit

        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .length: "8자 이상"
            case .letter: "영문 포함"
            case .digit: "숫자 포함"
            }
        }

        func isMet(in password: String) -> Bool {
            switch self {
            case .length: password.count >= 8
            case .letter: password.contains { $0.isLetter }
            case .digit: password.contains { $0.isNumber }
            }
        }
    }

    /// The one address this build already has an account for, taken from the
    /// fixture graph so the duplicate path is reachable without a server.
    static let registeredEmail = Fixtures.user.handle + "@syncroom.app"

    var email: String
    var password: String
    var confirmation: String
    /// The password field is masked until the writer asks to see what they typed.
    var isPasswordVisible = false

    var agreesToTerms: Bool
    var agreesToPrivacy: Bool
    var agreesToMarketing: Bool

    /// Set by `submit()`, cleared the moment the address is edited again.
    var isEmailTaken = false

    init(email: String = "",
         password: String = "",
         confirmation: String = "",
         agreesToTerms: Bool = false,
         agreesToPrivacy: Bool = false,
         agreesToMarketing: Bool = false,
         isEmailTaken: Bool = false) {
        self.email = email
        self.password = password
        self.confirmation = confirmation
        self.agreesToTerms = agreesToTerms
        self.agreesToPrivacy = agreesToPrivacy
        self.agreesToMarketing = agreesToMarketing
        self.isEmailTaken = isEmailTaken
    }

    // MARK: Validity

    var isEmailValid: Bool {
        let value = email.trimmingCharacters(in: .whitespaces)
        guard !value.contains(" "),
              let at = value.firstIndex(of: "@"), at != value.startIndex else { return false }
        let domain = value[value.index(after: at)...]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    func isMet(_ requirement: Requirement) -> Bool { requirement.isMet(in: password) }

    var isPasswordValid: Bool { Requirement.allCases.allSatisfy(isMet) }

    var isConfirmationFilled: Bool { !confirmation.isEmpty }

    var confirmationMatches: Bool { isConfirmationFilled && confirmation == password }

    /// Only the two agreements that cannot be declined. Marketing is optional and
    /// deliberately absent: consent that gates a signup is not consent.
    var agreesToAllRequired: Bool { agreesToTerms && agreesToPrivacy }

    var agreesToEverything: Bool { agreesToAllRequired && agreesToMarketing }

    /// The single gate for "다음", and the only place the answer is computed.
    ///
    /// All four have to hold: a well-formed address, a password that meets every
    /// stated requirement, a confirmation that matches it, and both *required*
    /// agreements. The view asks this one property and nothing else — it never
    /// re-derives a piece of it for the button.
    var canContinue: Bool {
        isEmailValid && isPasswordValid && confirmationMatches && agreesToAllRequired
    }

    // MARK: Actions

    /// The master checkbox sets or clears every item, optional one included.
    func setAgreesToEverything(_ isOn: Bool) {
        agreesToTerms = isOn
        agreesToPrivacy = isOn
        agreesToMarketing = isOn
    }

    func agreement(for document: SignUpDocument) -> Bool {
        switch document {
        case .terms: agreesToTerms
        case .privacy: agreesToPrivacy
        case .marketing: agreesToMarketing
        }
    }

    func setAgreement(_ isOn: Bool, for document: SignUpDocument) {
        switch document {
        case .terms: agreesToTerms = isOn
        case .privacy: agreesToPrivacy = isOn
        case .marketing: agreesToMarketing = isOn
        }
    }

    /// Checks the address against the accounts that already exist. Returns
    /// whether the flow may move on to the profile step.
    func submit() -> Bool {
        let value = email.trimmingCharacters(in: .whitespaces).lowercased()
        isEmailTaken = value == Self.registeredEmail.lowercased()
        return !isEmailTaken
    }

    /// Clears a "taken" verdict that no longer belongs to what is in the field.
    ///
    /// Guarded: assigning to an `@Observable` property publishes a change even
    /// when the new value equals the old one, so an unguarded write from the
    /// field's `onChange` invalidated the whole screen on every keystroke.
    func emailDidChange() {
        if isEmailTaken { isEmailTaken = false }
    }
}

/// The three agreements, and the documents behind them.
enum SignUpDocument: String, Identifiable, CaseIterable, Sendable {
    case terms, privacy, marketing

    var id: String { rawValue }

    var isRequired: Bool { self != .marketing }

    /// The checklist line, which states up front whether it can be declined.
    var title: LocalizedStringKey {
        switch self {
        case .terms: "(필수) 서비스 이용약관"
        case .privacy: "(필수) 개인정보 처리방침"
        case .marketing: "(선택) 마케팅 정보 수신"
        }
    }

    /// The heading of the document itself, without the requirement prefix.
    var documentTitle: LocalizedStringKey {
        switch self {
        case .terms: "서비스 이용약관"
        case .privacy: "개인정보 처리방침"
        case .marketing: "마케팅 정보 수신"
        }
    }
}

// MARK: - Screen

struct SignUpView: View {
    @Environment(SessionModel.self) private var session

    @State private var model: SignUpModel
    @FocusState private var focus: SignUpField?
    @State private var reading: SignUpDocument?

    private enum SignUpField: Hashable {
        case email, password, confirmation
    }

    init(model: SignUpModel = SignUpModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        List {
            Section {
                fields
            }

            // The master row is its own group: in a grouped list that is what
            // says it governs the group beneath it rather than belonging to it.
            Section {
                SignUpAgreementRow(title: "전체동의",
                                   isEmphasised: true,
                                   isOn: model.agreesToEverything,
                                   toggle: { model.setAgreesToEverything(!model.agreesToEverything) })
            } header: {
                Text("약관 동의")
            }

            Section {
                ForEach(SignUpDocument.allCases) { document in
                    SignUpAgreementRow(
                        title: document.title,
                        isOn: model.agreement(for: document),
                        toggle: { model.setAgreement(!model.agreement(for: document), for: document) },
                        onView: { reading = document }
                    )
                }
            }
        }
        // A `List` brings its own grouped background, the one surface in the app
        // that would not be ours. Hiding it and painting `surface` underneath
        // keeps this step on the same ground as the other three — the row insets,
        // heights and separators still come from the list.
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .listRowBackground(Palette.surface)
        .scrollDismissesKeyboard(.interactively)
        // The title is drawn here and nowhere else, at a display mode this screen
        // states rather than inherits. Nothing inside the content column repeats it.
        .navigationTitle("회원가입")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    session.stage = .signedOut
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel("뒤로")
            }
        }
        .safeAreaInset(edge: .bottom) {
            AuthStepFooter {
                Button("다음") {
                    focus = nil
                    if model.submit() {
                        session.stage = .profileSetup
                    }
                }
                .buttonStyle(SignUpPrimaryButtonStyle())
                .disabled(!model.canContinue)
            }
        }
        .sheet(item: $reading) { document in
            SignUpDocumentSheet(document: document)
        }
    }

    // MARK: - Fields

    /// The three fields as a single row that opts out of the list's chrome. They
    /// are the flow's own field boxes, not list rows, so they take
    /// `Metric.screenMargin` and line up with the pinned button; only the
    /// checklist below inherits the list's own metrics.
    private var fields: some View {
        VStack(alignment: .leading, spacing: Space.s32) {
            emailField
            passwordField
            confirmationField
        }
        .listRowInsets(EdgeInsets(top: Space.s16,
                                  leading: Metric.screenMargin,
                                  bottom: Space.s16,
                                  trailing: Metric.screenMargin))
        .listRowSeparator(.hidden)
    }

    // MARK: - Email

    private var emailField: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s12) {
            AuthFieldLabel(title: "이메일")

            AuthFieldBox {
                TextField("이메일", text: $model.email, prompt: Text("이메일 주소"))
                    .textFieldStyle(.plain)
                    .typography(.body)
                    .foregroundStyle(Palette.ink)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
                    .padding(.vertical, Space.s12)
            }
            .onChange(of: model.email) { _, _ in
                // The verdict belongs to the address that produced it.
                model.emailDidChange()
            }

            if model.isEmailTaken {
                InlineBanner(kind: .error, message: "이미 가입된 이메일입니다")
            }
        }
        // Scoped to the block that actually changes. This used to sit on the
        // outermost view, which put the navigation bar inside the animation.
        .motion(value: model.isEmailTaken)
    }

    // MARK: - Password

    private var passwordField: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s12) {
            AuthFieldLabel(title: "비밀번호")

            AuthFieldBox {
                HStack(spacing: Space.s12) {
                    Group {
                        if model.isPasswordVisible {
                            TextField("비밀번호", text: $model.password, prompt: Text("비밀번호"))
                        } else {
                            SecureField("비밀번호", text: $model.password, prompt: Text("비밀번호"))
                        }
                    }
                    .textFieldStyle(.plain)
                    .typography(.body)
                    .foregroundStyle(Palette.ink)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .password)
                    .onSubmit { focus = .confirmation }
                    .padding(.vertical, Space.s12)

                    Button {
                        model.isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: model.isPasswordVisible ? "eye.slash" : "eye")
                            .typography(.rowTitle)
                            .frame(width: Metric.tapTarget, height: Metric.tapTarget)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.inkTertiary)
                    .accessibilityLabel(Text(model.isPasswordVisible ? "비밀번호 숨기기" : "비밀번호 보기"))
                }
            }

            VStack(alignment: .leading, spacing: Space.s8) {
                ForEach(SignUpModel.Requirement.allCases) { requirement in
                    AuthSignalMark(kind: model.isMet(requirement) ? .success : .pending,
                                   message: requirement.title)
                }
            }
            .motion(value: model.password)
        }
    }

    // MARK: - Confirmation

    private var confirmationField: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s12) {
            AuthFieldLabel(title: "비밀번호 확인")

            AuthFieldBox {
                SecureField("비밀번호 확인", text: $model.confirmation, prompt: Text("비밀번호 다시 입력"))
                    .textFieldStyle(.plain)
                    .typography(.body)
                    .foregroundStyle(Palette.ink)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focus, equals: .confirmation)
                    .onSubmit { focus = nil }
                    .padding(.vertical, Space.s12)
            }

            if model.isConfirmationFilled, !model.confirmationMatches {
                AuthSignalMark(kind: .error, message: "비밀번호가 일치하지 않아요")
            }
        }
        .motion(value: model.confirmation)
    }
}

// MARK: - Agreement row

/// One line of the consent checklist: a checkbox that is the whole line, and an
/// optional text action that opens the document it refers to.
///
/// It carries no height and no insets of its own — it is always a row of the
/// grouped list on this screen, and the list already guarantees both, including
/// the minimum tap target.
private struct SignUpAgreementRow: View {
    let title: LocalizedStringKey
    var isEmphasised: Bool = false
    let isOn: Bool
    let toggle: () -> Void
    var onView: (() -> Void)?

    var body: some View {
        HStack(spacing: Space.s12) {
            Button(action: toggle) {
                HStack(spacing: Space.s12) {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .typography(.rowTitle)
                        .foregroundStyle(isOn ? Palette.ink : Palette.inkTertiary)

                    Text(title)
                        .typography(isEmphasised ? .rowTitle : .body)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])

            if let onView {
                Button("보기", action: onView)
                    .buttonStyle(.syncQuiet)
            }
        }
        .motion(value: isOn)
    }
}

// MARK: - Primary action

/// The step's primary action.
///
/// `SyncFilledButtonStyle` — what `.syncSolid` builds — has no `isEnabled` branch,
/// so a `.disabled` primary button is still drawn as a fully active one. That is
/// what made "다음" look ready before a single field had been filled in. This is
/// the same geometry with an inactive state that reads as inactive, and it lives
/// on this screen because `ButtonStyles.swift` is not a file this change may edit.
private struct SignUpPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SignUpPrimaryButtonLabel(configuration: configuration)
    }
}

/// A `ButtonStyle` is not a `View`, so `@Environment` declared on one is never
/// updated. `isEnabled` has to be read from a real view inside `makeBody`.
private struct SignUpPrimaryButtonLabel: View {
    @Environment(\.isEnabled) private var isEnabled

    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .typography(.bodyStrong)
            .foregroundStyle(isEnabled ? Palette.surface : Palette.inkTertiary)
            .frame(maxWidth: .infinity)
            // `minHeight`, not `height`: the label is text, and at accessibility
            // sizes it has to be allowed to grow rather than be clipped.
            .frame(minHeight: Metric.controlM)
            .background(fill, in: .rect(cornerRadius: Radius.pill(Metric.controlM)))
            .contentShape(.rect(cornerRadius: Radius.pill(Metric.controlM)))
            .motion(Motion.quick, value: configuration.isPressed)
            .motion(Motion.quick, value: isEnabled)
    }

    private var fill: Color {
        guard isEnabled else { return Palette.surfaceRaised }
        return configuration.isPressed ? Palette.inkSecondary : Palette.ink
    }
}

// MARK: - Document sheet

/// What "보기" opens. The documents are not written yet, so the sheet says so
/// plainly rather than showing invented legal text.
private struct SignUpDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let document: SignUpDocument

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                EmptyStateView(
                    title: "아직 준비 중이에요",
                    message: "전문은 다음 업데이트에서 열려요. 동의 여부는 지금 선택할 수 있어요."
                )
                .padding(.horizontal, Metric.screenMargin)
            }
            .background(Palette.surface)
            .scrollIndicators(.hidden)
            .navigationTitle(document.documentTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Previews

private func previewSignUp(_ model: SignUpModel = SignUpModel()) -> some View {
    NavigationStack {
        SignUpView(model: model)
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

private func filledSignUp(email: String = "chan@syncroom.app",
                          agreesToTerms: Bool = true,
                          agreesToPrivacy: Bool = true,
                          agreesToMarketing: Bool = false,
                          isEmailTaken: Bool = false) -> SignUpModel {
    SignUpModel(email: email,
                password: "syncroom24",
                confirmation: "syncroom24",
                agreesToTerms: agreesToTerms,
                agreesToPrivacy: agreesToPrivacy,
                agreesToMarketing: agreesToMarketing,
                isEmailTaken: isEmailTaken)
}

#Preview("기본 — 라이트") {
    previewSignUp().preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewSignUp().preferredColorScheme(.dark)
}

#Preview("작성 중 — 다음 비활성") {
    previewSignUp(SignUpModel(email: "chan@", password: "sync", confirmation: "syncr"))
}

/// Everything typed and correct, but one required agreement still open: the gate
/// has to stay shut.
#Preview("필수 약관 미동의 — 다음 비활성") {
    previewSignUp(filledSignUp(agreesToPrivacy: false, agreesToMarketing: true))
}

#Preview("작성 완료 — 다음 활성 — 라이트") {
    previewSignUp(filledSignUp()).preferredColorScheme(.light)
}

#Preview("작성 완료 — 다음 활성 — 다크") {
    previewSignUp(filledSignUp()).preferredColorScheme(.dark)
}

#Preview("이미 가입된 이메일") {
    previewSignUp(filledSignUp(email: SignUpModel.registeredEmail, isEmailTaken: true))
}

#Preview("Dynamic Type — accessibility3") {
    previewSignUp(filledSignUp()).environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("약관 보기") {
    SignUpDocumentSheet(document: .terms)
}

#Preview("동의 항목") {
    @Previewable @State var isOn = false

    List {
        Section {
            SignUpAgreementRow(title: "전체동의",
                               isEmphasised: true,
                               isOn: isOn,
                               toggle: { isOn.toggle() })
        } header: {
            Text("약관 동의")
        }

        Section {
            SignUpAgreementRow(title: SignUpDocument.terms.title,
                               isOn: isOn,
                               toggle: { isOn.toggle() },
                               onView: {})
            SignUpAgreementRow(title: SignUpDocument.privacy.title,
                               isOn: isOn,
                               toggle: { isOn.toggle() },
                               onView: {})
            SignUpAgreementRow(title: SignUpDocument.marketing.title,
                               isOn: false,
                               toggle: {},
                               onView: {})
        }
    }
    .scrollContentBackground(.hidden)
    .background(Palette.surface)
    .listRowBackground(Palette.surface)
}

#Preview("다음 — 활성 · 비활성", traits: .sizeThatFitsLayout) {
    VStack(spacing: Space.s16) {
        Button("다음") {}
            .buttonStyle(SignUpPrimaryButtonStyle())

        Button("다음") {}
            .buttonStyle(SignUpPrimaryButtonStyle())
            .disabled(true)
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
