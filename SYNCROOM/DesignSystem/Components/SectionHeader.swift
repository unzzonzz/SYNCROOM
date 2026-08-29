//  SectionHeader.swift
//  A section title, optionally with one text action on the right.
//
//  Sections are separated by whitespace, not rules — this header carries no
//  divider, and screens should set the space above it rather than draw a line.

import SwiftUI

struct SectionHeader: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .typography(.sectionTitle)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: Space.s12)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .typography(.metaStrong)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .buttonStyle(.plain)
                .frame(minHeight: Metric.tapTarget)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s24) {
        SectionHeader(title: "인기있는 라이브")
        SectionHeader(title: "최근 검색어", actionTitle: "전체삭제") {}
        SectionHeader(title: "실시간 채팅", actionTitle: "숨기기") {}
    }
    .padding(Space.s24)
    .background(Palette.surface)
}
