//  LiveRoomDraft.swift
//  A room being configured, before it goes on air.
//
//  Shared by the setup screen, the audio check and the broadcast screen, so the
//  choices made in setup survive all the way to air.

import Foundation

struct LiveRoomDraft: Hashable, Sendable {
    var title: String
    /// Stored without the leading `#`. Capped at `maxHashtags`.
    var hashtags: [String]
    /// Performer slots besides the host, 0…4.
    var maxParticipants: Int
    var approval: JoinApproval
    var isAcceptingParticipants: Bool
    var visibility: RoomVisibility
    var acceptsDonation: Bool
    var thumbnailURL: URL?

    static let maxHashtags = 5
    static let maxTitleLength = 40
    static let participantRange = 0...4

    /// A new room, pre-titled after its host the way the product does it.
    static func initial(host: Artist) -> LiveRoomDraft {
        LiveRoomDraft(
            title: String(localized: "\(host.displayName)의 방",
                          comment: "Default live room title, named after its host"),
            hashtags: [],
            maxParticipants: 0,
            approval: .manual,
            isAcceptingParticipants: false,
            visibility: .everyone,
            acceptsDonation: true,
            thumbnailURL: nil
        )
    }

    /// The live room this draft becomes when the broadcast starts.
    func makeRoom(host: Artist) -> LiveRoom {
        LiveRoom(
            title: title,
            thumbnailURL: thumbnailURL,
            host: host,
            hashtags: hashtags,
            participantCount: 0,
            viewerCount: 0,
            maxParticipants: maxParticipants,
            isAcceptingParticipants: isAcceptingParticipants,
            visibility: visibility,
            acceptsDonation: acceptsDonation,
            status: .live
        )
    }
}
