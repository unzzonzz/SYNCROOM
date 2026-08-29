//  Fixtures.swift
//  The single fixture graph the whole app and every preview reads from.
//
//  Identity is stable for the lifetime of the process, so a room opened from the
//  home shelf is the same room the chat, participant sheet and mini player see.
//  Previews reference these values directly, which keeps a card in a preview and
//  the same card on a screen showing identical content.
//
//  Media URLs are deliberately `nil`: the app makes no network requests, so every
//  image goes down the `AsyncImage` placeholder path.

import Foundation

enum Fixtures {

    // MARK: - Artists

    static let seungchan = Artist(
        displayName: "김승찬",
        handle: "unzzonzz",
        isVerified: true,
        hashtags: ["R&B", "CCM", "피아노", "충만하게"],
        followerCount: 120_000,
        followingCount: 10,
        isLive: true,
        bio: "건반 앞에서 가장 솔직해집니다."
    )

    static let user = Artist(
        displayName: "User",
        handle: "user",
        hashtags: ["HASHTAG", "HASHTAG_01", "HASHTAG_02"],
        followerCount: 0,
        followingCount: 0
    )

    /// Exercises the long-text edge cases: a 20-character handle and six hashtags.
    static let longform = Artist(
        displayName: "긴 이름을 가진 아티스트",
        handle: "verylonghandle_20chr",
        hashtags: ["HASHTAG", "HASHTAG_01", "HASHTAG_02", "HASHTAG_03", "HASHTAG_04", "HASHTAG_05"],
        followerCount: 1_204_392,
        followingCount: 842,
        isLive: true,
        bio: "긴 소개 문구가 어떻게 줄바꿈되는지 확인하기 위한 계정입니다."
    )

    // Chat participants. These are viewers, not performers, so they carry no
    // hashtags or follower counts of their own.
    static let brightWolf = Artist(displayName: "BrightWolf6156", handle: "BrightWolf6156")
    static let silentEagle = Artist(displayName: "SilentEagle7634", handle: "SilentEagle7634")
    static let fastDragon = Artist(displayName: "FastDragon3291", handle: "FastDragon3291")
    static let happyPanda = Artist(displayName: "HappyPanda9482", handle: "HappyPanda9482")
    static let loudLion = Artist(displayName: "LoudLion1573", handle: "LoudLion1573")

    static let allArtists: [Artist] = [
        seungchan, user, longform, brightWolf, silentEagle, fastDragon, happyPanda, loudLion,
    ]

    // MARK: - Rooms

    static let chansRoom = LiveRoom(
        title: "김승찬의 방",
        host: seungchan,
        hashtags: ["R&B", "CCM", "피아노", "충만하게"],
        participantCount: 1,
        viewerCount: 8_304,
        maxParticipants: 4,
        isAcceptingParticipants: true,
        acceptsDonation: true
    )

    static let plainRoom = LiveRoom(
        title: "Title",
        host: user,
        hashtags: ["HASHTAG", "HASHTAG_01", "HASHTAG_02"],
        participantCount: 0,
        viewerCount: 0,
        maxParticipants: 0
    )

    /// The wrap case: a title that runs to two lines and six hashtags that fill
    /// the two-line chip block before clipping.
    static let longformRoom = LiveRoom(
        title: "밤새도록 이어지는 어쿠스틱 세션 그리고 아주 긴 제목",
        host: longform,
        hashtags: ["HASHTAG", "HASHTAG_01", "HASHTAG_02", "HASHTAG_03", "HASHTAG_04", "HASHTAG_05"],
        participantCount: 3,
        viewerCount: 1_204_392,
        maxParticipants: 4,
        isAcceptingParticipants: false
    )

    static let secondPlainRoom = LiveRoom(
        title: "Title",
        host: user,
        hashtags: ["HASHTAG", "HASHTAG_01", "HASHTAG_02"],
        participantCount: 0,
        viewerCount: 0,
        maxParticipants: 0
    )

