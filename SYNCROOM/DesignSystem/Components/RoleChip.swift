//  RoleChip.swift
//  What a performer is playing. Shares the chip geometry with hashtags so the
//  two read as the same class of object.

import SwiftUI

struct RoleChip: View {
    let role: PerformerRole
    var isSelected: Bool = false

    var body: some View {
        Text(role.label)
            .typography(.chip)
            .foregroundStyle(isSelected ? Palette.surface : Palette.inkChip)
            .lineLimit(1)
            .padding(.horizontal, Space.s12)
            .frame(height: Metric.chipHeight)
            .background(isSelected ? Palette.ink : Palette.surfaceRaised,
                        in: .rect(cornerRadius: Radius.pill(Metric.chipHeight)))
    }
}

/// A single-choice row of roles, used when applying to join a room.
struct RolePicker: View {
    @Binding var selection: PerformerRole?

    var body: some View {
        FlowLayout(spacing: Space.s8, lineSpacing: Space.s8) {
            ForEach(PerformerRole.allCases) { role in
                Button {
                    selection = role
                } label: {
                    RoleChip(role: role, isSelected: selection == role)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == role ? .isSelected : [])
            }
        }
        .motion(value: selection)
    }
}

#Preview("Chips", traits: .sizeThatFitsLayout) {
    @Previewable @State var role: PerformerRole? = .keys
    VStack(alignment: .leading, spacing: Space.s24) {
        RoleChip(role: .vocal)
        RolePicker(selection: $role)
    }
    .frame(width: 320)
    .padding(Space.s24)
    .background(Palette.surface)
}
