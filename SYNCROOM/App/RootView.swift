//  RootView.swift
//  The app shell.
//
//  Liquid Glass: this file is where the platform's glass lives. The tab bar is a
//  system `TabView` — never a custom `HStack` — so it gets the real Liquid Glass
//  treatment, and `.tabBarMinimizeBehavior(.onScrollDown)` lets it shrink out of
//  the way as content scrolls. The mini player is a single
//  `.tabViewBottomAccessory`, which is what satisfies "visible on every page
//  while watching" without any screen drawing a player of its own. The two
//  full-screen flows use `.fullScreenCover`, so they cover the tab bar and the
//  accessory together — the same pattern as the system music player expanding
//  from its mini bar.

import SwiftUI

struct RootView: View {
    @Environment(SessionModel.self) private var session

    var body: some View {
        Group {
            if session.isSignedIn {
                SignedInShell()
            } else {
                AuthFlowView()
            }
        }
        .motion(value: session.isSignedIn)
    }
}

private struct SignedInShell: View {
    @Environment(AppRouter.self) private var router
    @Environment(PlaybackController.self) private var playback

    /// Ties the mini player to the full-screen room, so minimising reads as the
    /// room shrinking into the accessory rather than as a dismiss followed by an
    /// unrelated bar fading in.
    @Namespace private var liveRoomZoom

    var body: some View {
        @Bindable var router = router
        @Bindable var playback = playback

        TabView(selection: $router.tab) {
            Tab("홈", systemImage: "house", value: RootTab.home) {
                NavigationStack(path: $router.homePath) {
                    HomeView()
                        .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
                }
            }
            Tab("탐색", systemImage: "magnifyingglass", value: RootTab.search, role: .search) {
                NavigationStack(path: $router.searchPath) {
                    ExploreView()
                        .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
                }
            }
            Tab("프로필", systemImage: "person", value: RootTab.profile) {
                NavigationStack(path: $router.profilePath) {
                    MyProfileView()
                        .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .modifier(MiniPlayerAccessory(room: playback.watching, zoomNamespace: liveRoomZoom))
        .fullScreenCover(isPresented: $playback.isPresentingRoom) {
            if let room = playback.watching {
                LiveRoomView(room: room, sourceNamespace: liveRoomZoom)
            }
        }
        .fullScreenCover(isPresented: $router.isPresentingHostFlow) {
            HostFlowView()
        }
    }
}

/// Attaches the mini player to the tab bar.
///
/// Returning an empty view from the accessory closure still leaves the system
/// drawing an empty glass capsule above the tab bar, so the accessory has to be
/// switched off rather than emptied. iOS 26.1 added `isEnabled:` for exactly
/// this; on 26.0 — the deployment target — the modifier is attached only while
/// something is playing.
private struct MiniPlayerAccessory: ViewModifier {
    let room: LiveRoom?
    let zoomNamespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: room != nil) {
                if let room {
                    MiniPlayerBar(room: room)
                        .matchedTransitionSource(id: LiveRoomTransition.sourceID, in: zoomNamespace)
                }
            }
        } else if let room {
            content.tabViewBottomAccessory {
                MiniPlayerBar(room: room)
                    .matchedTransitionSource(id: LiveRoomTransition.sourceID, in: zoomNamespace)
            }
        } else {
            content
        }
    }
}

/// Resolves a pushed `Route` to its screen. Keeping this in one place means a
/// screen never needs to know how another screen is constructed.
struct RouteDestination: View {
    let route: Route

    var body: some View {
        switch route {
        case .notifications:
            NotificationsView()
        case .hashtag(let tag):
            HashtagDetailView(tag: tag)
        case .artist(let artist):
            ArtistProfileView(artist: artist)
        case .follows(let scope, let artist):
            FollowListView(artist: artist, scope: scope)
        case .editProfile:
            EditProfileView()
        case .settings:
            SettingsView()
        case .watchHistory:
            WatchHistoryView()
        case .myBroadcasts:
            MyBroadcastsView()
        case .donationHistory:
            DonationHistoryView()
        }
    }
}

#Preview("Signed in") {
    RootView()
        .environment(SessionModel())
        .environment(AppRouter())
        .environment(PlaybackController())
        .environment(SettingsStore())
}

#Preview("Watching — mini player visible") {
    let playback = PlaybackController()
    playback.watch(Fixtures.chansRoom)
    playback.minimize()
    return RootView()
        .environment(SessionModel())
        .environment(AppRouter())
        .environment(playback)
        .environment(SettingsStore())
}
