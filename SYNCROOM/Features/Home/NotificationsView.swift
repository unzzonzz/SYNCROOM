//  NotificationsView.swift  (S9)
//
//  Liquid Glass: the only glass on this screen belongs to the system. "모두 읽음"
//  is a plain `ToolbarItem`, so the navigation bar draws the glass capsule around
//  it and nothing here paints a bar background; `.scrollEdgeEffectStyle(.soft,
//  for: .top)` lets the list dissolve under that bar instead of a gradient mask.
//  The inbox itself is opaque content — rows are separated by space, never by a
//  material or a rule.

import SwiftUI

@MainActor
@Observable
final class NotificationsModel {
    private let dataSource: any DataSource

    var state: LoadState<[AppNotification]> = .loading

    init(dataSource: any DataSource = MockDataSource.shared) {
        self.dataSource = dataSource
    }

    func load() async {
        state = await LoadState.load { try await self.dataSource.notifications() }
    }

    func reload() async {
        state = await LoadState.load { try await self.dataSource.notifications() }
    }

    /// Drives whether the "모두 읽음" action is offered at all.
    var hasUnread: Bool {
        (state.value ?? []).contains { !$0.isRead }
    }

    func markAllRead() {
        guard var items = state.value else { return }
        for index in items.indices {
            items[index].isRead = true
        }
        state = .loaded(items)
    }

    func markRead(_ id: AppNotification.ID) {
        mutate(id) { $0.isRead = true }
    }

    /// The follow toggle on a `.newFollower` row acts on the actor in place, so
    /// the row and its button can never disagree about the follow state.
    func toggleFollow(_ id: AppNotification.ID) {
        mutate(id) { notification in
            notification.isRead = true
            notification.actor?.isFollowing.toggle()
        }
    }

    private func mutate(_ id: AppNotification.ID, _ change: (inout AppNotification) -> Void) {
        guard var items = state.value,
              let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
        state = .loaded(items)
    }
}

struct NotificationsView: View {
    @Environment(SessionModel.self) private var session
    @Environment(PlaybackController.self) private var playback

    @State private var model: NotificationsModel

    init(model: NotificationsModel = NotificationsModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView(.vertical) {
            switch model.state {
            case .loading:
                loadingContent
            case .failed(let error):
                ErrorStateView(error: error) {
                    Task { await model.reload() }
                }
                .padding(.horizontal, Metric.screenMargin)
            case .loaded(let items):
                if items.isEmpty {
                    EmptyStateView(
                        title: "아직 받은 알림이 없어요",
                        message: "팔로우한 아티스트가 라이브를 시작하면 여기에 알려드릴게요."
                    )
                    .padding(.horizontal, Metric.screenMargin)
                } else {
                    inbox(items)
                }
            }
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await model.reload() }
        .navigationTitle("알림")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            // Hidden rather than disabled: with nothing unread there is nothing
            // the action could do, and the title already says so.
            if model.hasUnread {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("모두 읽음") {
                        model.markAllRead()
                        session.markAllNotificationsRead()
                    }
                }
            }
        }
        .task { await model.load() }
    }

    // MARK: - Loaded

    private func inbox(_ items: [AppNotification]) -> some View {
        // A run of like-for-like rows, so the platform hairline earns its place
        // here the same way it does in 내 정보 and the history lists.
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(items) { notification in
                NotificationRow(
                    notification: notification,
                    onOpenLive: {
                        model.markRead(notification.id)
                        playback.watch(Fixtures.chansRoom)
                    },
                    onToggleFollow: { model.toggleFollow(notification.id) },
                    onAcknowledge: { model.markRead(notification.id) }
                )
                .padding(.vertical, Space.s12)

                if notification.id != items.last?.id {
                    RowSeparator()
                }
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s16)
        .padding(.bottom, Space.s48)
    }

    // MARK: - Loading

    /// The real row geometry, redacted, so the list does not jump when the
    /// fixtures land.
    private var loadingContent: some View {
        LazyVStack(alignment: .leading, spacing: Space.s24) {
            ForEach(Fixtures.notifications) { notification in
                NotificationRow(notification: notification,
                                onOpenLive: {},
                                onToggleFollow: {},
                                onAcknowledge: {})
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s16)
        .skeleton(true)
    }
}

// MARK: - Row

