//  EditProfileView.swift  (S17)
//
//  Liquid Glass: 취소 and 저장 sit in a real `.toolbar`, so the system draws
//  their glass capsules and nothing here paints a bar. Every other presentation
//  on this screen is the platform's own material too — a `.confirmationDialog`
//  for the avatar, `.photosPicker` for the library, and an `.alert` on the way
//  out. The form itself is content, so its fields stay opaque.

import PhotosUI
import SwiftUI
import UIKit

// MARK: - Draft

/// Which picture the profile will be saved with.
enum EditProfileAvatar: Equatable, Sendable {
    /// Whatever the loaded profile already had.
    case original
    /// A photo just chosen from the library.
    case picked(Data)
    /// Explicitly cleared back to the default placeholder.
    case placeholder
}

/// Everything on this screen that can be edited, in one comparable value — which
/// is what makes "has anything changed?" a single equality check rather than
/// five hand-written comparisons that can drift apart.
struct EditProfileDraft: Equatable, Sendable {
    var name: String = ""
    var handle: String = ""
    var bio: String = ""
    var hashtags: Set<String> = []
    var avatar: EditProfileAvatar = .original
}

/// Where the handle's duplicate check stands.
enum EditProfileHandleCheck: Equatable, Sendable {
    /// Nothing to say: the handle is unchanged, empty, or the check itself failed.
    case idle
    case checking
    case available
    case taken
}

// MARK: - Model

@MainActor
@Observable
final class EditProfileModel {

    /// A one-line bio is one line. The counter makes the cap visible rather than
    /// letting the field silently stop accepting text.
    static let bioLimit = 40
    static let hashtagLimit = 5

    private let dataSource: any DataSource
    /// Preview seams: values typed into the form before it is looked at.
    private let editedName: String?
    private let editedHandle: String?

    /// The profile as it was loaded. Also the baseline `저장` is measured against.
    var state: LoadState<Artist> = .loading
    var draft = EditProfileDraft()
    private(set) var original = EditProfileDraft()
    var handleCheck: EditProfileHandleCheck = .idle

    init(dataSource: any DataSource = MockDataSource.shared,
         editedName: String? = nil,
         editedHandle: String? = nil) {
        self.dataSource = dataSource
        self.editedName = editedName
        self.editedHandle = editedHandle
    }

    func load() async {
        state = await LoadState.load { try await self.dataSource.myProfile().artist }
        guard let artist = state.value else { return }
        original = EditProfileDraft(artist: artist, selectable: Fixtures.selectableHashtags,
                                    limit: Self.hashtagLimit)
        draft = original
        if let editedName { draft.name = editedName }
        if let editedHandle { draft.handle = editedHandle }
    }

    func reload() async {
        await load()
    }

    // MARK: Derived

