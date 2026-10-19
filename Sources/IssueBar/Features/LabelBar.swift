import SwiftUI
import IssueBarCore

struct LabelBar: View {
    static let shortcutCount = 9

    let labels: [IssueLabel]
    let selected: Set<String>
    let onToggle: (IssueLabel) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Array(labels.enumerated()), id: \.element.id) { index, label in
                    LabelChip(
                        label: label,
                        isSelected: selected.contains(label.name),
                        shortcut: index < Self.shortcutCount ? "⌘\(index + 1)" : nil
                    )
                    .onTapGesture { onToggle(label) }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.never)
        .frame(height: 40)
    }
}

private struct LabelChip: View {
    let label: IssueLabel
    let isSelected: Bool
    let shortcut: String?

    var body: some View {
        let color = Color(hex: label.color)
        HStack(spacing: 6) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle.fill")
                .font(.system(size: isSelected ? 11 : 8))
                .foregroundStyle(color)
            Text(label.name)
                .font(.system(size: 12, weight: .medium))
            if let shortcut {
                Text(shortcut)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? color.opacity(0.28) : Color.primary.opacity(0.06), in: Capsule())
        .overlay(Capsule().strokeBorder(isSelected ? color.opacity(0.9) : .clear, lineWidth: 1))
        .contentShape(Capsule())
        .help(label.description ?? "")
        .fixedSize()
    }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x808080
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
