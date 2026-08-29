//  LiveSetupView.swift  (S10)
//
//  Liquid Glass: the close control is a real `.toolbar` item, so the system
//  draws its glass capsule and this file paints no navigation bar of its own.
//  The single action that floats over the scrolling form — 다음 — is
//  `.buttonStyle(.glassProminent)` with a capsule border shape inside a
//  `.safeAreaInset(edge: .bottom)`, which is the platform's own floating-CTA
//  treatment. The form beneath it is content, so it stays opaque.

import PhotosUI
import SwiftUI

// MARK: - Model

@MainActor
@Observable
final class LiveSetupModel {

    /// The room being configured. Seeded from the signed-in host the first time
    /// the form appears, or handed in when the audio check steps back here.
    var draft: LiveRoomDraft

    /// Whether `draft` already carries a real, host-derived title.
    private var isSeeded: Bool

    /// The hashtag being typed, before it becomes a chip.
    var tagInput: String = ""

    /// The cover the host picked, kept as an image rather than a URL: the app
    /// has no upload endpoint, so `draft.thumbnailURL` stays empty until a real
    /// upload hands one back. Inventing a URL here would be fake metadata.
    var pickedItem: PhotosPickerItem?
    var cover: Image?

    init(draft: LiveRoomDraft? = nil) {
        self.draft = draft ?? LiveRoomDraft(title: "",
                                            hashtags: [],
                                            maxParticipants: 0,
                                            approval: .manual,
                                            isAcceptingParticipants: false,
                                            visibility: .everyone,
                                            acceptsDonation: true,
                                            thumbnailURL: nil)
        self.isSeeded = draft != nil
    }

    /// Names the room after whoever is opening it, exactly once.
    func seed(host: Artist) {
        guard !isSeeded else { return }
        draft = .initial(host: host)
        isSeeded = true
    }

    // MARK: Title

    var titleCount: Int { draft.title.count }

    /// A room with no name cannot go on air, and that is the only thing the
    /// form insists on.
    var canContinue: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Hashtags

    var isTagLimitReached: Bool { draft.hashtags.count >= LiveRoomDraft.maxHashtags }

    var canAddTag: Bool { pendingTag != nil && !isTagLimitReached }

    /// The typed tag, trimmed and stored bare — the `#` is presentation, and a
    /// duplicate is not a new tag.
    private var pendingTag: String? {
        var tag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        while tag.hasPrefix("#") { tag.removeFirst() }
        tag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty, !draft.hashtags.contains(tag) else { return nil }
        return tag
    }

    func addTag() {
        guard let tag = pendingTag, !isTagLimitReached else { return }
        draft.hashtags.append(tag)
        tagInput = ""
    }

    func removeTag(_ tag: String) {
        draft.hashtags.removeAll { $0 == tag }
    }

    // MARK: Cover

    func loadCover() async {
        guard let pickedItem else {
            cover = nil
            return
        }
        cover = try? await pickedItem.loadTransferable(type: Image.self)
    }
}

// MARK: - Screen

struct LiveSetupView: View {
    @Environment(SessionModel.self) private var session

    private let onNext: (LiveRoomDraft) -> Void
    private let onClose: () -> Void

    @State private var model: LiveSetupModel
    @State private var isPickingCover = false

    /// `draft` restores a form the host already filled in — the audio check
    /// steps back here rather than making them start over.
    init(draft: LiveRoomDraft? = nil,
         onNext: @escaping (LiveRoomDraft) -> Void,
         onClose: @escaping () -> Void) {
        self.init(model: LiveSetupModel(draft: draft), onNext: onNext, onClose: onClose)
    }

