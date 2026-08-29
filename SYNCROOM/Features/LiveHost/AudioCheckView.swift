//  AudioCheckView.swift  (S11)
//
//  Liquid Glass: the back control is a real `.toolbar` item, so the system draws
//  its glass capsule and nothing here paints a bar. The one action that floats
//  over the scrolling checks — 라이브 시작 — is `.buttonStyle(.glassProminent)`
//  with a capsule border shape inside a `.safeAreaInset(edge: .bottom)`, the
//  platform's own floating-CTA treatment. Everything the host reads while
//  listening — meter, latency, banners — is content, and content stays opaque.

import AVFoundation
import SwiftUI
import UIKit

// MARK: - Model

@MainActor
@Observable
final class AudioCheckModel {
    private let dataSource: any DataSource

    var devices: LoadState<[AudioDevice]> = .loading
    var selectedDevice: AudioDevice?

    private(set) var permission: MicrophonePermission

    /// Previews and tests pin the permission. The app leaves this `nil`, and the
    /// real value is read from `AVAudioApplication` instead.
    private let pinnedPermission: MicrophonePermission?

    var isMonitoring = true
    /// Monitor level, 0…1.
    var volume: Double = 0.7

    /// Drives the meter. Started in `.task`, stopped on disappear.
    let levels = AudioLevelSource()

    /// What the input does while this screen is up. `.silent` is the state the
    /// "no signal" warning exists for, and how a preview reaches it.
    private let input: AudioLevelSource.Mode

    init(dataSource: any DataSource = MockDataSource.shared,
         permission: MicrophonePermission? = nil,
         input: AudioLevelSource.Mode = .signal,
         latencyMilliseconds: Int? = nil) {
        self.dataSource = dataSource
        self.pinnedPermission = permission
        self.permission = permission ?? .undetermined
        self.input = input
        if let latencyMilliseconds {
            levels.latencyMilliseconds = latencyMilliseconds
        }
    }

    // MARK: Derived

    var latencyMilliseconds: Int { levels.latencyMilliseconds }
    var grade: LatencyGrade { levels.latencyGrade }

    /// Read off the same latency the grade comes from, so this line can never
    /// disagree with the figure above it.
    var networkStatus: LocalizedStringKey {
        switch grade {
        case .good: "네트워크 연결이 안정적이에요"
        case .fair: "네트워크가 조금 흔들리고 있어요"
        case .unstable: "네트워크가 불안정해요"
        }
    }

    /// The silence warning. With the microphone switched off there is a better
    /// explanation on screen already, so this one stands down for it.
    var showsSilenceWarning: Bool {
        permission != .denied && levels.isSilent
    }

    /// Without a microphone there is no performance to send, so the broadcast
    /// cannot start — but the host still needs to see the action is there.
    var canStart: Bool { permission != .denied }

    // MARK: Behaviour

    func prepare(preferred: AudioDevice?) async {
        if selectedDevice == nil { selectedDevice = preferred }
        await resolvePermission()
        levels.start()
        await loadDevices()
    }

    func loadDevices() async {
        devices = await LoadState.load { try await self.dataSource.audioDevices() }
        if let devices = devices.value {
            selectedDevice = devices.first { $0.id == selectedDevice?.id } ?? devices.first
        }
    }

    func stop() {
        levels.stop()
    }

    /// Asks for the microphone the first time, and does nothing further once the
    /// answer is on record — a denied permission can only be changed in Settings.
    func resolvePermission() async {
        if let pinnedPermission {
            permission = pinnedPermission
            applyInput()
            return
        }
        permission = Self.systemPermission
        if permission == .undetermined {
            let granted = await AVAudioApplication.requestRecordPermission()
            permission = granted ? .granted : .denied
        }
        applyInput()
    }

    /// Re-reads the system value when the app comes back to the front, which is
    /// how a trip to Settings gets reflected here.
    func refreshPermission() {
        guard pinnedPermission == nil else { return }
        permission = Self.systemPermission
        applyInput()
    }