private struct NotificationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let notification: AppNotification
    var onOpenLive: () -> Void
    var onToggleFollow: () -> Void
    var onAcknowledge: () -> Void

    var body: some View {
        if notification.kind == .liveStarted {
            Button(action: onOpenLive) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: Space.s12) {
            unreadMarker
            leading

            VStack(alignment: .leading, spacing: Space.s12) {
                VStack(alignment: .leading, spacing: Space.s4) {
                    Text(message)
                        .typography(.body)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(Format.relative(notification.receivedAt))
                        .typography(.meta)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .accessibilityElement(children: .combine)

                // At accessibility sizes the control takes its own line rather
                // than squeezing the message into a two-word column.
                if hasAccessory, dynamicTypeSize.isAccessibilitySize {
                    accessory
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if hasAccessory, !dynamicTypeSize.isAccessibilitySize {
                accessory
            }
        }
        .contentShape(.rect)
    }

    // MARK: Slots

    /// Mail's convention: a dot in a reserved leading column, so read and unread
    /// rows still share one alignment line.
    private var unreadMarker: some View {
        ZStack {
            if !notification.isRead {
                Circle()
                    .fill(Palette.signalLive)
                    .frame(width: Space.s8, height: Space.s8)
                    .accessibilityLabel("읽지 않음")
            }
        }
        .frame(width: Space.s8, height: Metric.avatarL)
    }

    @ViewBuilder
    private var leading: some View {
        if let actor = notification.actor {
            AvatarView(artist: actor, size: Metric.avatarL)
        } else {
            Image(systemName: "megaphone")
                .typography(.sectionTitle)
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: Metric.avatarL, height: Metric.avatarL)
                .background(Palette.surfaceRaised, in: .circle)
                .accessibilityHidden(true)
        }
    }

    private var hasAccessory: Bool {
        switch notification.kind {
        case .newFollower, .joinRequest: true
        case .liveStarted, .donation, .announcement: false
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch notification.kind {
        case .newFollower:
            FollowButton(isFollowing: notification.actor?.isFollowing ?? false,
                         action: onToggleFollow)
        case .joinRequest:
            RowActionButton(title: "확인", action: onAcknowledge)
        case .liveStarted, .donation, .announcement:
            EmptyView()
        }
    }

    // MARK: Copy

    /// Every line is built through `String(localized:)` so the actor and the
    /// amount interpolate into a catalogued format string rather than into a
    /// literal assembled at the call site.
    private var message: String {
        let name = notification.actor?.displayName ?? ""
        let handle = Format.handle(notification.actor?.handle ?? "")

        switch notification.kind {
        case .liveStarted:
            return String(localized: "\(name)님이 라이브를 시작했어요",
                          comment: "Notification: an artist the user follows started a live room")
        case .newFollower:
            return String(localized: "\(handle)님이 회원님을 팔로우합니다",
                          comment: "Notification: someone started following the signed-in user")
        case .donation:
            return String(localized: "\(handle)님이 \(Format.currency(notification.amount ?? 0))을 후원했어요",
                          comment: "Notification: someone sent the signed-in user a donation")
        case .joinRequest:
            return String(localized: "\(handle)님이 참여를 신청했어요",
                          comment: "Notification: someone asked to join the user's live room")
        case .announcement:
            return String(localized: "이번 주 인기 라이브를 확인해보세요",
                          comment: "Notification: editorial announcement from the service")
        }
    }
}

/// The row-scale action button, sized to sit beside `FollowButton` as a sibling
/// rather than as a second kind of control.
private struct RowActionButton: View {
    let title: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .typography(.chip)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, Space.s16)
                .padding(.vertical, Space.s8)
                .frame(minHeight: Space.s32)
                .background(Palette.surfaceRaised, in: .capsule)
        }
        .buttonStyle(.plain)
        .frame(minHeight: Metric.tapTarget)
    }
}

// MARK: - Previews

private func previewNotifications(_ behaviour: MockDataSource.Behaviour) -> some View {
    NavigationStack {
        NotificationsView(
            model: NotificationsModel(dataSource: MockDataSource(behaviour: behaviour))
        )
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewNotifications(.populated).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewNotifications(.populated).preferredColorScheme(.dark)
}

#Preview("로딩") {
    previewNotifications(.loading)
}

#Preview("빈 상태") {
    previewNotifications(.empty)
}

#Preview("오류") {
    previewNotifications(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewNotifications(.populated).environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("알림 행 — 다섯 종류", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s24) {
        ForEach(Fixtures.notifications) { notification in
            NotificationRow(notification: notification,
                            onOpenLive: {},
                            onToggleFollow: {},
                            onAcknowledge: {})
        }
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