    /// The injection seam previews use to open the form part-way filled in.
    init(model: LiveSetupModel,
         onNext: @escaping (LiveRoomDraft) -> Void,
         onClose: @escaping () -> Void) {
        self.onNext = onNext
        self.onClose = onClose
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s48) {
                coverField
                titleField
                hashtagField
                participationSection
                visibilitySection
                donationField
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Space.s16)
            .padding(.bottom, Space.s32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Palette.surface)
        .navigationTitle("라이브 개설")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("닫기")
            }
        }
        .safeAreaInset(edge: .bottom) {
            nextBar
        }
        .task { model.seed(host: session.currentUser) }
    }

    // MARK: - Cover

    private var coverField: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            LiveSetupFieldLabel(title: "썸네일")

            // Presented as a modifier on a plain Button rather than with a custom
            // PhotosPicker label: the picker's label closure is not main-actor
            // isolated, so reading view state inside it warns under strict concurrency.
            Button {
                isPickingCover = true
            } label: {
                coverArea
            }
            .buttonStyle(.plain)
            .accessibilityLabel("썸네일 사진 선택")
            .photosPicker(isPresented: $isPickingCover,
                          selection: coverSelection,
                          matching: .images)
        }
    }

    /// Selecting loads the image straight away, so the picker's binding does the
    /// work rather than a separate change observer.
    private var coverSelection: Binding<PhotosPickerItem?> {
        Binding(
            get: { model.pickedItem },
            set: { item in
                model.pickedItem = item
                Task { await model.loadCover() }
            }
        )
    }

    /// 16:9, the same frame the stream itself is in, so what the host picks is
    /// what the card and the banner will crop to.
    private var coverArea: some View {
        RoundedRectangle(cornerRadius: Radius.media)
            .fill(Palette.surfaceStrong)
            .aspectRatio(Metric.stream, contentMode: .fit)
            .overlay {
                if let cover = model.cover {
                    cover
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: Space.s8) {
                        Image(systemName: "photo.badge.plus")
                            .typography(.sectionTitle)
                            .foregroundStyle(Palette.inkTertiary)
                        Text("사진 선택")
                            .typography(.metaStrong)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: Radius.media))
            .motion(value: model.cover == nil)
            .accessibilityHidden(true)
    }

    // MARK: - Title

    private var titleField: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s12) {
            LiveSetupFieldLabel(title: "제목")

            VStack(alignment: .trailing, spacing: Space.s8) {
                TextField("제목",
                          text: titleBinding,
                          prompt: Text("어떤 방인지 알려주세요"))
                    .textFieldStyle(.plain)
                    .typography(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .submitLabel(.done)
                    .padding(Space.s16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.surface))

                Text(verbatim: "\(model.titleCount)/\(LiveRoomDraft.maxTitleLength)")
                    .typography(.meta)
                    .foregroundStyle(Palette.inkTertiary)
                    .accessibilityLabel("입력한 글자 수")
                    .accessibilityValue(Text("\(LiveRoomDraft.maxTitleLength)자 중 \(model.titleCount)자"))
            }
        }
    }

    /// Clamps at the limit as it is typed, rather than rejecting the field after
    /// the fact.
    private var titleBinding: Binding<String> {
        Binding(
            get: { model.draft.title },
            set: { model.draft.title = String($0.prefix(LiveRoomDraft.maxTitleLength)) }
        )
    }

    // MARK: - Hashtags

    private var hashtagField: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s12) {
            LiveSetupFieldLabel(title: "해시태그")

            HStack(spacing: Space.s12) {
                TextField("해시태그",
                          text: $model.tagInput,
                          prompt: Text("해시태그 입력"))
                    .textFieldStyle(.plain)
                    .typography(.body)
                    .foregroundStyle(Palette.ink)
                    .submitLabel(.done)
                    .onSubmit { model.addTag() }
                    .padding(.horizontal, Space.s16)
                    .padding(.vertical, Space.s12)
                    .frame(maxWidth: .infinity, minHeight: Metric.controlM, alignment: .leading)
                    .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.surface))
                    .disabled(model.isTagLimitReached)

                Button("추가") { model.addTag() }
                    .buttonStyle(.syncQuiet)
                    .disabled(!model.canAddTag)
            }

            if !model.draft.hashtags.isEmpty {
                FlowLayout(spacing: Space.s8, lineSpacing: Space.s4) {
                    ForEach(model.draft.hashtags, id: \.self) { tag in
                        LiveSetupTagChip(tag: tag) {
                            model.removeTag(tag)
                        }
                    }
                }
                .motion(value: model.draft.hashtags)
            }

            Text(verbatim: "\(model.draft.hashtags.count)/\(LiveRoomDraft.maxHashtags)")
                .typography(.meta)
                .foregroundStyle(Palette.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("추가한 해시태그 수")
                .accessibilityValue(Text("\(LiveRoomDraft.maxHashtags)개 중 \(model.draft.hashtags.count)개"))
        }
    }

    // MARK: - 참여 설정

    private var participationSection: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s24) {
            SectionHeader(title: "참여 설정")

            Stepper(value: $model.draft.maxParticipants,
                    in: LiveRoomDraft.participantRange) {
                HStack(spacing: Space.s12) {
                    Text("참여 인원")
                        .typography(.rowTitle)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: Space.s12)

                    Text("\(model.draft.maxParticipants)명")
                        .typography(.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                }
            }
            .frame(minHeight: Metric.tapTarget)

            VStack(alignment: .leading, spacing: Space.s12) {
                LiveSetupFieldLabel(title: "참여 승인 방식")

                Picker(selection: $model.draft.approval) {
                    ForEach(JoinApproval.allCases) { approval in
                        Text(approval.label).tag(approval)
                    }
                } label: {
                    Text("참여 승인 방식")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Toggle(isOn: $model.draft.isAcceptingParticipants) {
                Text("참여 신청 받기")
                    .typography(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tint(Palette.ink)
            .frame(minHeight: Metric.tapTarget)
        }
    }

    // MARK: - 공개 설정

    private var visibilitySection: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s16) {
            SectionHeader(title: "공개 설정")

            HStack(spacing: Space.s12) {
                Text("공개 범위")
                    .typography(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: Space.s12)

                Picker(selection: $model.draft.visibility) {
                    ForEach(RoomVisibility.allCases) { visibility in
                        Text(visibility.label).tag(visibility)
                    }
                } label: {
                    Text("공개 범위")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Palette.ink)
            }
            .frame(minHeight: Metric.tapTarget)
        }
    }

    // MARK: - 후원

    private var donationField: some View {
        @Bindable var model = model

        return Toggle(isOn: $model.draft.acceptsDonation) {
            Text("후원 받기")
                .typography(.rowTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(Palette.ink)
        .frame(minHeight: Metric.tapTarget)
    }

    // MARK: - Next

    private var nextBar: some View {
        Button {
            onNext(model.draft)
        } label: {
            Text("다음 (오디오 설정)")
                .typography(.bodyStrong)
                .padding(.vertical, Space.s12)
                .frame(maxWidth: .infinity, minHeight: Metric.controlM)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .disabled(!model.canContinue)
        .padding(.horizontal, Metric.screenMargin)
        .padding(.bottom, Space.s16)
    }
}

// MARK: - Form parts

/// A quiet field label on the setup form. The screen's headings are its section
/// titles, so field labels sit one step down, on the metadata scale.
private struct LiveSetupFieldLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .typography(.metaStrong)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// An added hashtag. Unlike `HashtagChip` this one is a control — tapping it
/// removes the tag — so it carries a dismiss mark and grows with Dynamic Type
/// instead of clipping.
private struct LiveSetupTagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: Space.s4) {
                Text(Format.hashtag(tag))
                    .typography(.chip)
                    .foregroundStyle(Palette.inkChip)
                    .lineLimit(1)

                Image(systemName: "xmark")
                    .typography(.chip)
                    .foregroundStyle(Palette.inkTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Space.s12)
            .padding(.vertical, Space.s4)
            .frame(minHeight: Metric.chipHeight)
            .background(Palette.surfaceRaised,
                        in: .rect(cornerRadius: Radius.pill(Metric.chipHeight)))
            .contentShape(.rect(cornerRadius: Radius.pill(Metric.chipHeight)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("해시태그 삭제")
        .accessibilityValue(Text(verbatim: Format.hashtag(tag)))
    }
}

// MARK: - Previews

private func liveSetupPreviewDraft() -> LiveRoomDraft {
    var draft = LiveRoomDraft.initial(host: Fixtures.seungchan)
    draft.hashtags = Fixtures.seungchan.hashtags
    draft.maxParticipants = 4
    draft.isAcceptingParticipants = true
    draft.visibility = .followers
    return draft
}

/// The six-tag, long-title edge case, capped at the five tags the draft allows.
private func liveSetupCrowdedDraft() -> LiveRoomDraft {
    var draft = liveSetupPreviewDraft()
    draft.title = Fixtures.longformRoom.title
    draft.hashtags = Array(Fixtures.longform.hashtags.prefix(LiveRoomDraft.maxHashtags))
    return draft
}

/// A form the host has emptied out: 다음 is visible but cannot be used.
private func liveSetupUntitledDraft() -> LiveRoomDraft {
    var draft = liveSetupPreviewDraft()
    draft.title = ""
    return draft
}

private func previewLiveSetup(_ draft: LiveRoomDraft? = nil) -> some View {
    NavigationStack {
        LiveSetupView(model: LiveSetupModel(draft: draft), onNext: { _ in }, onClose: {})
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewLiveSetup().preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewLiveSetup().preferredColorScheme(.dark)
}

#Preview("작성 중") {
    previewLiveSetup(liveSetupPreviewDraft())
}

#Preview("해시태그 가득") {
    previewLiveSetup(liveSetupCrowdedDraft())
}

#Preview("제목 없음") {
    previewLiveSetup(liveSetupUntitledDraft())
}

#Preview("Dynamic Type — accessibility3") {
    previewLiveSetup(liveSetupPreviewDraft())
        .environment(\.dynamicTypeSize, .accessibility3)
}
