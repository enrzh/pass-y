import BitwardenKit
import BitwardenResources
import SwiftUI

/// A view containing the generator used to generate new usernames and passwords.
///
struct GeneratorView: View { // swiftlint:disable:this type_body_length
    // MARK: Properties

    /// The key path of the currently focused text field.
    @FocusState private var focusedFieldKeyPath: KeyPath<GeneratorState, String>?

    /// An action that opens URLs.
    @Environment(\.openURL) private var openURL

    /// The `Store` for this view.
    @ObservedObject var store: Store<GeneratorState, GeneratorAction, GeneratorEffect>

    var body: some View {
        Form {
            if selectableGeneratorTypes.count > 1 {
                Section {
                    // Native segmented control; types a policy disables are left out (the policy note says why).
                    Picker(
                        Localizations.generator,
                        selection: store.binding(get: \.generatorType, send: GeneratorAction.generatorTypeChanged),
                    ) {
                        ForEach(selectableGeneratorTypes) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("GeneratorTypePicker")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            if store.state.isPolicyInEffect {
                Section {
                    Label(Localizations.passwordGeneratorPolicyInEffect, systemImage: "info.circle")
                        .accessibilityIdentifier("PasswordGeneratorPolicyInEffectLabel")
                }
            }

            ForEach(store.state.formSections) { section in
                sectionView(section)
                if section.containsGeneratedValue {
                    actionSection
                }
            }
        }
        .listSectionSpacing(PassYDesign.Spacing.large)
        .contentMargins(.top, PassYDesign.Spacing.small, for: .scrollContent)
        .passYReadableWidth()
        .navigationTitle(Localizations.generator)
        .navigationBarTitleDisplayMode(store.state.presentationMode == .tab ? .large : .inline)
        .task { await store.perform(.appeared) }
        .onChange(of: focusedFieldKeyPath) { newValue in
            store.send(.textFieldFocusChanged(keyPath: newValue))
        }
        .toast(store.binding(
            get: \.toast,
            send: GeneratorAction.toastShown,
        ))
        .onChange(of: store.state.url) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearUrl)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if store.state.presentationMode.isDismissButtonVisible {
                    cancelToolbarButton {
                        store.send(.dismissPressed)
                    }
                }
            }

            if store.state.presentationMode == .tab {
                PassYAvatarToolbarItem()
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                if store.state.presentationMode.isOptionsButtonVisible {
                    optionsToolbarMenu {
                        Button(Localizations.passwordHistory) {
                            store.send(.showPasswordHistory)
                        }
                    }
                }
            }
        }
    }

    /// The generator types the user can choose (a policy can disable some).
    private var selectableGeneratorTypes: [GeneratorType] {
        store.state.availableGeneratorTypes.filter { !store.state.isGeneratorTypeDisabled($0) }
    }