    /// No permission means no signal, so the meter tells the same story the
    /// banner does.
    private func applyInput() {
        levels.mode = permission == .denied ? .silent : input
    }

    private static var systemPermission: MicrophonePermission {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        case .undetermined: .undetermined
        @unknown default: .undetermined
        }
    }
}

// MARK: - Screen

struct AudioCheckView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    private let draft: LiveRoomDraft
    private let onStart: () -> Void
    private let onBack: () -> Void

    @State private var model: AudioCheckModel

    init(draft: LiveRoomDraft,
         onStart: @escaping () -> Void,
         onBack: @escaping () -> Void) {
        self.init(draft: draft, model: AudioCheckModel(), onStart: onStart, onBack: onBack)
    }

    /// The injection seam previews use to pin a permission, a data-source
    /// behaviour or a silent input.
    init(draft: LiveRoomDraft,
         model: AudioCheckModel,
         onStart: @escaping () -> Void,
         onBack: @escaping () -> Void) {
        self.draft = draft
        self.onStart = onStart
        self.onBack = onBack
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s48) {
                roomHeader
                permissionBanner
                deviceSection
                meterSection
                monitorSection
                latencySection
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Space.s16)
            .padding(.bottom, Space.s32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Palette.surface)
        .navigationTitle("오디오 · 입력 점검")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("뒤로")
            }
        }
        .safeAreaInset(edge: .bottom) {
            startBar
        }
        .task { await model.prepare(preferred: settings.preferredInputDevice) }
        .onChange(of: scenePhase) {
            if scenePhase == .active { model.refreshPermission() }
        }
        .onDisappear { model.stop() }
    }

    // MARK: - What is about to go on air

    private var roomHeader: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text(draft.title)
                .typography(.roomTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if !draft.hashtags.isEmpty {
                HashtagChipRow(tags: draft.hashtags)
            }
        }
    }

    // MARK: - Microphone permission

    @ViewBuilder
    private var permissionBanner: some View {
        switch model.permission {
        case .granted:
            EmptyView()

        case .undetermined:
            InlineBanner(kind: .caution,
                         message: "마이크 접근 권한이 필요해요",
                         actionTitle: "권한 요청") {
                Task { await model.resolvePermission() }
            }

        case .denied:
            InlineBanner(kind: .error,
                         message: "마이크 접근이 꺼져 있어 소리를 보낼 수 없어요",
                         actionTitle: "설정 열기") {
                openSettings()
            }
        }
    }

    /// Only Settings can turn a denied microphone back on, so that is where the
    /// banner's action goes.
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Input device

    private var deviceSection: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s12) {
            AudioCheckFieldLabel(title: "입력 장치")

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
                    Task { await model.loadDevices() }
                }

            case .loaded(let devices):
                if devices.isEmpty {
                    Text("사용할 수 있는 입력 장치가 없어요")
                        .typography(.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Device names are hardware, not copy, so they are verbatim.
                    Picker(selection: $model.selectedDevice) {
                        ForEach(devices) { device in
                            Text(verbatim: device.name).tag(Optional(device))
                        }
                    } label: {
                        Text("입력 장치")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: Metric.tapTarget, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Level

    private var meterSection: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            AudioLevelMeter(level: model.levels.level, height: Space.s16)

            Text("말하거나 연주해보세요")
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.showsSilenceWarning {
                InlineBanner(kind: .caution, message: "입력 신호가 감지되지 않습니다")
            }
        }
        .motion(value: model.showsSilenceWarning)
    }

    // MARK: - Monitoring

    private var monitorSection: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Space.s24) {
            Toggle(isOn: $model.isMonitoring) {
                Text("모니터링")
                    .typography(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tint(Palette.ink)
            .frame(minHeight: Metric.tapTarget)

            VStack(alignment: .leading, spacing: Space.s12) {
                AudioCheckFieldLabel(title: "모니터 볼륨")

                Slider(value: $model.volume, in: 0...1) {
                    Text("모니터 볼륨")
                }
                .tint(Palette.ink)
                // With monitoring off there is nothing to set the level of.
                .disabled(!model.isMonitoring)
            }
        }
        .motion(value: model.isMonitoring)
    }

    // MARK: - Latency

    private var latencySection: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            AudioCheckFieldLabel(title: "지연 시간")

            HStack(alignment: .firstTextBaseline, spacing: Space.s12) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    Text(verbatim: "\(model.latencyMilliseconds)")
                        .typography(.displayStat)
                        .foregroundStyle(Palette.ink)

                    Text(verbatim: "ms")
                        .typography(.displayUnit)
                        .foregroundStyle(Palette.ink)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("지연 시간")
                .accessibilityValue(Text("\(model.latencyMilliseconds)밀리초"))

                Spacer(minLength: Space.s12)

                AudioCheckGradeMark(grade: model.grade)
            }

            Text(model.networkStatus)
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .motion(value: model.latencyMilliseconds)
    }

    // MARK: - Start

    private var startBar: some View {
        Button {
            onStart()
        } label: {
            Text("라이브 시작")
                .typography(.bodyStrong)
                .padding(.vertical, Space.s12)
                .frame(maxWidth: .infinity, minHeight: Metric.controlM)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .disabled(!model.canStart)
        .padding(.horizontal, Metric.screenMargin)
        .padding(.bottom, Space.s16)
    }
}

