//  JoinRequestSheet.swift  (S21)
//
//  Liquid Glass: a sheet *is* the platform's glass, so this file paints no
//  background of its own and never restyles the presentation — it only declares
//  `.presentationDetents([.medium, .large])` so the detents travel with the view
//  rather than living at whichever screen happens to present it. Everything
//  inside the content column stays opaque, because content is not glass.

import SwiftUI

// MARK: - Model

@MainActor
@Observable
final class JoinRequestModel {

    /// A request is a note, not a message, so the field is capped.
    static let noteLimit = 40

    private let dataSource: any DataSource

    /// The input devices the request could go out with. The first one is the
    /// default, and `selectedDeviceID` overrides it once the applicant chooses.
    var devices: LoadState<[AudioDevice]> = .loading
    var selectedDeviceID: UUID?

    var role: PerformerRole?
    var note: String = ""

    var isSending = false
    /// `nil` while the applicant is still filling the form in.
    var outcome: JoinRequestOutcome?
    /// Only meaningful once the request has been accepted.
    var isMuted = false

    /// Drives the input meter. Started in `.task`, stopped on disappear.
    let levels = AudioLevelSource()

    /// The pending send, and the host's eventual reply. Held so `cancel()` can
    /// withdraw a request that has not been answered yet.
    private var reply: Task<Void, Never>?

    init(dataSource: any DataSource = MockDataSource.shared,
         role: PerformerRole? = nil,
         note: String = "",
         outcome: JoinRequestOutcome? = nil) {
        self.dataSource = dataSource
        self.role = role
        self.note = note
        self.outcome = outcome
    }

    /// The device the request will go out with: the chosen one, else the first.
    var device: AudioDevice? {
        guard let devices = devices.value else { return nil }
        return devices.first { $0.id == selectedDeviceID } ?? devices.first
    }

    var canSend: Bool { role != nil && !isSending }

    func load() async {
        devices = await LoadState.load { try await self.dataSource.audioDevices() }
    }

    func startMetering() {
        levels.mode = isMuted ? .silent : .signal
        levels.start()
    }

    func stopMetering() {
        reply?.cancel()
        reply = nil
        levels.stop()
    }

    func send() {
        guard canSend else { return }
        isSending = true
        reply = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            isSending = false
            outcome = .pending
            // The host answers in their own time; this delay stands in for that
            // reply arriving, so the whole applicant journey is reachable.
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            outcome = .accepted
        }
    }

    /// Withdraws a request that has not been answered, back to the form.
    func cancel() {
        reply?.cancel()
        reply = nil
        isSending = false
        outcome = nil
    }

    /// Muting stops the outgoing signal, so the meter goes flat with it.
    func setMuted(_ muted: Bool) {
        isMuted = muted
        levels.mode = muted ? .silent : .signal
    }
}

// MARK: - Screen

struct JoinRequestSheet: View {
    @Environment(\.dismiss) private var dismiss

    let room: LiveRoom

    @State private var model: JoinRequestModel
    @State private var isChoosingDevice = false

    init(room: LiveRoom, model: JoinRequestModel = JoinRequestModel()) {
        self.room = room
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s32) {
                header

                if let outcome = model.outcome {
                    switch outcome {
                    case .pending: pendingContent
                    case .accepted: acceptedContent
                    case .declined: declinedContent
                    }
                } else {
                    formContent
                }
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Space.s24)
            .padding(.bottom, Space.s48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .motion(value: model.outcome)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            model.startMetering()
            await model.load()
        }
        .onDisappear { model.stopMetering() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s12) {
            Text(room.title)
                .typography(.roomTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            slotCount
        }
    }

