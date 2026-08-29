//  Artist.swift

import Foundation

struct Artist: Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    /// Stored without the leading `@`; the prefix is added at display time.
    var handle: String
    var avatarURL: URL?
    var isVerified: Bool
    /// Stored without the leading `#`; the prefix is added at display time.
    var hashtags: [String]
    var followerCount: Int
    var followingCount: Int
    var isFollowing: Bool
    var isLive: Bool
    /// One-line bio, shown on profile screens. Empty when the artist has not set one.
    var bio: String

    init(id: UUID = UUID(),
         displayName: String,
         handle: String,
         avatarURL: URL? = nil,
         isVerified: Bool = false,
         hashtags: [String] = [],
         followerCount: Int = 0,
         followingCount: Int = 0,
         isFollowing: Bool = false,
         isLive: Bool = false,
         bio: String = "") {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.avatarURL = avatarURL
        self.isVerified = isVerified
        self.hashtags = hashtags
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.isFollowing = isFollowing
        self.isLive = isLive
        self.bio = bio
    }
}

/// What a performer is playing. `guitar` is the instrument; `other` covers
/// anything not in the list.
enum PerformerRole: String, CaseIterable, Identifiable, Hashable, Sendable {
    case vocal, guitar, bass, keys, drums, other
    var id: String { rawValue }
}

/// Whether a participant is currently playing or queued.
enum ParticipantState: Hashable, Sendable {
    case performing
    case waiting
}

struct Participant: Identifiable, Hashable, Sendable {
    let id: UUID
    var artist: Artist
    var role: PerformerRole
    var isMuted: Bool
    var state: ParticipantState

    init(id: UUID = UUID(),
         artist: Artist,
         role: PerformerRole,
         isMuted: Bool = false,
         state: ParticipantState = .performing) {
        self.id = id
        self.artist = artist
        self.role = role
        self.isMuted = isMuted
        self.state = state
    }
}

/// A viewer asking to join a room as a performer (S21 → S22).
struct JoinRequest: Identifiable, Hashable, Sendable {
    let id: UUID
    var artist: Artist
    var role: PerformerRole
    /// The short note the applicant attached.
    var note: String

    init(id: UUID = UUID(), artist: Artist, role: PerformerRole, note: String) {
        self.id = id
        self.artist = artist
        self.role = role
        self.note = note
    }
}

/// Where a join request stands, from the applicant's side.
enum JoinRequestOutcome: Hashable, Sendable {
    case pending
    case accepted
    case declined
}
