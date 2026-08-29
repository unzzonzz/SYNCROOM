//  LiveMoreMenu.swift  (S25)
//
//  Liquid Glass: nothing here is drawn by hand. The control is a system `Menu`
//  wearing the same `.glassEffect` circle as its neighbours, and picking a
//  quality opens a nested system menu rather than a panel of our own. Sharing
//  goes through a plain `.sheet`, which is glass the system owns too.
//
//  Why a `Menu` and not a `.confirmationDialog`: on iOS 26 a dialog with no
//  source anchor is presented as a floating list that simply appears — frame
//  captures show it fully drawn in a single frame, with no transition to speak
//  of, because there is nothing for it to animate out of. A menu is anchored to
//  the control that opened it, so the system grows it from the button and
//  collapses it back. That is also the platform's own pattern for an ellipsis.

import SwiftUI

// MARK: - Quality

/// The three stream qualities the more-menu offers. Named after its menu so it
/// cannot collide with a broadcast-side setting of the same idea.
enum LiveMoreMenuQuality: String, CaseIterable, Identifiable, Hashable, Sendable {
    case automatic, high, dataSaver

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .automatic: "자동"
        case .high: "고화질"
        case .dataSaver: "데이터 절약"
        }
    }

    /// Plain text of the same word, for the toast that confirms the change —
    /// a `LocalizedStringKey` cannot be interpolated into a `String(localized:)`.
    var name: String {
        switch self {
        case .automatic: String(localized: "자동", comment: "Stream quality: automatic")
        case .high: String(localized: "고화질", comment: "Stream quality: high")
        case .dataSaver: String(localized: "데이터 절약", comment: "Stream quality: data saver")
        }
    }
}

// MARK: - Menu state

/// What the menu can put on screen, held by the screen rather than by the
/// button, because a toast and a sheet belong to the whole view — a 44pt
/// control is the wrong thing to anchor them to.
@MainActor
@Observable
final class LiveMoreMenuModel {
    var quality: LiveMoreMenuQuality = .automatic
    var isPresentingShare = false
    /// The menu confirms its own actions, so a screen can adopt it without
    /// wiring up feedback of its own.
    var toast: Toast?

    func select(_ option: LiveMoreMenuQuality) {
        quality = option
        toast = Toast(message: String(localized: "화질 설정 · \(option.name)",
                                      comment: "Toast confirming the chosen stream quality"))
    }

    func report() {
        toast = Toast(message: String(localized: "신고가 접수되었어요",
                                      comment: "Confirmation after reporting a live room"))
    }

    func block() {
        toast = Toast(message: String(localized: "차단했어요",
                                      comment: "Confirmation after blocking a host"))
    }
}

// MARK: - Control

/// The `ellipsis` itself. A `Menu` wearing the glass circle its siblings wear,
/// so it sits in the same `GlassEffectContainer` as the other floating controls.
struct LiveMoreMenuButton: View {
    let model: LiveMoreMenuModel

    var body: some View {
        Menu {
            Button("공유하기") { model.isPresentingShare = true }

            // A nested menu, not a second presentation. Opening one system
            // presentation from inside another drops the incoming transition.
            Menu("화질 설정") {
                ForEach(LiveMoreMenuQuality.allCases) { option in
                    Button {
                        model.select(option)
                    } label: {
                        if model.quality == option {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            }

            Button("채팅 신고") { model.report() }
            Button("이 방송 신고") { model.report() }
            Button("호스트 차단", role: .destructive) { model.block() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: Metric.tapTarget, height: Metric.tapTarget)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.onStream)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("더보기")
    }
}

extension View {
    /// What the live room's menu can put on screen: the share sheet and the
    /// toast that confirms an action.
    func liveMoreMenu(model: LiveMoreMenuModel, room: LiveRoom) -> some View {
        modifier(LiveMoreMenuPresentations(model: model, room: room))
    }
}

private struct LiveMoreMenuPresentations: ViewModifier {
    @Bindable var model: LiveMoreMenuModel
    let room: LiveRoom

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $model.isPresentingShare) {
                LiveMoreMenuShareSheet(room: room)
            }
            .toast($model.toast, topInset: ToastInset.belowStreamControls)
    }
}

// MARK: - Share

/// What "공유하기" opens. The system share sheet needs something to be shared
/// *from*, so this names the room and hands the text to `ShareLink` — no link is
/// invented, because the app has no backend to link to.
struct LiveMoreMenuShareSheet: View {
    let room: LiveRoom

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s24) {
            Text("공유하기")
                .typography(.screenTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Space.s8) {
                Text(room.title)
                    .typography(.cardTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                NameLabel(artist: room.host, style: .meta)
            }

            ShareLink(item: shareText) {
                Text("공유하기")
            }
            .buttonStyle(.syncSolid)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.vertical, Space.s32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var shareText: String {
        String(localized: "\(room.title) · \(Format.handle(room.host.handle))",
               comment: "Text shared from a live room: its title and the host's handle")
    }
}

// MARK: - Previews

/// A stand-in host, so the menu can be opened in a preview from the same
/// control the live room uses — over footage, since that is where it lives.
private struct LiveMoreMenuPreviewHost: View {
    let room: LiveRoom
    @State private var model = LiveMoreMenuModel()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Palette.stream
            GlassControlBar {
                LiveMoreMenuButton(model: model)
            }
            .padding(Metric.screenMargin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liveMoreMenu(model: model, room: room)
    }
}

#Preview("기본 — 라이트") {
    LiveMoreMenuPreviewHost(room: Fixtures.chansRoom).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    LiveMoreMenuPreviewHost(room: Fixtures.chansRoom).preferredColorScheme(.dark)
}

#Preview("공유 시트") {
    LiveMoreMenuShareSheet(room: Fixtures.chansRoom)
}

#Preview("Dynamic Type — accessibility3") {
    LiveMoreMenuPreviewHost(room: Fixtures.longformRoom)
        .environment(\.dynamicTypeSize, .accessibility3)
}