    /// The page action below the generated value: "Use this ..." when presented in place, "New login" in the tab.
    /// It is its own borderless section, so the value card above keeps its shape.
    @ViewBuilder private var actionSection: some View {
        if store.state.presentationMode.isFillButtonVisible {
            PassYActionStack {
                Button {
                    store.send(.fillGeneratedValue)
                } label: {
                    Text(store.state.generatorType.fillButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .passYButtonStyle(.primary, fillsWidth: true)
                .accessibilityIdentifier("FillGeneratedValueButton")
            }
        }

        if store.state.presentationMode.isCreateLoginButtonVisible {
            PassYActionStack {
                Button {
                    Task { await store.perform(.createLoginPressed) }
                } label: {
                    Text(Localizations.createLogin)
                        .frame(maxWidth: .infinity)
                }
                .passYButtonStyle(.primary, fillsWidth: true)
                .disabled(!store.state.hasGeneratedValue)
                .accessibilityIdentifier("CreateLoginButton")
            }
        }
    }

    /// Returns a view for displaying a section of items in the form.
    ///
    /// - Parameter section: The section of items to display.
    ///
    @ViewBuilder
    func sectionView(_ section: GeneratorState.FormSection<GeneratorState>) -> some View {
        Section {
            ForEach(section.groups) { group in
                groupView(group)
            }
        } header: {
            if let title = section.title {
                Text(title)
            }
        }
    }

    /// Returns a view for displaying a group of items within a section of the form.
    ///
    /// - Parameter group: The group of items to display.
    ///
    func groupView(_ group: GeneratorState.FormSectionGroup<GeneratorState>) -> some View {
        ForEach(group.fields) { field in
            switch field.fieldType {
            case let .emailWebsite(website):
                emailWebsiteView(website: website)
            case let .generatedValue(generatedValueField):
                generatedValueView(field: generatedValueField)
            case let .menuEmailType(menuField):
                menuRow(menuField) { store.send(.emailTypeChanged($0)) }
            case let .menuUsernameForwardedEmailService(menuField):
                menuRow(menuField) { store.send(.usernameForwardedEmailServiceChanged($0)) }
            case let .menuUsernameGeneratorType(menuField):
                menuUsernameGeneratorTypeView(field: menuField)
            case let .slider(sliderField):
                PassYSliderRow(
                    sliderField.title,
                    value: Binding(
                        get: { sliderField.value },
                        set: { store.send(.sliderValueChanged(field: sliderField, value: $0)) },
                    ),
                    in: sliderField.range,
                    step: sliderField.step,
                    identifier: sliderField.sliderAccessibilityId,
                    valueIdentifier: sliderField.sliderValueAccessibilityId,
                ) { isEditing in
                    store.send(.sliderEditingChanged(field: sliderField, isEditing: isEditing))
                }
            case let .stepper(stepperField):
                PassYStepperRow(
                    stepperField.title,
                    value: Binding(
                        get: { stepperField.value },
                        set: { store.send(.stepperValueChanged(field: stepperField, value: $0)) },
                    ),
                    in: stepperField.range,
                    identifier: stepperField.accessibilityId,
                )
            case let .text(textField):
                textRow(textField)
            case let .toggle(toggleField):
                PassYToggleRow(
                    toggleField.title,
                    isOn: Binding(
                        get: { toggleField.isOn },
                        set: { store.send(.toggleValueChanged(field: toggleField, isOn: $0)) },
                    ),
                    identifier: toggleField.accessibilityId,
                    accessibilityLabel: toggleField.accessibilityLabel,
                )
                .disabled(toggleField.isDisabled)
            }
        }
    }

    /// A choice row of the generator form with its footer note.
    @ViewBuilder
    func menuRow<T: Menuable>(
        _ field: FormMenuField<GeneratorState, T>,
        action: @escaping (T) -> Void,
    ) -> some View {
        VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
            PassYPickerRow(
                field.title,
                options: field.options,
                selection: Binding(get: { field.selection }, set: action),
                identifier: field.accessibilityIdentifier,
            )
            if let footer = field.footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, PassYDesign.Spacing.xSmall)
            }
        }
    }

    /// A text row of the generator form (e-mail, domain, API key ...), masked when it is a secret.
    @ViewBuilder
    func textRow(_ field: FormTextField<GeneratorState>) -> some View {
        let text = Binding(
            get: { field.value },
            set: { store.send(.textValueChanged(field: field, value: $0)) },
        )
        Group {
            if let isPasswordVisible = field.isPasswordVisible {
                PassYSecureField(
                    field.title,
                    text: text,
                    isRevealed: Binding(
                        get: { isPasswordVisible },
                        set: { store.send(.textFieldIsPasswordVisibleChanged(field: field, value: $0)) },
                    ),
                    identifier: field.accessibilityId,
                    revealIdentifier: field.passwordVisibilityAccessibilityId,
                )
            } else {
                PassYFormField(field.title, text: text, identifier: field.accessibilityId)
            }
        }
        .keyboardType(field.keyboardType)
        .textContentType(field.textContentType)
        .textInputAutocapitalization(field.autocapitalization.textInputAutocapitalization)
        .autocorrectionDisabled(field.isAutocorrectDisabled)
        .focused($focusedFieldKeyPath, equals: field.keyPath)
    }

    /// Returns a view for displaying a static email website field.
    ///
    /// - Parameter website: The website to display in the field.
    ///
    @ViewBuilder
    func emailWebsiteView(website: String) -> some View {
        HStack {
            Text(Localizations.website)
            Spacer()
            Text(website).foregroundStyle(.secondary)
        }
    }

    /// Returns a view for displaying a generated value (the generated password, username or email).
    ///
    /// - Parameter field: The data for displaying the generated value field.
    ///
    @ViewBuilder
    func generatedValueView(field: GeneratorState.GeneratedValueField<GeneratorState>) -> some View {
        HStack(spacing: PassYDesign.Spacing.medium) {
            Text(PassYValueText.tinted(field.value))
                .font(.title3.monospaced())
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityLabel(field.value)
                .accessibilityIdentifier("GeneratedPasswordLabel")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { store.send(.copyGeneratedValue) }
            Button {
                store.send(.refreshGeneratedValue)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(store.state.generatorType.regenerateButtonAccessibilityLabel)
            .accessibilityIdentifier("RegenerateValueButton")

            Button {
                store.send(.copyGeneratedValue)
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(store.state.generatorType.copyButtonAccessibilityLabel)
            .accessibilityIdentifier("CopyValueIconButton")
        }
        .padding(.vertical, PassYDesign.Spacing.xSmall)
    }

    /// Returns a view for displaying a menu for selecting the username type
    ///
    /// - Parameter field: The data for displaying the menu field.
    ///
    func menuUsernameGeneratorTypeView(
        field: FormMenuField<GeneratorState, UsernameGeneratorType>,
    ) -> some View {
        HStack(spacing: PassYDesign.Spacing.small) {
            menuRow(field) { store.send(.usernameGeneratorTypeChanged($0)) }
            Button {
                openURL(ExternalLinksConstants.generatorUsernameTypes)
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Localizations.learnMore)
        }
    }
}

// MARK: - FormSection + generated value

private extension GeneratorState.FormSection where State == GeneratorState {
    /// Whether this is the section that shows the generated value.
    var containsGeneratedValue: Bool {
        groups.contains { group in
            group.fields.contains { field in
                if case .generatedValue = field.fieldType { return true }
                return false
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    NavigationView {
        GeneratorView(store: Store(processor: StateProcessor(state: GeneratorState())))
    }
}
#endif
