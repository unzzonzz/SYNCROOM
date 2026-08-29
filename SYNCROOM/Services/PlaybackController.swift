//  PlaybackController.swift
//  What the viewer is currently watching.
//
//  This is the only source of truth behind the mini player. `RootView` reads it
//  in a single `.tabViewBottomAccessory`, which is what makes the mini player
//  appear on every tab without any screen having to draw it.

import Observation
import SwiftUI

/// Everything the live room screen needs to survive being minimised.
///
/// The full-screen cover is torn down when it is dismissed, so anything held in
/// the view would reload from scratch on the way back — and minimising would be
/// indistinguishable from leaving and re-entering. Holding it here means the
/// chat, its scroll position and the collapse state are exactly where they were.
@MainActor
@Observable
final class LiveRoomSession {
    let room: LiveRoom
    var detail: LoadState<RoomDetail> = .loading
    var isChatHidden = false
    /// The message the chat was scrolled to, restored on re-expand.
    var chatAnchorID: UUID?

    init(room: LiveRoom) {
        self.room = room
    }
}

@MainActor
@Observable
final class PlaybackController {

    /// The room being watched, or `nil` when nothing is playing.
    private(set) var watching: LiveRoom?

    /// State for the room on screen, kept across minimise and re-expand and
    /// discarded only when the session actually ends.
    private(set) var session: LiveRoomSession?

    /// Whether the full-screen room detail is on screen. The mini player and the
    /// full screen are two presentations of the same session, exactly like the
    /// system music player.
    var isPresentingRoom = false

    var isWatching: Bool { watching != nil }

    /// Opens a room full screen and starts the session.
    ///
    /// The accessory needs exactly one source of motion. The system does not
    /// animate its own attach/detach, so without this the mini player and the
    /// tab bar jump in a single frame; with this *and* a transition on the
    /// accessory's content, the content slid while the container collapsed and
    /// the two read as separate movements. One animation, on the state, and no
    /// transition inside.
    func watch(_ room: LiveRoom) {
        withAnimation(Motion.standard) {
            // Re-entering the same room keeps its session; a different room
            // starts a fresh one.
            if session?.room.id != room.id {
                session = LiveRoomSession(room: room)
            }
            watching = room
            isPresentingRoom = true
        }
    }

    /// Collapses the full screen back to the mini player, still watching.
    func minimize() {
        isPresentingRoom = false
    }

    /// Re-opens the full screen for the session already in progress.
    func expand() {
        guard watching != nil else { return }
        isPresentingRoom = true
    }

    /// Ends the session and removes the mini player. See `watch(_:)` for why the
    /// animation lives here and nowhere else.
    func stop() {
        withAnimation(Motion.standard) {
            watching = nil
            session = nil
            isPresentingRoom = false
        }
    }
}
