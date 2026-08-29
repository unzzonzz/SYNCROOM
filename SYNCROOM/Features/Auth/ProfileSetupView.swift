//  ProfileSetupView.swift  (S7)
//
//  Liquid Glass: none is drawn here. The navigation bar the flow's
//  `NavigationStack` supplies is the only glass on screen, and the system draws
//  the capsule around the back button in it. The photo picker, the fields and the
//  pinned "다음" all live in the content column, which stays opaque.

import PhotosUI
import SwiftUI
import UIKit

// MARK: - Model

@MainActor
@Observable
final class ProfileSetupModel {

    /// Where the handle's duplicate check stands.
    enum HandleState: Sendable {
        case idle, checking, available, taken
    }

    /// This screen is the second of the three onboarding steps.
    static let step = 2
    static let stepCount = 3
    /// A one-line introduction, so the field is capped at one line's worth.
    static let bioLimit = 40
    static let hashtagLimit = 5

    var name: String
    var handle: String
    var bio: String
    var hashtags: Set<String>
    /// The picked image, as data. Nothing is uploaded — there is no backend —
    /// and nothing is written to disk.
    var avatar: Data?

    private(set) var handleState: HandleState

    /// How long the check waits before answering. A preview injects a long delay
    /// to hold the screen in its "확인중" state.
    private let checkDelay: Duration

    init(name: String = "",
         handle: String = "",
         bio: String = "",
         hashtags: Set<String> = [],
         handleState: HandleState = .idle,
         checkDelay: Duration = .milliseconds(500)) {
        self.name = name
        self.handle = handle
        self.bio = bio
        self.hashtags = hashtags
        self.handleState = handleState
        self.checkDelay = checkDelay
    }

    /// The handles already spoken for, read from the fixture graph — this build
    /// has no server to ask.
    private var takenHandles: Set<String> {
        Set(Fixtures.allArtists.map { $0.handle.lowercased() })
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var trimmedHandle: String { handle.trimmingCharacters(in: .whitespaces) }

    var canContinue: Bool { !trimmedName.isEmpty && handleState == .available }

    /// The debounced duplicate check. Driven by `.task(id:)`, so a new keystroke
    /// cancels the check in flight instead of racing it to the answer.
    func checkHandle() async {
        let value = trimmedHandle.lowercased()
        guard !value.isEmpty else {
            handleState = .idle
            return
        }
        handleState = .checking
        do {
            try await Task.sleep(for: checkDelay)
        } catch {
            return
        }
        handleState = takenHandles.contains(value) ? .taken : .available
    }

    func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item else {
            avatar = nil
            return
        }
        avatar = try? await item.loadTransferable(type: Data.self)
    }
}

// MARK: - Screen

struct ProfileSetupView: View {
    @Environment(SessionModel.self) private var session

    @State private var model: ProfileSetupModel
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isPickingPhoto = false
    @FocusState private var focus: ProfileSetupField?

    private enum ProfileSetupField: Hashable {
        case name, handle, bio
    }

