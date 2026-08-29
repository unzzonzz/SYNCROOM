//  SettingsRow.swift
//  Title, one line of description, chevron.
//
//  Rows are separated by space rather than by a repeated hairline — the design
//  system treats a 1px divider between every row as a last resort, not a default.

import SwiftUI

struct SettingsRow: View {
    let title: LocalizedStringKey
    var description: LocalizedStringKey?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s12) {
                VStack(alignment: .leading, spacing: Space.s4) {
                    Text(title)
                        .typography(.rowTitle)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    if let description {
                        Text(description)
                            .typography(.meta)
                            .foregroundStyle(Palette.inkSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .frame(minHeight: Metric.settingsRow)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// The value-bearing sibling: a label with its current setting on the right.
struct SettingsValueRow: View {
    let title: LocalizedStringKey
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s12) {
                Text(title)
                    .typography(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(value)
                    .typography(.body)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .frame(minHeight: Metric.settingsRow)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 0) {
        SettingsRow(title: "시청 기록", description: "최근에 본 라이브") {}
        SettingsRow(title: "내 라이브", description: "지난 방송 다시보기와 통계") {}
        SettingsRow(title: "후원 내역", description: "보낸 후원과 받은 후원") {}
        SettingsRow(title: "알림 설정", description: "팔로우한 아티스트 라이브 알림") {}
        SettingsValueRow(title: "기본 입력 장치", value: "Focusrite Scarlett 2i2") {}
    }
    .padding(.horizontal, Metric.screenMargin)
    .background(Palette.surface)
}
