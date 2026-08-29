//  RowSeparator.swift
//  The platform hairline between rows in a vertical list.
//
//  This design system separates sections with space rather than rules, and that
//  still holds for *sections*. Inside a long list of like-for-like rows, though,
//  a separator is doing real work: it says where one row ends and the next
//  begins when both are the same shape. `Divider` is the system's own hairline,
//  so it inherits the platform's thickness and its light/dark behaviour.

import SwiftUI

struct RowSeparator: View {
    /// Aligns the rule with the row's text column, the way a system list insets
    /// its separators past a leading avatar or icon.
    var leadingInset: CGFloat = 0

    var body: some View {
        Divider()
            .padding(.leading, leadingInset)
    }
}

/// Places `separator` between elements, never before the first or after the last.
struct SeparatedRows<Data: RandomAccessCollection, RowContent: View>: View
where Data.Element: Identifiable {
    let data: Data
    var leadingInset: CGFloat = 0
    @ViewBuilder var row: (Data.Element) -> RowContent

    var body: some View {
        VStack(spacing: 0) {
            ForEach(data) { element in
                row(element)
                if element.id != data.last?.id {
                    RowSeparator(leadingInset: leadingInset)
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 0) {
        SettingsRow(title: "시청 기록", description: "최근에 본 라이브") {}
        RowSeparator()
        SettingsRow(title: "내 라이브", description: "지난 방송 다시보기와 통계") {}
        RowSeparator()
        SettingsRow(title: "후원 내역", description: "보낸 후원과 받은 후원") {}
    }
    .padding(.horizontal, Metric.screenMargin)
    .background(Palette.surface)
}