    init(model: ProfileSetupModel = ProfileSetupModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s32) {
                progress
                avatarPicker
                nameField
                handleField
                bioField
                hashtagField
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Space.s16)
            .padding(.bottom, Space.s48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("프로필 설정")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    session.stage = .signUp
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
                    session.stage = .followSuggestions
                }
                .buttonStyle(.syncSolid)
                .disabled(!model.canContinue)
            }
        }
    }

    // MARK: - Progress

    /// Step 2 of 3, said in words and measured by one bar. The words carry the
    /// meaning; the bar is the same capsule the audio meter uses, so nothing
    /// decorative is introduced to say a number that type already says.
    private var progress: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text("\(ProfileSetupModel.stepCount)단계 중 \(ProfileSetupModel.step)단계")
                .typography(.metaStrong)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Capsule()
                .fill(Palette.surfaceRaised)
                .frame(height: Space.s4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Palette.ink)
                        .scaleEffect(x: stepFraction, y: 1, anchor: .leading)
                }
                .clipShape(.capsule)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("진행 단계")
        .accessibilityValue(Text("\(ProfileSetupModel.stepCount)단계 중 \(ProfileSetupModel.step)단계"))
    }

    private var stepFraction: CGFloat {
        CGFloat(ProfileSetupModel.step) / CGFloat(ProfileSetupModel.stepCount)
    }

    // MARK: - Avatar

    private var avatarPicker: some View {
        // Presented as a modifier on a plain Button rather than with a custom
        // PhotosPicker label: the picker's label closure is not main-actor
        // isolated, so reading view state inside it warns under strict concurrency.
        Button {
            isPickingPhoto = true
        } label: {
            HStack(spacing: Space.s16) {
                avatarPreview

                Text(model.avatar == nil ? "사진 추가" : "사진 변경")
                    .typography(.metaStrong)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: Metric.tapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("프로필 사진")
        .photosPicker(isPresented: $isPickingPhoto,
                      selection: $pickedPhoto,
                      matching: .images,
                      photoLibrary: .shared())
        .onChange(of: pickedPhoto) { _, newValue in
            Task { await model.loadAvatar(from: newValue) }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let data = model.avatar, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: Metric.avatarXL, height: Metric.avatarXL)
                .clipShape(.circle)
                .accessibilityHidden(true)
        } else {
            AvatarView(identity: model.handle, url: nil, size: Metric.avatarXL)
        }
    }

    // MARK: - Name

    private var nameField: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s12) {
            AuthFieldLabel(title: "이름")

            AuthFieldBox {
                TextField("이름", text: $model.name, prompt: Text("사람들에게 보일 이름"))
                    .textFieldStyle(.plain)
                    .typography(.body)
                    .foregroundStyle(Palette.ink)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .focused($focus, equals: .name)
                    .onSubmit { focus = .handle }
                    .padding(.vertical, Space.s12)
            }
        }
    }

    // MARK: - Handle

    private var handleField: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s12) {
            AuthFieldLabel(title: "핸들")

            AuthFieldBox {
                HStack(spacing: Space.s4) {
                    // The prefix is fixed and is punctuation, not language.
                    Text(verbatim: "@")
                        .typography(.body)
                        .foregroundStyle(Palette.inkTertiary)
                        .accessibilityHidden(true)

                    TextField("핸들", text: $model.handle, prompt: Text("영문 아이디"))
                        .textFieldStyle(.plain)
                        .typography(.body)
                        .foregroundStyle(Palette.ink)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focus, equals: .handle)
                        .onSubmit { focus = .bio }
                }
                .padding(.vertical, Space.s12)
            }

            handleStatus
        }
        .task(id: model.handle) {
            await model.checkHandle()
        }
        .motion(value: model.handleState)
    }

    @ViewBuilder
    private var handleStatus: some View {
        switch model.handleState {
        case .idle:
            EmptyView()
        case .checking:
            AuthSignalMark(kind: .caution, message: "확인중")
        case .available:
            AuthSignalMark(kind: .success, message: "사용 가능")
        case .taken:
            AuthSignalMark(kind: .error, message: "이미 사용 중이에요")
        }
    }

    // MARK: - Bio

    private var bioField: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            AuthFieldLabel(title: "한 줄 소개")

            AuthFieldBox {
                TextField("한 줄 소개",
                          text: bioBinding,
                          prompt: Text("어떤 음악을 하는지 한 줄로 알려주세요"),
                          axis: .vertical)
                    .textFieldStyle(.plain)
                    .typography(.body)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1...3)
                    .focused($focus, equals: .bio)
                    .padding(.vertical, Space.s12)
            }

            Text(verbatim: "\(model.bio.count)/\(ProfileSetupModel.bioLimit)")
                .typography(.meta)
                .foregroundStyle(Palette.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("입력한 글자 수")
                .accessibilityValue(Text("\(ProfileSetupModel.bioLimit)자 중 \(model.bio.count)자"))
        }
    }

    /// Clamps at the limit as it is typed, rather than rejecting the field after
    /// the fact.
    private var bioBinding: Binding<String> {
        Binding(
            get: { model.bio },
            set: { model.bio = String($0.prefix(ProfileSetupModel.bioLimit)) }
        )
    }

    // MARK: - Hashtags

    private var hashtagField: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s12) {
            AuthFieldLabel(title: "해시태그",
                           detail: "최대 \(ProfileSetupModel.hashtagLimit)개")

            HashtagPicker(tags: Fixtures.selectableHashtags,
                          selection: $model.hashtags,
                          limit: ProfileSetupModel.hashtagLimit)
        }
    }
}

// MARK: - Previews

private func previewProfileSetup(_ model: ProfileSetupModel = ProfileSetupModel()) -> some View {
    NavigationStack {
        ProfileSetupView(model: model)
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewProfileSetup().preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewProfileSetup().preferredColorScheme(.dark)
}

#Preview("핸들 확인중") {
    previewProfileSetup(
        ProfileSetupModel(name: "김승찬",
                          handle: "chan",
                          handleState: .checking,
                          checkDelay: .seconds(60 * 60))
    )
}

#Preview("핸들 사용 가능") {
    previewProfileSetup(
        ProfileSetupModel(name: "김승찬",
                          handle: "chan",
                          bio: Fixtures.seungchan.bio,
                          hashtags: ["R&B", "CCM"],
                          handleState: .available)
    )
}

#Preview("핸들 중복") {
    previewProfileSetup(
        ProfileSetupModel(name: "김승찬",
                          handle: Fixtures.seungchan.handle,
                          handleState: .taken)
    )
}

#Preview("Dynamic Type — accessibility3") {
    previewProfileSetup(
        ProfileSetupModel(name: "김승찬", handle: "chan", handleState: .available)
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}