    var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Handles are stored lower-cased and bare — the `@` is presentation.
    var normalizedHandle: String {
        draft.handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var hasChanges: Bool { draft != original }

    /// `저장` is live only once something actually changed, and only when what
    /// changed can be saved: a profile needs a name, needs a handle, and cannot
    /// take a handle that belongs to someone else.
    var canSave: Bool {
        guard state.value != nil else { return false }
        return hasChanges
            && !trimmedName.isEmpty
            && !normalizedHandle.isEmpty
            && handleCheck != .taken
            && handleCheck != .checking
    }

    // MARK: Handle

    /// Asks whether the typed handle is already somebody's. Driven by
    /// `.task(id:)`, so each keystroke cancels the pause the last one started
    /// and only the handle that survives it is actually looked up.
    func checkHandle() async {
        let candidate = normalizedHandle
        guard !candidate.isEmpty, candidate != original.handle else {
            handleCheck = .idle
            return
        }

        handleCheck = .checking
        do {
            try await Task.sleep(for: .milliseconds(400))
        } catch {
            return
        }

        do {
            _ = try await dataSource.profile(handle: candidate)
            handleCheck = .taken
        } catch DataSourceError.notFound {
            handleCheck = .available
        } catch {
            // The lookup itself failed. Say nothing rather than claim an answer
            // we do not have.
            handleCheck = .idle
        }
    }

    // MARK: Avatar

    func useLibraryPhoto(_ data: Data) {
        draft.avatar = .picked(data)
    }

    /// Clearing a picture that was never there is not a change, so a profile
    /// with no avatar stays clean when the default is chosen.
    func useDefaultAvatar() {
        draft.avatar = state.value?.avatarURL == nil ? .original : .placeholder
    }

    /// The URL the avatar should be drawn from, once the picked photo — which is
    /// bytes, not a URL — has been ruled out.
    var avatarURL: URL? {
        draft.avatar == .placeholder ? nil : state.value?.avatarURL
    }

    // MARK: Save

    /// The edited artist, ready to be written back.
    ///
    /// The picked photo is deliberately not carried across: it is image data,
    /// and it only becomes an `avatarURL` once something uploads it.
    func edited() -> Artist? {
        guard var artist = state.value else { return nil }
        artist.displayName = trimmedName
        artist.handle = normalizedHandle
        artist.bio = draft.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        // Kept in the picker's own order so the chips do not shuffle on save.
        artist.hashtags = Fixtures.selectableHashtags.filter { draft.hashtags.contains($0) }
        return artist
    }
}

extension EditProfileDraft {
    /// Seeds the form from a profile. Hashtags are narrowed to the ones the
    /// picker can actually show, and to the number it will accept, so the
    /// baseline is a state the form can return to.
    init(artist: Artist, selectable: [String], limit: Int) {
        self.init(name: artist.displayName,
                  handle: artist.handle,
                  bio: artist.bio,
                  hashtags: Set(selectable.filter { artist.hashtags.contains($0) }.prefix(limit)),
                  avatar: .original)
    }
}

// MARK: - Screen

/// The fields, in tab order.
private enum EditProfileField: Hashable {
    case name, handle, bio
}

struct EditProfileView: View {
    @Environment(AppRouter.self) private var router
    @Environment(SessionModel.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var model: EditProfileModel
    @State private var isChoosingAvatar = false
    @State private var isPickingPhoto = false
    @State private var isConfirmingDiscard = false
    @State private var pickedItem: PhotosPickerItem?

    @FocusState private var focus: EditProfileField?

    init(model: EditProfileModel = EditProfileModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView(.vertical) {
            switch model.state {
            case .loading:
                formContent.skeleton(true)
            case .failed(let error):
                ErrorStateView(error: error) {
                    Task { await model.reload() }
                }
                .padding(.horizontal, Metric.screenMargin)
            case .loaded:
                formContent
            }
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("프로필 수정")
        .toolbarTitleDisplayMode(.inline)
        // The screen owns leaving, so the system back button would be a second
        // exit that skips the unsaved-changes question.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { leave() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { save() }
                    .disabled(!model.canSave)
            }
        }
        .confirmationDialog("프로필 사진",
                            isPresented: $isChoosingAvatar,
                            titleVisibility: .hidden) {
            Button("사진 보관함에서 선택") { isPickingPhoto = true }
            Button("기본 이미지로 변경") { model.useDefaultAvatar() }
            Button("취소", role: .cancel) {}
        }
        .photosPicker(isPresented: $isPickingPhoto, selection: $pickedItem, matching: .images)
        .alert("저장하지 않고 나갈까요?", isPresented: $isConfirmingDiscard) {
            Button("계속 편집", role: .cancel) {}
            Button("나가기", role: .destructive) { dismiss() }
        } message: {
            Text("방금 바꾼 내용은 사라져요.")
        }
        .task { await model.load() }
        .task(id: model.draft.handle) { await model.checkHandle() }
        .task(id: pickedItem) { await adoptPickedPhoto() }
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(alignment: .leading, spacing: Space.s48) {
            avatarBlock

            VStack(alignment: .leading, spacing: Space.s32) {
                nameField
                handleField
                bioField
            }

            hashtagBlock

            accountBlock
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s16)
        .padding(.bottom, Space.s48)
    }

    // MARK: Avatar

    private var avatarBlock: some View {
        Button {
            focus = nil
            isChoosingAvatar = true
        } label: {
            VStack(spacing: Space.s12) {
                avatarImage
                Text("사진 변경")
                    .typography(.metaStrong)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: Metric.tapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("프로필 사진 변경")
    }

    @ViewBuilder
    private var avatarImage: some View {
        if case .picked(let data) = model.draft.avatar, let photo = UIImage(data: data) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: Metric.avatarXL, height: Metric.avatarXL)
                .clipShape(.circle)
                .accessibilityHidden(true)
        } else {
            AvatarView(identity: model.draft.handle, url: model.avatarURL, size: Metric.avatarXL)
        }
    }

    private func adoptPickedPhoto() async {
        guard let pickedItem else { return }
        guard let data = try? await pickedItem.loadTransferable(type: Data.self) else { return }
        model.useLibraryPhoto(data)
    }

    // MARK: Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            EditProfileFieldLabel(title: "이름")

