import SwiftUI

// MARK: - LoginEditForm

/// Edit form for Login vault items.
///
/// Mirrors the layout of `LoginDetailView`: Credentials card, Websites card,
/// Notes card, Custom Fields card. URIs can be added, removed, and reordered.
/// Password is masked by default.
struct LoginEditForm: View {

    @Binding var draft: DraftLoginContent
    let totpCodeGenerator: any TOTPCodeGenerating

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            DetailSectionCard("Credentials") {
                OptionalEditFieldRow(label: "Username", value: $draft.username)
                Divider()
                MaskedEditFieldRow(label: "Password", value: $draft.password, generatorBinding: $draft.password)
            }

            additionalFieldsSection

            DetailSectionCard("Websites") {
                ForEach(draft.uris) { uri in
                    if let index = draft.uris.firstIndex(where: { $0.id == uri.id }) {
                        if index > 0 { Divider() }
                        URIEditRow(
                            uri: $draft.uris[index],
                            canMoveUp: index > 0,
                            canMoveDown: index < draft.uris.count - 1,
                            showReorderButtons: draft.uris.count > 1,
                            onMoveUp: {
                                guard let i = draft.uris.firstIndex(where: { $0.id == uri.id }), i > 0 else { return }
                                draft.uris.swapAt(i, i - 1)
                            },
                            onMoveDown: {
                                guard let i = draft.uris.firstIndex(where: { $0.id == uri.id }), i < draft.uris.count - 1 else { return }
                                draft.uris.swapAt(i, i + 1)
                            },
                            onRemove: {
                                guard let i = draft.uris.firstIndex(where: { $0.id == uri.id }) else { return }
                                draft.uris.remove(at: i)
                            }
                        )
                    }
                }
                if !draft.uris.isEmpty { Divider() }
                Button {
                    draft.uris.append(DraftLoginURI())
                } label: {
                    Label("Add Website", systemImage: "plus")
                        .font(Typography.fieldValue)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
                .padding(.vertical, Spacing.rowVertical)
                .padding(.horizontal, Spacing.rowHorizontal)
                .accessibilityLabel("Add website")
            }

            DetailSectionCard("Notes") {
                OptionalEditFieldRow(label: "Notes", value: $draft.notes)
            }
        }
    }

    private var additionalFieldsSection: some View {
        DetailSectionCard(
            "Additional Fields",
            showsBackground: draft.totp != nil
        ) {
            if draft.totp != nil {
                TOTPSecretEditView(
                    configuration: Binding(
                        get: { draft.totp ?? "" },
                        set: { draft.totp = $0 }
                    ),
                    generator: totpCodeGenerator
                )
                Divider()
                Button("Remove Authenticator", role: .destructive) {
                    draft.totp = nil
                }
                .buttonStyle(.borderless)
                .padding(.vertical, Spacing.rowVertical)
                .padding(.horizontal, Spacing.rowHorizontal)
                .accessibilityLabel("Remove authenticator")
            }

            if draft.totp == nil {
                Button {
                    draft.totp = ""
                } label: {
                    Label("Add Authenticator (TOTP)", systemImage: "plus")
                        .font(Typography.fieldValue)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add authenticator")
            }
        }
    }
}

