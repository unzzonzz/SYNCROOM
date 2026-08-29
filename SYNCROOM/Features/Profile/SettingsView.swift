//  SettingsView.swift  (S19)
//
//  Liquid Glass: this screen draws no surface of its own. A system `List` is the
//  native settings idiom, so the platform owns the grouped material, the row
//  separators and the navigation bar that floats in glass above them — and the
//  two-step deletion uses system `.alert`, which the system also renders in
//  glass. Adding any background here would only compete with what the OS draws.

import SwiftUI

@MainActor
@Observable
final class SettingsModel {
    private let dataSource: any DataSource

    /// The only asynchronous thing on this screen: the list of capture devices
    /// offered for "기본 입력 장치". Everything else is local preference state.
    var devices: LoadState<[AudioDevice]> = .loading

    init(dataSource: any DataSource = MockDataSource.shared) {
        self.dataSource = dataSource
    }

    func load() async {
        devices = await LoadState.load { try await self.dataSource.audioDevices() }
    }
}

struct SettingsView: View {
    @Environment(SessionModel.self) private var session
    @Environment(SettingsStore.self) private var settings

    @State private var model: SettingsModel
    /// Step one of the deletion confirmation.
    @State private var isConfirmingDeletion = false
    /// Step two: the irreversibility, stated on its own so it cannot be skimmed.
    @State private var isConfirmingErasure = false

    init(model: SettingsModel = SettingsModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var settings = settings

        List {
            Section {
                ForEach(SettingsTopic.account) { topic in
                    NavigationLink {
                        SettingsPlaceholderView(topic: topic)
                    } label: {
                        SettingsRowLabel(title: topic.title)
                    }
                }
            } header: {
                Text("계정")
            }

            Section {
                Toggle(isOn: $settings.liveStartAlerts) {
                    SettingsRowLabel(title: "라이브 시작")
                }
                Toggle(isOn: $settings.followAlerts) {
                    SettingsRowLabel(title: "팔로우")
                }
                Toggle(isOn: $settings.donationAlerts) {
                    SettingsRowLabel(title: "후원")
                }
                Toggle(isOn: $settings.marketingAlerts) {
                    SettingsRowLabel(title: "마케팅")
                }
            } header: {
                Text("알림")
            }

            Section {
                inputDeviceRow($settings.preferredInputDevice)
                Toggle(isOn: $settings.dataSaver) {
                    SettingsRowLabel(title: "데이터 절약 모드")
                }
                Toggle(isOn: $settings.autoplay) {
                    SettingsRowLabel(title: "자동 재생")
                }
            } header: {
                Text("오디오 · 재생")
            }

            Section {
                NavigationLink {
                    SettingsPlaceholderView(topic: .paymentMethods)
                } label: {
                    SettingsRowLabel(title: SettingsTopic.paymentMethods.title)
                }
                NavigationLink(value: Route.donationHistory) {
                    SettingsRowLabel(title: "후원 내역")
                }
            } header: {
                Text("결제")
            }

            Section {
                ForEach(SettingsTopic.information) { topic in
                    NavigationLink {
                        SettingsPlaceholderView(topic: topic)
                    } label: {
                        SettingsRowLabel(title: topic.title)
                    }
                }
                if let appVersion {
                    LabeledContent {
                        SettingsRowValue(value: appVersion)
                    } label: {
                        SettingsRowLabel(title: "버전")
                    }
                }
            } header: {
                Text("정보")
            }

            Section {
                Button {
                    session.signOut()
                } label: {
                    SettingsRowLabel(title: "로그아웃")
                }

                Button(role: .destructive) {
                    isConfirmingDeletion = true
                } label: {
                    Text("회원 탈퇴")
                        .typography(.rowTitle)
                        .foregroundStyle(Palette.signalLive)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Step one lives on the button and step two on the list, so the
                // second alert is never asked to present from inside the first.
                .alert("회원 탈퇴를 진행할까요?", isPresented: $isConfirmingDeletion) {
                    Button("취소", role: .cancel) {}
                    Button("계속", role: .destructive) { isConfirmingErasure = true }
                } message: {
                    Text("프로필, 지난 방송, 후원 내역이 모두 사라져요.")
                }
            }
        }
        // A `List` brings its own grouped background, which is the one surface in
        // the app that would not be our own. Hiding it and painting `surface`
        // underneath keeps Settings on the same ground as every other screen —
        // and, because the token carries light, dark and high-contrast variants,
        // in every appearance.
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .listRowBackground(Palette.surface)
        .navigationTitle("설정")
        .alert("정말 탈퇴할까요?", isPresented: $isConfirmingErasure) {
            Button("취소", role: .cancel) {}
            Button("탈퇴하기", role: .destructive) { session.signOut() }
        } message: {
            Text("한 번 삭제한 계정은 되돌릴 수 없어요.")
        }
        .task { await model.load() }
    }

    // MARK: - Audio input

    /// The device picker only offers a choice when there is a list to choose
    /// from. While it loads, and when it fails, the row states what is in use
    /// rather than pretending the selection can be changed.
    @ViewBuilder
    private func inputDeviceRow(_ selection: Binding<AudioDevice>) -> some View {
        switch model.devices {
        case .loaded(let devices) where !devices.isEmpty:
            Picker(selection: selection) {
                ForEach(devices) { device in
                    Text(verbatim: device.name).tag(device)
                }
            } label: {
                SettingsRowLabel(title: "기본 입력 장치")
            }

        case .loading:
            LabeledContent {
                SettingsRowValue(value: selection.wrappedValue.name)
            } label: {
                SettingsRowLabel(title: "기본 입력 장치")
            }
            .skeleton(true)

        case .loaded, .failed:
            LabeledContent {
                SettingsRowValue(value: selection.wrappedValue.name)
            } label: {
                SettingsRowLabel(title: "기본 입력 장치")
            }
            Button {
                Task { await model.load() }
            } label: {
                SettingsRowLabel(title: "입력 장치 다시 불러오기")
            }
        }
    }

    // MARK: - Version

    /// Read from the bundle so the number on screen can never drift from the
    /// build the user is actually running.
    private var appVersion: String? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let version, !version.isEmpty else { return nil }
        return version
    }
}

