//  Presentation.swift
//  Display names and signal colours for model enums. Keeping these out of the
//  model layer lets `Models/` stay framework-free, and gives every screen one
//  source for what a role or a state is called.

import SwiftUI

extension PerformerRole {
    var label: LocalizedStringKey {
        switch self {
        case .vocal: "보컬"
        case .guitar: "기타"
        case .bass: "베이스"
        case .keys: "건반"
        case .drums: "드럼"
        case .other: "기타 악기"
        }
    }
}

extension ParticipantState {
    var label: LocalizedStringKey {
        switch self {
        case .performing: "연주 중"
        case .waiting: "대기"
        }
    }

    /// Performing is a distinct, meaningful state, so it earns a signal colour.
    /// Waiting is ordinary and stays on the ink ramp.
    var signal: Color? {
        switch self {
        case .performing: Palette.signalSpecial
        case .waiting: nil
        }
    }
}

extension RoomVisibility {
    var label: LocalizedStringKey {
        switch self {
        case .everyone: "전체 공개"
        case .followers: "팔로워만"
        case .linkOnly: "링크가 있는 사람만"
        }
    }
}

extension JoinApproval {
    var label: LocalizedStringKey {
        switch self {
        case .manual: "승인제"
        case .automatic: "자동 수락"
        }
    }
}

extension SearchScope {
    var label: LocalizedStringKey {
        switch self {
        case .all: "전체"
        case .artist: "아티스트"
        case .live: "라이브"
        case .hashtag: "해시태그"
        }
    }
}

extension LatencyGrade {
    var label: LocalizedStringKey {
        switch self {
        case .good: "좋음"
        case .fair: "보통"
        case .unstable: "불안정"
        }
    }

    var signal: Color {
        switch self {
        case .good: Palette.signalSuccess
        case .fair: Palette.signalCaution
        case .unstable: Palette.signalLive
        }
    }
}