private struct TOTPSecretEditView: View {
    @Binding var configuration: String
    let generator: any TOTPCodeGenerating

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.fieldContentGap) {
            Text("Authenticator Key")
                .font(Typography.fieldLabel)
                .foregroundStyle(.secondary)

            HStack(spacing: Spacing.fieldActionGap) {
                TextField("Base32 key or otpauth URI", text: $configuration)
                    .font(Typography.fieldValue.monospaced())
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .foregroundStyle(isFieldFocused ? Color.primary : Color.clear)
                    .overlay(alignment: .leading) {
                        if !isFieldFocused, !configuration.isEmpty {
                            Text(MaskedFieldState.maskedPlaceholder)
                                .font(Typography.fieldValue.monospaced())
                                .foregroundStyle(.primary)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel("Authenticator key")
                    .accessibilityValue(isFieldFocused ? configuration : "Hidden")

                Button {
                    isFieldFocused.toggle()
                } label: {
                    Image(systemName: isFieldFocused ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .help(isFieldFocused ? "Hide" : "Edit")
                .accessibilityLabel(isFieldFocused ? "Hide authenticator key" : "Edit authenticator key")
            }

            if !configuration.isEmpty {
                TOTPCodeView(
                    configuration: configuration,
                    generator: generator,
                    showsErrors: true
                )
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
    }
}

struct TOTPCodeView: View {
    let configuration: String
    let generator: any TOTPCodeGenerating
    var showsErrors = false
    var onCopy: ((String) -> Void)? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            switch displayState(at: context.date) {
            case .code(let code):
                HStack(spacing: Spacing.fieldActionGap) {
                    VStack(alignment: .leading, spacing: Spacing.fieldContentGap) {
                        Text("One-Time Password")
                            .font(Typography.fieldLabel)
                            .foregroundStyle(.secondary)
                        Text(formatted(code.value))
                            .font(Typography.fieldValue.monospaced())
                            .textSelection(.enabled)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("One-time password \(code.value)")

                    Spacer()

                    Gauge(
                        value: Double(code.period - code.secondsRemaining),
                        in: 0...Double(code.period)
                    ) {
                        Text("Time remaining")
                    } currentValueLabel: {
                        Text("\(code.secondsRemaining)")
                            .font(Typography.utility)
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .controlSize(.small)
                    .accessibilityLabel("Time remaining")
                    .accessibilityValue("\(code.secondsRemaining) seconds")

                    if let onCopy {
                        Button {
                            onCopy(code.value)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(Typography.utility.weight(.semibold))
                                .textCase(.uppercase)
                        }
                        .buttonStyle(.borderless)
                        .help("Copy one-time password")
                        .accessibilityLabel("Copy one-time password")
                    }
                }
            case .error(let message):
                if showsErrors {
                    Text(message)
                        .font(Typography.utility)
                        .foregroundStyle(.red)
                        .accessibilityLabel(message)
                }
            }
        }
    }

    private func displayState(at date: Date) -> DisplayState {
        do {
            return .code(try generator.generateCode(from: configuration, at: date))
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func formatted(_ code: String) -> String {
        let midpoint = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[..<midpoint]) \(code[midpoint...])"
    }

    private enum DisplayState {
        case code(TOTPCode)
        case error(String)
    }
}

// MARK: - URIEditRow

/// An editable row for a single LoginURI, with match-type picker, reorder, and remove controls.
private struct URIEditRow: View {

    @Binding var uri: DraftLoginURI
    let canMoveUp: Bool
    let canMoveDown: Bool
    let showReorderButtons: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    @State private var showMatchType = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if showReorderButtons {
                    VStack(spacing: 2) {
                        Button(action: onMoveUp) {
                            Image(systemName: "chevron.up")
                                .font(Typography.utility)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Move up")
                        .disabled(!canMoveUp)

                        Button(action: onMoveDown) {
                            Image(systemName: "chevron.down")
                                .font(Typography.utility)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Move down")
                        .disabled(!canMoveDown)
                    }
                    .padding(.leading, Spacing.rowHorizontal)
                }

                EditFieldRow(label: "Website", text: $uri.uri)

                Button {
                    optionalAnimation(.easeInOut(duration: 0.2)) {
                        showMatchType.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(showMatchType ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Match type settings")

                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove website")
                .padding(.trailing, Spacing.rowHorizontal)
            }
            if showMatchType {
                Divider()
                HStack {
                    Text("Match Type")
                        .font(Typography.fieldLabel)
                        .foregroundStyle(.secondary)
                        .padding(.leading, Spacing.rowHorizontal)
                    Spacer()
                    Picker("Match Type", selection: $uri.matchType) {
                        Text("Default").tag(URIMatchType?.none)
                        ForEach(URIMatchType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(URIMatchType?.some(type))
                        }
                    }
                    .labelsHidden()
                    .padding(.trailing, Spacing.rowHorizontal)
                }
                .padding(.vertical, Spacing.rowVertical)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - URIMatchType + Helpers

private extension URIMatchType {
    static var allCases: [URIMatchType] {
        [.domain, .host, .startsWith, .exact, .regularExpression, .never]
    }

    var displayName: String {
        switch self {
        case .domain:            return "Domain"
        case .host:              return "Host"
        case .startsWith:        return "Starts With"
        case .exact:             return "Exact"
        case .regularExpression: return "Regular Expression"
        case .never:             return "Never"
        }
    }
}
