//  Live.swift

import Foundation

/// Who can find and open a room.
enum RoomVisibility: String, CaseIterable, Identifiable, Hashable, Sendable {
    case everyone, followers, linkOnly
    var id: String { rawValue }
}

/// How the host handles incoming join requests.
enum JoinApproval: String, CaseIterable, Identifiable, Hashable, Sendable {
    case manual, automatic
    var id: String { rawValue }
}

enum LiveStatus: Hashable, Sendable {
    case live
    case ended
}

struct LiveRoom: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var thumbnailURL: URL?
    var host: Artist
    /// Stored without the leading `#`.
    var hashtags: [String]
    var participantCount: Int
    var viewerCount: Int
    /// 0…4 performer slots beyond the host.
    var maxParticipants: Int
    var isAcceptingParticipants: Bool
    var visibility: RoomVisibility
    var acceptsDonation: Bool
    var status: LiveStatus

    init(id: UUID = UUID(),
         title: String,
         thumbnailURL: URL? = nil,
         host: Artist,
         hashtags: [String] = [],
         participantCount: Int = 0,
         viewerCount: Int = 0,
         maxParticipants: Int = 0,
         isAcceptingParticipants: Bool = false,
         visibility: RoomVisibility = .everyone,
         acceptsDonation: Bool = true,
         status: LiveStatus = .live) {
        self.id = id
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.host = host
        self.hashtags = hashtags
        self.participantCount = participantCount
        self.viewerCount = viewerCount
        self.maxParticipants = maxParticipants
        self.isAcceptingParticipants = isAcceptingParticipants
        self.visibility = visibility
        self.acceptsDonation = acceptsDonation
        self.status = status
    }
}

/// A saved replay of a finished broadcast (S20 "지난 방송", S3 "내 라이브").
struct PastBroadcast: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var thumbnailURL: URL?
    var viewCount: Int
    var endedAt: Date

    init(id: UUID = UUID(), title: String, thumbnailURL: URL? = nil,
         viewCount: Int, endedAt: Date) {
        self.id = id
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.viewCount = viewCount
        self.endedAt = endedAt
    }
}

/// The metrics shown after a broadcast ends (S13).
struct LiveSummary: Hashable, Sendable {
    var duration: TimeInterval
    var peakViewers: Int
    var totalViewers: Int
    var participantCount: Int
    var donationTotal: Int
    var newFollowers: Int
}

// MARK: - Audio (S11)

struct AudioDevice: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// Round-trip latency banding. Colour is derived from this, never chosen ad hoc.
enum LatencyGrade: Hashable, Sendable {
    case good
    case fair
    case unstable

    static func grade(forMilliseconds ms: Int) -> LatencyGrade {
        switch ms {
        case ..<40: .good
        case ..<90: .fair
        default: .unstable
        }
    }
}

/// Whether the app may use the microphone (S11).
enum MicrophonePermission: Hashable, Sendable {
    case undetermined
    case granted
    case denied
}