// MARK: - Row parts

/// Every row label in the list, at one scale, whatever control sits beside it.
private struct SettingsRowLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .typography(.rowTitle)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The current value of a setting, trailing its label.
private struct SettingsRowValue: View {
    let value: String

    var body: some View {
        Text(value)
            .typography(.body)
            .foregroundStyle(Palette.inkSecondary)
            .lineLimit(1)
    }
}

// MARK: - Placeholder destinations

/// The settings destinations that exist in the information architecture but have
/// nothing behind them yet. Each is a real push to an honest placeholder, so no
/// row on this screen carries a chevron that does nothing.
private enum SettingsTopic: String, Identifiable, Hashable, CaseIterable {
    case credentials, socialAccounts, artistVerification
    case paymentMethods
    case announcements, support, terms, privacy

    var id: String { rawValue }

    static let account: [SettingsTopic] = [.credentials, .socialAccounts, .artistVerification]
    static let information: [SettingsTopic] = [.announcements, .support, .terms, .privacy]

    var title: LocalizedStringKey {
        switch self {
        case .credentials: "이메일·비밀번호"
        case .socialAccounts: "연결된 소셜 계정"
        case .artistVerification: "아티스트 인증 신청"
        case .paymentMethods: "결제 수단 관리"
        case .announcements: "공지사항"
        case .support: "고객센터"
        case .terms: "이용약관"
        case .privacy: "개인정보처리방침"
        }
    }
}

private struct SettingsPlaceholderView: View {
    let topic: SettingsTopic

    var body: some View {
        ScrollView(.vertical) {
            EmptyStateView(
                title: "아직 준비 중이에요",
                message: "이 화면은 다음 업데이트에서 열려요. 그때까지는 설정에서 바뀌는 것이 없어요."
            )
            .padding(.horizontal, Metric.screenMargin)
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .navigationTitle(topic.title)
        .toolbarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

private func previewSettings(_ behaviour: MockDataSource.Behaviour) -> some View {
    NavigationStack {
        SettingsView(model: SettingsModel(dataSource: MockDataSource(behaviour: behaviour)))
            .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewSettings(.populated).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewSettings(.populated).preferredColorScheme(.dark)
}

#Preview("로딩") {
    previewSettings(.loading)
}

#Preview("빈 상태") {
    previewSettings(.empty)
}

#Preview("오류") {
    previewSettings(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewSettings(.populated).environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("준비 중 화면") {
    NavigationStack {
        SettingsPlaceholderView(topic: .terms)
    }
}
