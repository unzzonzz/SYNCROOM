//  HostFlowView.swift  (S10 → S13)
//
//  Liquid Glass: this view paints nothing at all. It is the stage machine behind
//  the `.fullScreenCover` `RootView` presents — the platform's own full-screen
//  takeover, which is the only glass involved — and it owns the navigation
//  containers so each stage can use a real `.toolbar` and get system glass
//  capsules for its close and back controls. The broadcast stage is handed no
//  container, because footage runs edge to edge and draws its own floating
//  glass bars over the stream.

import SwiftUI

// MARK: - Model

@MainActor
@Observable
final class HostFlowModel {

    /// setup → audioCheck → broadcasting → summary → dismiss. Each stage
    /// carries what the next screen needs, so a stage can never be entered
    /// without its payload.
    enum Stage: Hashable, Sendable {
        case setup
        case audioCheck(LiveRoomDraft)
        case broadcasting(LiveRoom)
        case summary(LiveSummary)
    }

    private(set) var stage: Stage

    /// The form as the host last left it, so stepping back from the audio check
    /// returns to what they filled in rather than to an empty form.
    private(set) var draft: LiveRoomDraft?

    /// The room the draft became once it went on air.
    private(set) var room: LiveRoom?

    init(stage: Stage = .setup) {
        self.stage = stage
        if case .audioCheck(let draft) = stage { self.draft = draft }
        if case .broadcasting(let room) = stage { self.room = room }
    }

    func checkAudio(with draft: LiveRoomDraft) {
        self.draft = draft
        stage = .audioCheck(draft)
    }

    func editSetup() {
        stage = .setup
    }

    /// The one place a draft becomes a live room.
    func goLive(host: Artist) {
        guard case .audioCheck(let draft) = stage else { return }
        let room = draft.makeRoom(host: host)
        self.room = room
        stage = .broadcasting(room)
    }

    func finish(with summary: LiveSummary) {
        stage = .summary(summary)
    }
}

// MARK: - Flow

struct HostFlowView: View {
    @Environment(AppRouter.self) private var router
    @Environment(SessionModel.self) private var session

    @State private var model: HostFlowModel

    init(model: HostFlowModel = HostFlowModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            switch model.stage {
            case .setup:
                NavigationStack {
                    LiveSetupView(draft: model.draft) { draft in
                        model.checkAudio(with: draft)
                    } onClose: {
                        dismissFlow()
                    }
                }

            case .audioCheck(let draft):
                NavigationStack {
                    AudioCheckView(draft: draft) {
                        model.goLive(host: session.currentUser)
                    } onBack: {
                        model.editSetup()
                    }
                }

            case .broadcasting(let room):
                BroadcastView(room: room) { summary in
                    model.finish(with: summary)
                }

            case .summary(let summary):
                NavigationStack {
                    BroadcastSummaryView(summary: summary) {
                        dismissFlow()
                    }
                }
            }
        }
        .motion(value: model.stage)
    }

    /// The flow is a presentation of the router, so it closes the same way it
    /// opened — through `router.startHosting()`'s flag.
    private func dismissFlow() {
        router.isPresentingHostFlow = false
    }
}

// MARK: - Previews

/// A filled-in draft, so the stages after setup show what a real handover looks
/// like rather than an empty form.
private func hostFlowPreviewDraft() -> LiveRoomDraft {
    var draft = LiveRoomDraft.initial(host: Fixtures.seungchan)
    draft.hashtags = Fixtures.seungchan.hashtags
    draft.maxParticipants = 4
    draft.isAcceptingParticipants = true
    return draft
}

private func previewHostFlow(_ stage: HostFlowModel.Stage) -> some View {
    HostFlowView(model: HostFlowModel(stage: stage))
        .environment(AppRouter())
        .environment(SessionModel())
        .environment(PlaybackController())
        .environment(SettingsStore())
}

#Preview("라이브 개설 — 라이트") {
    previewHostFlow(.setup).preferredColorScheme(.light)
}

#Preview("라이브 개설 — 다크") {
    previewHostFlow(.setup).preferredColorScheme(.dark)
}

#Preview("오디오 점검") {
    previewHostFlow(.audioCheck(hostFlowPreviewDraft()))
}

#Preview("송출") {
    previewHostFlow(.broadcasting(Fixtures.chansRoom))
}

#Preview("종료 요약") {
    previewHostFlow(.summary(Fixtures.liveSummary))
}

#Preview("Dynamic Type — accessibility3") {
    previewHostFlow(.setup).environment(\.dynamicTypeSize, .accessibility3)
}