// MARK: - Parts

/// A quiet field label on the check list. The screen's heading is the room it is
/// about to open, so these sit a step below it on the scale.
private struct AudioCheckFieldLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .typography(.metaStrong)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The latency grade, as a filled mark carrying `onSignal` text. The grade owns
/// its colour, and a signal is a fill here — never small coloured body text.
private struct AudioCheckGradeMark: View {
    let grade: LatencyGrade

    var body: some View {
        Text(grade.label)
            .typography(.chip)
            .foregroundStyle(Palette.onSignal)
            .lineLimit(1)
            .padding(.horizontal, Space.s12)
            .padding(.vertical, Space.s4)
            .frame(minHeight: Metric.chipHeight)
            .background(grade.signal, in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("연결 상태")
            .accessibilityValue(Text(grade.label))
    }
}

// MARK: - Previews

private func audioCheckPreviewDraft() -> LiveRoomDraft {
    var draft = LiveRoomDraft.initial(host: Fixtures.seungchan)
    draft.hashtags = Fixtures.seungchan.hashtags
    draft.maxParticipants = 4
    draft.isAcceptingParticipants = true
    return draft
}

private func previewAudioCheck(_ behaviour: MockDataSource.Behaviour = .populated,
                               permission: MicrophonePermission = .granted,
                               input: AudioLevelSource.Mode = .signal,
                               latency: Int? = nil) -> some View {
    NavigationStack {
        AudioCheckView(
            draft: audioCheckPreviewDraft(),
            model: AudioCheckModel(dataSource: MockDataSource(behaviour: behaviour),
                                   permission: permission,
                                   input: input,
                                   latencyMilliseconds: latency),
            onStart: {},
            onBack: {}
        )
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewAudioCheck().preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewAudioCheck().preferredColorScheme(.dark)
}

#Preview("입력 없음") {
    previewAudioCheck(input: .silent)
}

#Preview("권한 미결정") {
    previewAudioCheck(permission: .undetermined)
}

#Preview("권한 허용") {
    previewAudioCheck(permission: .granted)
}

#Preview("권한 거부") {
    previewAudioCheck(permission: .denied)
}

#Preview("지연 불안정") {
    previewAudioCheck(latency: 128)
}

#Preview("장치 로딩") {
    previewAudioCheck(.loading)
}

#Preview("장치 없음") {
    previewAudioCheck(.empty)
}

#Preview("장치 오류") {
    previewAudioCheck(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewAudioCheck().environment(\.dynamicTypeSize, .accessibility3)
}
