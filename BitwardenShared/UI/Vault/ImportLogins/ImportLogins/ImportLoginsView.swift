import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ImportLoginsView

/// A view that instructs the user how to import their logins from another password manager.
///
struct ImportLoginsView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ImportLoginsState, ImportLoginsAction, ImportLoginsEffect>

    /// The total number of instruction steps after the intro page. Used for displaying Step X of Y.
    private let totalSteps = 3

    // MARK: View

    var body: some View {
        Group {
            switch store.state.page {
            case .intro: intro()
            case .step1: step1()
            case .step2: step2()
            case .step3: step3()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: store.state.page)
        .navigationBar(title: Localizations.importLogins, titleDisplayMode: .inline)
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }
        }
        .task {
            await store.perform(.appeared)
        }
    }

    // MARK: Private

    /// The intro page view.
    @ViewBuilder
    private func intro() -> some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 52))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text(Localizations.giveYourVaultAHeadStart)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(Localizations.importLoginsDescriptionLong)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                VStack(spacing: 12) {
                    Button {
                        store.send(.getStarted)
                    } label: {
                        Text(Localizations.getStarted).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if store.state.shouldShowImportLoginsLater {
                        AsyncButton {
                            await store.perform(.importLoginsLater)
                        } label: {
                            Text(Localizations.importLoginsLater).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, 16)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .passYNativeFormBackground()
    }

    /// The step 1 page view.
    @ViewBuilder
    private func step1() -> some View {
        stepView(step: 1, title: Localizations.exportYourSavedLogins) {
            NumberedListRow(title: Localizations.onYourComputerLogInToYourCurrentBrowserOrPasswordManager)
            NumberedListRow(title: Localizations.exportYourPasswordsThisOptionIsUsuallyFoundInYourSettings)
            NumberedListRow(
                title: Localizations.saveTheExportedFileSomewhereOnYourComputerYouCanFindEasily,
                subtitle: Localizations.youllDeleteThisFileAfterImportIsComplete,
            )
        }
    }

    /// The step 2 page view.
    @ViewBuilder
    private func step2() -> some View {
        stepView(step: 2, title: Localizations.logInToBitwarden) {
            NumberedListRow(title: Localizations.onYourComputerOpenANewBrowserTabAndGoTo(store.state.webVaultHost))
            NumberedListRow(title: Localizations.logInToTheBitwardenWebApp)
        }
    }

    /// The step 3 page view.
    @ViewBuilder
    private func step3() -> some View {
        stepView(step: 3, title: Localizations.importLoginsToBitwarden) {
            NumberedListRow(title: Localizations.inTheBitwardenNavigationFindTheToolsOptionAndSelectImportData)
            NumberedListRow(title: Localizations.fillOutTheFormAndImportYourSavedPasswordFile)
            NumberedListRow(title: Localizations.selectImportDataInTheWebAppThenDoneToFinishSyncing)
            NumberedListRow(title: Localizations.forYourSecurityBeSureToDeleteYourSavedPasswordFile)
        }
    }

    /// Returns a form for displaying the instructions for a step.
    ///
    /// - Parameters:
    ///   - step: The step number of this page.
    ///   - title: The title of the step.
    ///   - list: A closure that returns the views to display in a numbered list.
    ///
    @ViewBuilder
    private func stepView(
        step: Int,
        title: String,
        @ViewBuilder list: () -> some View,
    ) -> some View {
        Form {
            Section {
                VStack(spacing: 4) {
                    Text(Localizations.stepXOfY(step, totalSteps))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }

            Section {
                NumberedList(content: list)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            } footer: {
                Text(LocalizedStringKey(
                    Localizations.needHelpCheckOutImportHelp(ExternalLinksConstants.importHelp),
                ))
                .tint(.accentColor)
                .accessibilityLinks(in: Localizations.needHelpCheckOutImportHelp(ExternalLinksConstants.importHelp))
            }

            Section {
                VStack(spacing: 12) {
                    AsyncButton {
                        await store.perform(.advanceNextPage)
                    } label: {
                        Text(step == totalSteps ? Localizations.done : Localizations.continue)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        store.send(.advancePreviousPage)
                    } label: {
                        Text(Localizations.back).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal, 16)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .passYNativeFormBackground()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Intro") {
    ImportLoginsView(store: Store(processor: StateProcessor(state: ImportLoginsState(mode: .vault))))
        .navStackWrapped
}

#Preview("Step 1") {
    ImportLoginsView(store: Store(processor: StateProcessor(state: ImportLoginsState(mode: .vault, page: .step1))))
        .navStackWrapped
}

#Preview("Step 2") {
    ImportLoginsView(store: Store(processor: StateProcessor(state: ImportLoginsState(mode: .vault, page: .step2))))
        .navStackWrapped
}

#Preview("Step 3") {
    ImportLoginsView(store: Store(processor: StateProcessor(state: ImportLoginsState(mode: .vault, page: .step3))))
        .navStackWrapped
}
#endif