    /// A finished broadcast, for the ended-live edge case on the detail screen.
    static let endedRoom = LiveRoom(
        title: "지난 밤의 방",
        host: user,
        hashtags: ["HASHTAG"],
        participantCount: 0,
        viewerCount: 0,
        status: .ended
    )

    static let shelfRooms: [LiveRoom] = [chansRoom, plainRoom, longformRoom, secondPlainRoom]

    static let allRooms: [LiveRoom] = shelfRooms + [endedRoom]

    // MARK: - Home

    static let heroSlides: [HeroSlide] = [
        HeroSlide(room: chansRoom),
        HeroSlide(room: longformRoom),
        HeroSlide(room: plainRoom),
    ]

    static let homeShelves: [HomeShelf] = [
        HomeShelf(title: String(localized: "인기있는 라이브",
                                comment: "Home shelf: most-watched rooms"),
                  rooms: shelfRooms),
        // An editorial shelf chosen by operations. Its title is not derived from
        // a hashtag, which is why the shelf carries its own name.
        HomeShelf(title: String(localized: "감성 충만하게",
                                comment: "Home shelf: curated editorial selection"),
                  rooms: shelfRooms),
    ]

    /// Shape-only stand-ins shown behind `.redacted(.placeholder)` while the
    /// home feed loads. Redaction removes every glyph, so only the geometry of
    /// what is arriving survives.
    private static func placeholderRoom() -> LiveRoom {
        LiveRoom(title: "Title", host: user,
                 hashtags: ["HASHTAG", "HASHTAG_01", "HASHTAG_02"],
                 participantCount: 0, viewerCount: 0)
    }

    static let placeholderShelves: [HomeShelf] = [
        HomeShelf(title: String(localized: "인기있는 라이브",
                                comment: "Home shelf: most-watched rooms"),
                  rooms: [placeholderRoom(), placeholderRoom()]),
        HomeShelf(title: String(localized: "감성 충만하게",
                                comment: "Home shelf: curated editorial selection"),
                  rooms: [placeholderRoom(), placeholderRoom()]),
    ]

    // MARK: - Explore

    static let recentQueries: [RecentQuery] = [
        .artist(seungchan),
        .hashtag("R&B"),
        .hashtag("CCM"),
        .hashtag("피아노"),
    ]

    static let recommendedArtists: [Artist] = [seungchan, user, longform]
    /// Only artists who are actually on air — the shelf is titled
    /// "라이브 중인 아티스트", so an offline artist in it would be a lie.
    static let liveArtists: [Artist] = allArtists.filter(\.isLive)

    // MARK: - Hashtags

    static let hashtagStats: [HashtagStat] = [
        HashtagStat(tag: "R&B", liveCount: 128, artistCount: 2_341),
        HashtagStat(tag: "CCM", liveCount: 64, artistCount: 892),
        HashtagStat(tag: "피아노", liveCount: 210, artistCount: 4_118),
        HashtagStat(tag: "충만하게", liveCount: 12, artistCount: 96),
    ]

    /// Enough tags to overflow any card, for the "+N" previews.
    static let manyHashtags: [String] = [
        "R&B", "CCM", "피아노", "충만하게", "재즈", "어쿠스틱", "보컬", "드럼", "작곡", "커버",
    ]

    /// Offered when a search returns nothing.
    static let suggestedHashtags: [String] = ["R&B", "CCM", "피아노", "충만하게"]

    /// The picker grid in profile setup.
    static let selectableHashtags: [String] = [
        "R&B", "CCM", "피아노", "충만하게", "재즈", "어쿠스틱", "보컬", "드럼", "작곡", "커버",
    ]

    // MARK: - Chat

    /// The live chat log, in order. `FastDragon3291` carries a 10,000원 donation,
    /// which lands in the top emphasis tier.
    static let chatLog: [ChatMessage] = [
        ChatMessage(authorHandle: "BrightWolf6156", text: "노래 진짜 좋다"),
        ChatMessage(authorHandle: "SilentEagle7634", text: "혹시 신청곡 받나요?"),
        ChatMessage(authorHandle: "FastDragon3291", text: "안녕하세요",
                    donation: Donation(amount: 10_000)),
        ChatMessage(authorHandle: "HappyPanda9482", text: "ㅋㅋㅋㅋㅋ"),
        ChatMessage(authorHandle: "LoudLion1573", text: "다음 곡 기대가 됩니다!"),
    ]