            TextField("이름", text: $model.draft.name, prompt: Text("이름을 입력해주세요"))
                .textFieldStyle(.plain)
                .typography(.body)
                .foregroundStyle(Palette.ink)
                .textContentType(.name)
                .submitLabel(.next)
                .focused($focus, equals: .name)
                .onSubmit { focus = .handle }
                .padding(Space.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.surface))
        }
    }

    /// The `@` belongs to the field, not to the value — it is drawn beside the
    /// input and is never part of what the person types or of what is stored.
    private var handleField: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            EditProfileFieldLabel(title: "핸들")

            HStack(spacing: Space.s4) {
                Text(verbatim: "@")
                    .typography(.body)
                    .foregroundStyle(Palette.inkTertiary)
                    .accessibilityHidden(true)

                TextField("핸들", text: $model.draft.handle, prompt: Text("영문, 숫자, 밑줄"))
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
            .padding(Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.surface))

            EditProfileHandleStatus(check: model.handleCheck)
                .motion(value: model.handleCheck)
        }
    }

    private var bioField: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            EditProfileFieldLabel(title: "한 줄 소개")

            TextField("한 줄 소개",
                      text: bioBinding,
                      prompt: Text("나를 한 문장으로 소개해보세요"),
                      axis: .vertical)
                .textFieldStyle(.plain)
                .typography(.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(2...4)
                .submitLabel(.done)
                .focused($focus, equals: .bio)
                .onSubmit { focus = nil }
                .padding(Space.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.surface))

            Text(verbatim: "\(model.draft.bio.count)/\(EditProfileModel.bioLimit)")
                .typography(.meta)
                .foregroundStyle(Palette.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("입력한 글자 수")
                .accessibilityValue(
                    Text("\(EditProfileModel.bioLimit)자 중 \(model.draft.bio.count)자")
                )
        }
    }

    /// Clamps at the limit as it is typed, rather than rejecting the whole field
    /// after the fact.
    private var bioBinding: Binding<String> {
        Binding(
            get: { model.draft.bio },
            set: { model.draft.bio = String($0.prefix(EditProfileModel.bioLimit)) }
        )
    }

    // MARK: Hashtags

    private var hashtagBlock: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            EditProfileFieldLabel(title: "관심 해시태그")

            HashtagPicker(tags: Fixtures.selectableHashtags,
                          selection: $model.draft.hashtags,
                          limit: EditProfileModel.hashtagLimit)

            Text("최대 \(EditProfileModel.hashtagLimit)개까지 고를 수 있어요")
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Account

    private var accountBlock: some View {
        SettingsRow(title: "계정 설정", description: "알림, 결제, 로그아웃") {
            router.push(.settings)
        }
    }

    // MARK: - Leaving

    private func leave() {
        focus = nil
        if model.hasChanges {
            isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }

    private func save() {
        if let edited = model.edited() {
            session.currentUser = edited
        }
        dismiss()
    }
}

// MARK: - Field parts

/// A quiet label above a field. Inside a form the screen title is the only
/// heading, so field labels stay on the metadata step of the scale rather than
/// competing at `SectionHeader` weight.
private struct EditProfileFieldLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .typography(.metaStrong)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The handle's duplicate check, said in signal colour.
///
/// A signal is a fill carrying `onSignal` text, never tinted body text on the
/// surface — so the two short confirmations are filled marks, and the one state
/// the person has to act on is a full `InlineBanner`.
private struct EditProfileHandleStatus: View {
    let check: EditProfileHandleCheck

    var body: some View {
        switch check {
        case .idle:
            EmptyView()
        case .checking:
            EditProfileSignalMark(fill: Palette.signalCaution, title: "확인중")
        case .available:
            EditProfileSignalMark(fill: Palette.signalSuccess, title: "사용 가능")
        case .taken:
            InlineBanner(kind: .error, message: "이미 사용 중인 핸들이에요")
        }
    }
}

/// A small filled mark. A capsule rather than a fixed height, so it still holds
/// its label at accessibility sizes.
private struct EditProfileSignalMark: View {
    let fill: Color
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .typography(.chip)
            .foregroundStyle(Palette.onSignal)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Space.s12)
            .padding(.vertical, Space.s4)
            .background(fill, in: .capsule)
    }
}

// MARK: - Previews

private func previewEditProfile(_ behaviour: MockDataSource.Behaviour = .populated,
                                editedName: String? = nil,
                                editedHandle: String? = nil) -> some View {
    NavigationStack {
        EditProfileView(
            model: EditProfileModel(dataSource: MockDataSource(behaviour: behaviour),
                                    editedName: editedName,
                                    editedHandle: editedHandle)
        )
        .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewEditProfile().preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewEditProfile().preferredColorScheme(.dark)
}

#Preview("변경됨 — 저장 활성") {
    previewEditProfile(editedName: "김승찬 (건반)")
}

#Preview("핸들 사용 가능") {
    previewEditProfile(editedHandle: "chan_keys")
}

#Preview("핸들 중복") {
    previewEditProfile(editedHandle: "user")
}

#Preview("로딩") {
    previewEditProfile(.loading)
}

#Preview("오류") {
    previewEditProfile(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewEditProfile(editedHandle: "user")
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("핸들 확인 상태", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s16) {
        EditProfileHandleStatus(check: .checking)
        EditProfileHandleStatus(check: .available)
        EditProfileHandleStatus(check: .taken)
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
