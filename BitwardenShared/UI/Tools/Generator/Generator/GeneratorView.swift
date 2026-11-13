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
            if store.state.availableGeneratorTypes.count > 1 {
                Section {
                    // Native segmented control (readable in dark mode); the custom control is only kept when a
                    // policy disables one of the types.
                    Group {
                    if store.state.availableGeneratorTypes.contains(where: { store.state.isGeneratorTypeDisabled($0) }) {
                        BitwardenSegmentedControl(
                            isSelectionDisabled: { store.state.isGeneratorTypeDisabled($0) },
                            selection: store.binding(get: \.generatorType, send: GeneratorAction.generatorTypeChanged),
                            selections: store.state.availableGeneratorTypes,
                        )
                    } else {
                        Picker(
                            Localizations.generator,
                            selection: store.binding(get: \.generatorType, send: GeneratorAction.generatorTypeChanged),
                        ) {
                            ForEach(store.state.availableGeneratorTypes) { type in
                                Text(type.localizedName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("GeneratorTypePicker")
                    }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
            }
        }
        .navigationBar(title: Localizations.generator, titleDisplayMode: .inline)
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

            largeNavigationTitleToolbarItem(
                Localizations.generator,
                hidden: store.state.presentationMode != .tab,
            )

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

    /// The full-width button that fills the generated value
    /// into the field the user came from, when presented in place.
    @ViewBuilder var fillButton: some View {
        Button(store.state.generatorType.fillButtonTitle) {
            store.send(.fillGeneratedValue)
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("FillGeneratedValueButton")
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
                FormMenuFieldView(field: menuField) { newValue in
                    store.send(.emailTypeChanged(newValue))
                }
            case let .menuUsernameForwardedEmailService(menuField):
                FormMenuFieldView(field: menuField) { newValue in
                    store.send(.usernameForwardedEmailServiceChanged(newValue))
                }
            case let .menuUsernameGeneratorType(menuField):
                menuUsernameGeneratorTypeView(field: menuField)
            case let .slider(sliderField):
                SliderFieldView(field: sliderField) { isEditing in
                    store.send(.sliderEditingChanged(field: sliderField, isEditing: isEditing))
                } onValueChanged: { newValue in
                    store.send(.sliderValueChanged(field: sliderField, value: newValue))
                }
            case let .stepper(stepperField):
                StepperFieldView(field: stepperField) { newValue in
                    store.send(.stepperValueChanged(field: stepperField, value: newValue))
                }
            case let .text(textField):
                FormTextFieldView(field: textField) { newValue in
                    store.send(.textValueChanged(field: textField, value: newValue))
                } isPasswordVisibleChangedAction: { newValue in
                    store.send(.textFieldIsPasswordVisibleChanged(field: textField, value: newValue))
                }
                .focused($focusedFieldKeyPath, equals: textField.keyPath)
            case let .toggle(toggleField):
                ToggleFieldView(field: toggleField) { isOn in
                    store.send(.toggleValueChanged(field: toggleField, isOn: isOn))
                }
            }
        }
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
        HStack(spacing: 12) {
            PasswordText(password: field.value, isPasswordVisible: true)
                .accessibilityIdentifier("GeneratedPasswordLabel")
                .textSelection(.enabled)
            Spacer(minLength: 0)
            Button {
                store.send(.refreshGeneratedValue)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel(store.state.generatorType.regenerateButtonAccessibilityLabel)
            .accessibilityIdentifier("RegenerateValueButton")

            Button {
                store.send(.copyGeneratedValue)
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel(store.state.generatorType.copyButtonAccessibilityLabel)
            .accessibilityIdentifier("CopyValueIconButton")
        }

        if store.state.presentationMode.isFillButtonVisible {
            fillButton
        }

        if store.state.presentationMode.isCreateLoginButtonVisible {
            AsyncButton(Localizations.createLogin) {
                await store.perform(.createLoginPressed)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(!store.state.hasGeneratedValue)
            .accessibilityIdentifier("CreateLoginButton")
        }
    }

    /// Returns a view for displaying a menu for selecting the username type
    ///
    /// - Parameter field: The data for displaying the menu field.
    ///
    func menuUsernameGeneratorTypeView(
        field: FormMenuField<GeneratorState, UsernameGeneratorType>,
    ) -> some View {
        FormMenuFieldView(field: field) { newValue in
            store.send(.usernameGeneratorTypeChanged(newValue))
        } titleAccessoryContent: {
            Button {
                openURL(ExternalLinksConstants.generatorUsernameTypes)
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.footnote)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Localizations.learnMore)
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