    /// One message per donation tier, for the component preview.
    static let donationTiers: [ChatMessage] = [
        ChatMessage(authorHandle: "BrightWolf6156", text: "화이팅!",
                    donation: Donation(amount: 1_000)),
        ChatMessage(authorHandle: "SilentEagle7634", text: "잘 듣고 있어요",
                    donation: Donation(amount: 5_000)),
        ChatMessage(authorHandle: "FastDragon3291", text: "안녕하세요",
                    donation: Donation(amount: 10_000)),
    ]

    // MARK: - Participants

    static let participants: [Participant] = [
        Participant(artist: user, role: .guitar, state: .performing),
    ]

    static let joinRequests: [JoinRequest] = [
        JoinRequest(artist: happyPanda, role: .vocal, note: "한 곡만 같이 부르고 싶어요!"),
        JoinRequest(artist: loudLion, role: .drums, note: "리듬 맞춰볼게요"),
    ]

    // MARK: - Notifications

    static let notifications: [AppNotification] = [
        AppNotification(kind: .liveStarted, actor: seungchan,
                        receivedAt: .now.addingTimeInterval(-60 * 3)),
        AppNotification(kind: .newFollower, actor: fastDragon,
                        receivedAt: .now.addingTimeInterval(-60 * 42)),
        AppNotification(kind: .donation, actor: silentEagle, amount: 5_000,
                        receivedAt: .now.addingTimeInterval(-60 * 60 * 5)),
        AppNotification(kind: .joinRequest, actor: happyPanda,
                        receivedAt: .now.addingTimeInterval(-60 * 60 * 20)),
        AppNotification(kind: .announcement,
                        receivedAt: .now.addingTimeInterval(-60 * 60 * 26), isRead: true),
    ]

    // MARK: - Account

    static let paymentMethods: [PaymentMethod] = [
        PaymentMethod(brand: "신한카드", last4: "4417"),
    ]

    static let donationHistory: [DonationRecord] = [
        DonationRecord(counterpart: seungchan, roomTitle: "김승찬의 방", amount: 10_000,
                       sentAt: .now.addingTimeInterval(-60 * 60 * 3), isOutgoing: true),
        DonationRecord(counterpart: silentEagle, roomTitle: "김승찬의 방", amount: 5_000,
                       sentAt: .now.addingTimeInterval(-60 * 60 * 30), isOutgoing: false),
        DonationRecord(counterpart: fastDragon, roomTitle: "김승찬의 방", amount: 30_000,
                       sentAt: .now.addingTimeInterval(-60 * 60 * 52), isOutgoing: false),
    ]

    static let pastBroadcasts: [PastBroadcast] = [
        PastBroadcast(title: "새벽 두 시의 피아노", viewCount: 12_940,
                      endedAt: .now.addingTimeInterval(-60 * 60 * 24 * 2)),
        PastBroadcast(title: "CCM 커버 모음", viewCount: 8_120,
                      endedAt: .now.addingTimeInterval(-60 * 60 * 24 * 9)),
        PastBroadcast(title: "Title", viewCount: 402,
                      endedAt: .now.addingTimeInterval(-60 * 60 * 24 * 21)),
    ]

    static let watchHistory: [LiveRoom] = [chansRoom, longformRoom, plainRoom]

    // MARK: - Devices

    static let audioDevices: [AudioDevice] = [
        AudioDevice(name: "Focusrite Scarlett 2i2"),
        AudioDevice(name: "내장 마이크"),
    ]

    // MARK: - Broadcast result

    /// 01:24:07 of airtime, and the numbers that came with it.
    static let liveSummary = LiveSummary(
        duration: 5_047,
        peakViewers: 8_304,
        totalViewers: 12_940,
        participantCount: 3,
        donationTotal: 128_000,
        newFollowers: 342
    )
}