    /// `1/4` — the figure taken so far carries the ink, the capacity stays quiet.
    /// Two adjacent `Text` views rather than a concatenation, which is deprecated.
    private var slotCount: some View {
        HStack(spacing: 0) {
            Text(verbatim: "\(room.participantCount)")
                .typography(.metaStrong)
                .foregroundStyle(Palette.ink)
            Text(verbatim: "/\(room.maxParticipants)")
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("참여 인원")
        .accessibilityValue(Text("\(room.maxParticipants)명 중 \(room.participantCount)명"))
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(alignment: .leading, spacing: Space.s32) {
            VStack(alignment: .leading, spacing: Space.s12) {
                LiveSheetLabel(title: "어떤 역할로 참여하나요?")
                RolePicker(selection: $model.role)
            }

            VStack(alignment: .leading, spacing: Space.s12) {
                LiveSheetLabel(title: "호스트에게 한마디")
                noteField
            }

            audioSummary

            Button {
                model.send()
            } label: {
                Text(model.isSending ? "보내는 중" : "신청 보내기")
            }
            .buttonStyle(.syncSolid)
            .disabled(!model.canSend)
        }
    }

    private var noteField: some View {
        VStack(alignment: .trailing, spacing: Space.s8) {
            TextField("호스트에게 한마디",
                      text: noteBinding,
                      prompt: Text("어떤 곡을 함께 하고 싶은지 적어보세요"),
                      axis: .vertical)
                .textFieldStyle(.plain)
                .typography(.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(2...4)
                .padding(Space.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.surface))

            Text(verbatim: "\(model.note.count)/\(JoinRequestModel.noteLimit)")
                .typography(.meta)
                .foregroundStyle(Palette.inkTertiary)
                .accessibilityLabel("입력한 글자 수")
                .accessibilityValue(Text("\(JoinRequestModel.noteLimit)자 중 \(model.note.count)자"))
        }
    }

    /// Clamps at the limit as it is typed, rather than rejecting the whole field
    /// after the fact.
    private var noteBinding: Binding<String> {
        Binding(
            get: { model.note },
            set: { model.note = String($0.prefix(JoinRequestModel.noteLimit)) }
        )
    }

    // MARK: - Audio

    private var audioSummary: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            LiveSheetLabel(title: "입력 장치",
                           actionTitle: model.devices.value?.isEmpty == false ? "설정 변경" : nil) {
                isChoosingDevice = true
            }

            switch model.devices {
            case .loading:
                Text("불러오는 중")
                    .typography(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .skeleton(true)
            case .failed:
                InlineBanner(kind: .caution,
                             message: "입력 장치를 불러오지 못했어요",
                             actionTitle: "다시 시도") {
                    Task { await model.load() }
                }
            case .loaded:
                if let device = model.device {
                    Text(device.name)
                        .typography(.rowTitle)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("사용할 수 있는 입력 장치가 없어요")
                        .typography(.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            AudioLevelMeter(level: model.levels.level)
        }
        .confirmationDialog("입력 장치", isPresented: $isChoosingDevice, titleVisibility: .visible) {
            // Device names are hardware, not copy, so they are not localized.
            ForEach(model.devices.value ?? []) { device in
                Button(device.name) { model.selectedDeviceID = device.id }
            }
            Button("취소", role: .cancel) {}
        }
    }

    // MARK: - Outcomes

    private var pendingContent: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            Text("호스트의 승인을 기다리는 중...")
                .typography(.sectionTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("수락되면 바로 함께 연주할 수 있어요.")
                .typography(.body)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let role = model.role {
                RoleChip(role: role)
                    .padding(.top, Space.s4)
            }

            Button("취소") { model.cancel() }
                .buttonStyle(.syncFilled)
                .padding(.top, Space.s12)
        }
    }

    private var acceptedContent: some View {
        VStack(alignment: .leading, spacing: Space.s24) {
            InlineBanner(kind: .success, message: "참여가 수락되었어요")

            VStack(alignment: .leading, spacing: Space.s12) {
                LiveSheetLabel(title: "입력 장치")
                if let device = model.device {
                    Text(device.name)
                        .typography(.rowTitle)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                AudioLevelMeter(level: model.levels.level)
            }

            Toggle(isOn: mutedBinding) {
                Text("마이크 음소거")
                    .typography(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tint(Palette.ink)
            .frame(minHeight: Metric.tapTarget)

            Button("나가기") { dismiss() }
                .buttonStyle(.syncFilled)
        }
    }

    private var mutedBinding: Binding<Bool> {
        Binding(get: { model.isMuted }, set: { model.setMuted($0) })
    }

    private var declinedContent: some View {
        EmptyStateView(title: "이번엔 참여가 어려웠어요",
                       message: "다음 라이브에서 다시 신청해보세요.",
                       actionTitle: "닫기") {
            dismiss()
        }
    }
}

// MARK: - Shared sheet label

/// A quiet field label with one optional trailing action, shared by the three
/// live-room sheets. It lives here rather than in the design system because it
/// is a sheet-form idiom: inside a sheet the only heading is the sheet's own
/// title, so field labels stay on the metadata step of the scale instead of
/// competing at `SectionHeader` weight.
struct LiveSheetLabel: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s12) {
            Text(title)
                .typography(.metaStrong)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Space.s12)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.syncQuiet)
            }
        }
    }
}

// MARK: - Previews

private func previewJoinRequest(_ behaviour: MockDataSource.Behaviour = .populated,
                                role: PerformerRole? = .keys,
                                note: String = "",
                                outcome: JoinRequestOutcome? = nil) -> some View {
    JoinRequestSheet(
        room: Fixtures.chansRoom,
        model: JoinRequestModel(dataSource: MockDataSource(behaviour: behaviour),
                                role: role,
                                note: note,
                                outcome: outcome)
    )
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewJoinRequest(role: nil).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewJoinRequest(role: nil).preferredColorScheme(.dark)
}

#Preview("작성 중") {
    previewJoinRequest(note: "한 곡만 같이 연주하고 싶어요!")
}

#Preview("승인 대기") {
    previewJoinRequest(outcome: .pending)
}

#Preview("참여 수락") {
    previewJoinRequest(outcome: .accepted)
}

#Preview("참여 거절") {
    previewJoinRequest(outcome: .declined)
}

#Preview("장치 없음") {
    previewJoinRequest(.empty)
}

#Preview("장치 오류") {
    previewJoinRequest(.failing)
}

#Preview("로딩") {
    previewJoinRequest(.loading)
}

#Preview("Dynamic Type — accessibility3") {
    previewJoinRequest().environment(\.dynamicTypeSize, .accessibility3)
}
