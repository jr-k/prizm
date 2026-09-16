import SwiftUI

// MARK: - CustomFieldsEditSection

/// Editable custom fields for a vault item.
///
/// Names and values can be changed, fields can be added or removed, and hidden values
/// remain masked until explicitly revealed.
struct CustomFieldsEditSection: View {

    /// Binding into the parent draft's `customFields` array.
    @Binding var fields: [DraftCustomField]

    var body: some View {
        DetailSectionCard("Custom Fields") {
            ForEach(fields) { field in
                if let index = fields.firstIndex(where: { $0.id == field.id }) {
                    if index > 0 { Divider() }
                    CustomFieldEditRow(
                        field: $fields[index],
                        canMoveUp: index > fields.startIndex,
                        canMoveDown: index < fields.index(before: fields.endIndex),
                        onMoveUp: {
                            moveField(from: index, to: index - 1)
                        },
                        onMoveDown: {
                            moveField(from: index, to: index + 1)
                        },
                        onDropField: { sourceID in
                            moveField(withID: sourceID, to: index)
                        },
                        onRemove: {
                            fields.removeAll { $0.id == field.id }
                        }
                    )
                }
            }

            if !fields.isEmpty { Divider() }

            Button {
                fields.append(DraftCustomField())
            } label: {
                Label("Add Custom Field", systemImage: "plus")
                    .font(Typography.fieldValue)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
            .padding(.vertical, Spacing.rowVertical)
            .padding(.horizontal, Spacing.rowHorizontal)
            .accessibilityLabel("Add custom field")
        }
    }

    private func moveField(from sourceIndex: Int, to destinationIndex: Int) {
        guard fields.indices.contains(sourceIndex),
              fields.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else { return }
        fields.swapAt(sourceIndex, destinationIndex)
    }

    private func moveField(withID sourceID: String, to destinationIndex: Int) -> Bool {
        guard let id = UUID(uuidString: sourceID),
              let sourceIndex = fields.firstIndex(where: { $0.id == id }),
              fields.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else { return false }

        fields.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
        )
        return true
    }
}

// MARK: - CustomFieldEditRow

/// A single editable row for one custom field.
private struct CustomFieldEditRow: View {

    @Binding var field: DraftCustomField
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDropField: (String) -> Bool
    let onRemove: () -> Void

    /// Controls reveal state for Hidden fields (masked by default - spec §4.9).
    @State private var isRevealed = false
    @State private var isDropTargeted = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.headerGap) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .draggable(field.id.uuidString)
                .help("Drag to reorder")
                .accessibilityLabel("Reorder \(accessibleFieldName)")

            VStack(alignment: .leading, spacing: 2) {
                TextField("Key", text: $field.name)
                    .font(Typography.fieldLabel)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Custom field key")

                switch field.type {
                case .hidden:
                    editableHiddenField

                case .boolean:
                    // Boolean fields use a Toggle; value is "true" or "false" string.
                    Toggle(
                        isOn: Binding(
                            get:  { field.value == "true" },
                            set:  { field.value = $0 ? "true" : "false" }
                        )
                    ) {
                        EmptyView()
                    }
                    .labelsHidden()
                    .accessibilityLabel("\(accessibleFieldName) value")
                    .accessibilityValue(field.value == "true" ? "True" : "False")

                case .linked:
                    // Linked fields are read-only by design - their value is derived
                    // from another field and cannot be independently edited.
                    Text(field.value ?? "-")
                        .font(Typography.fieldValue)
                        .foregroundStyle(.secondary)

                default: // .text
                    TextField("Value", text: valueBinding)
                    .font(Typography.fieldValue)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("\(accessibleFieldName) value")
                }
            }
            Spacer()

            if field.type == .hidden {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide" : "Reveal")
                .accessibilityLabel(isRevealed ? "Hide \(accessibleFieldName)" : "Reveal \(accessibleFieldName)")
            }

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Remove custom field")
            .accessibilityLabel("Remove \(accessibleFieldName)")
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
        .background(
            isDropTargeted
                ? Color.accentColor.opacity(Opacity.dropTarget(contrast))
                : Color.clear
        )
        .dropDestination(for: String.self) { sourceIDs, _ in
            guard let sourceID = sourceIDs.first else { return false }
            return onDropField(sourceID)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .accessibilityAction(named: "Move up") {
            if canMoveUp { onMoveUp() }
        }
        .accessibilityAction(named: "Move down") {
            if canMoveDown { onMoveDown() }
        }
    }

    @ViewBuilder
    private var editableHiddenField: some View {
        if isRevealed {
            TextField("Value", text: valueBinding)
            .font(Typography.fieldValue.monospaced())
            .textFieldStyle(.plain)
            .accessibilityLabel("\(accessibleFieldName) value")
        } else {
            SecureField("Value", text: valueBinding)
                .font(Typography.fieldValue.monospaced())
                .textFieldStyle(.plain)
                .accessibilityLabel("\(accessibleFieldName) value")
        }
    }

    private var valueBinding: Binding<String> {
        Binding(
            get: { field.value ?? "" },
            set: { field.value = $0.isEmpty ? nil : $0 }
        )
    }

    private var accessibleFieldName: String {
        field.name.isEmpty ? "custom field" : field.name
    }
}
