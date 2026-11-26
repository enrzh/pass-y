# Architecture

- [Overview](#overview)
  - [Password Manager App Targets](#password-manager-app-targets)
  - [Authenticator App Targets](#authenticator-app-targets)
  - [Shared Frameworks](#shared-frameworks)
  - [Test Helpers](#test-helpers)
  - [Architecture Structure](#architecture-structure)
- [Core Layer](#core-layer)
  - [Models](#models)
  - [Data Stores](#data-stores)
  - [Services](#services)
  - [Repositories](#repositories)
  - [Dependency Injection](#dependency-injection)
- [UI Layer](#ui-layer)
  - [Module](#module)
  - [Coordinator](#coordinator)
  - [Routes and Events](#routes-and-events)
  - [Processor](#processor)
  - [State](#state)
  - [View](#view)
  - [Actions and Effects](#actions-and-effects)
  - [Example](#example)
- [Test Architecture](#test-architecture)
  - [Testing Philosophy](#testing-philosophy)
  - [Test Layer Alignment](#test-layer-alignment)
  - [Testing Strategies by Component Type](#testing-strategies-by-component-type)
  - [Test Organization](#test-organization)
  - [Dependency Mocking](#dependency-mocking)
  - [Test Isolation](#test-isolation)

## Overview

The iOS repository contains two main apps: Bitwarden Password Manager and Bitwarden Authenticator.

### Password Manager App Targets

- `Bitwarden`: The main iOS Password Manager app.
- `BitwardenActionExtension`: An [Action extension](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Action.html) that can be accessed via the system share sheet "Autofill with Bitwarden" option.
- `BitwardenAutoFillExtension`: An AutoFill Credential Provider extension which allows Bitwarden to offer up credentials for [Password AutoFill](https://developer.apple.com/documentation/security/password_autofill/).
- `BitwardenNotificationExtension`: A [UNNotificationServiceExtension](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension) that is used to update the content of push notifications.
- `BitwardenShareExtension`: A [Share extension](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html) that allows creating text or file sends via the system share sheet.
- `BitwardenShared`: The main Password Manager framework containing the Core and UI layers shared between the app and extensions.

### Authenticator App Targets

- `Authenticator`: The main iOS Authenticator app.
- `AuthenticatorShared`: The main Authenticator framework containing the Core and UI layers.

### Shared Frameworks

- `BitwardenKit`: A shared framework providing common functionality across apps.
- `BitwardenResources`: A framework containing shared resources (assets, localizations, etc.).
- `AuthenticatorBridgeKit`: A framework for communication between the Password Manager and Authenticator apps.
- `Networking`: A local Swift package that implements the app's networking layer on top of `URLSession`.

### Test Helpers

- `GlobalTestHelpers`: Shared functionality between the app's test targets.
- `BitwardenKitMocks`: Mock implementations for BitwardenKit components.
- `AuthenticatorBridgeKitMocks`: Mock implementations for AuthenticatorBridgeKit components.
- `TestHelpers`: Additional test utilities and helpers.
- `ViewInspectorTestHelpers`: ViewInspector-specific test helpers for UI testing.

### Architecture Structure

Most of the app's functionality is implemented in the `BitwardenShared` and `AuthenticatorShared` frameworks. The files within these frameworks are mainly split up between two top-level folders, `Core` and `UI`. Each of these folders is then subdivided into the following folders:

- `Auth`
- `Autofill`
- `Billing`
- `Platform`
- `Tools`
- `Vault`

These folders follow the upstream Bitwarden team layout (Pass-Y has no CODEOWNERS file). One **MUST** not add additional direct subfolders to `Core` or `UI`. While this top-level structure is deliberately inflexible, the folder structure within the subfolders are not specifically prescribed.

The responsibilities of the core layer are to manage the storage and retrieval of data from low-level sources (such as from the network, persistence, or Bitwarden SDK) and to expose them in a more ready-to-consume manner by the UI layer via "repository" and "service" classes. The UI layer is then responsible for any final processing of this data for display in the UI as well as receiving events from the UI and updating the tracked state accordingly.

## Core Layer

The core layer is where all the UI-independent data is stored and retrieved. It consists of both raw data sources as well as higher-level "repository" and "service" classes. 

### Models

The lowest level of the core layer are the data model objects. These are the raw sources of data that include data retrieved or sent via network requests, data persisted with [CoreData](https://developer.apple.com/documentation/coredata/), and data that is used to interact with the [Bitwarden SDK](https://github.com/bitwarden/sdk-internal).

The models are roughly organized based on their use and type:

- `Domain`: Models that represent the main data types within the app.
- `Enum`: Enumeration model types.
- `Request`: Request models are data models used in the body of an API request.
- `Response`: Response models are typically the top-level data models that are decoded from an API response. These models may utilize domain and enum models that are shared between responses.

### Data Stores

Data stores are responsible for persisting data to Core Data, Keychain, and UserDefaults. This is implemented by the following:

- [AppSettingStore](../BitwardenShared/Core/Platform/Services/Stores/AppSettingsStore.swift): UserDefaults persistence.
- [DataStore](../BitwardenShared/Core/Platform/Services/Stores/DataStore.swift): CoreData persistence.
- [KeychainRepository](../BitwardenShared/Core/Auth/Services/KeychainRepository.swift): Keychain persistence.

### Services

Services represent the middle layer of the core layer. While some services may depend on other services or lower-level data stores (e.g. [CipherService](../BitwardenShared/Core/Vault/Services/CipherService.swift)), others are wrappers around OS-level functionality (e.g. [NFCReaderService](../BitwardenShared/Core/Platform/Services/NFCReaderService.swift)). The commonality amongst the services is that they tend to have a single discrete responsibility. These classes may exist solely in the core layer for use inside a repository or another service, like [CipherService](../BitwardenShared/Core/Vault/Services/CipherService.swift), or may be exposed directly to the UI layer, like [NFCReaderService](../BitwardenShared/Core/Platform/Services/NFCReaderService.swift).

### Repositories

Repositories are at the outermost layer of the core layer. Repositories are usually composed of one or more services, and in rare cases other repositories. Repositories are meant to be exposed directly to the UI layer. They synthesize data from multiple sources and combine various asynchronous requests as necessary to expose data to the UI layer in a more appropriate form. These classes tend to have broad responsibilities that generally cover a major domain of the app, such as authentication ([AuthRepository](../BitwardenShared/Core/Auth/Repositories/AuthRepository.swift)) or vault access ([VaultRepository](../BitwardenShared/Core/Vault/Repositories/VaultRepository.swift)).

### Dependency Injection

All services are contained within the [ServiceContainer](../BitwardenShared/Core/Platform/Services/ServiceContainer.swift). This allows services to be passed around the app and injected into the UI layer with minimal changes when a new dependency is added.

To make it clearer which coordinators and processors are using which dependencies, there is a [Services](../BitwardenShared/Core/Platform/Services/Services.swift) typealias that the `ServiceContainer` conforms to. This typealias uses protocol composition to declare the list of dependencies in the `ServiceContainer` that may be used in the UI layer. These protocols use a naming pattern of `Has<Service>`. The `Services` typealias only needs to contain the dependencies that need to be accessed outside of the data layer (e.g. A store may only need to be accessed by services or repositories in the core layer and wouldn't need to be exposed to the UI layer in the `Services` typealias. It would still be contained within the service container and injected directly into services or repositories at initialization.).

 Components in the UI layer can declare a similar `Services` typealias containing the list of dependencies that need to be injected into the component. This allows a single service container instance to be passed around the UI layer but limits components to accessing the predefined list of dependencies. 

The following example shows a `Services` typealias using protocol composition that the `ServiceContainer` conforms to. The types that are used within `Services` and `ServiceContainer` (e.g. `ExampleRepository`, `ExampleStore`, and `ExampleService`) should be protocols so they can be mocked for testing.

<details>
<summary>Show example</summary>

```swift
typealias Services = HasExampleRepository
    & HasExampleService

protocol HasExampleRepository {
    var exampleRepository: ExampleRepository { get }
}

protocol HasExampleService {
    var exampleService: ExampleService { get }
}

final class ServiceContainer: Services {
    let exampleService: ExampleService
    let exampleStore: ExampleStore
    let exampleRepository: ExampleRepository
}

final class ExampleCoordinator: Coordinator {
    typealias Services = HasExampleRepository
    
    private let services: Services
    
    init(services: Services) {
        self.services = services
    }
}
```

</details>

## UI Layer

The UI layer utilizes a unidirectional data flow pattern that is based on coordinators and processors.

### Module

Modules are used to build coordinators.

Each coordinator that can navigate to child coordinators will use its module to instantiate the child coordinator. A coordinator will have a module protocol that defines the child coordinators that could be built by that coordinator. The module protocols are implemented by the [DefaultAppModule](../BitwardenShared/UI/Platform/Application/AppModule.swift). The coordinator's module can be mocked during testing to test child coordinator creation.

 The [DefaultAppModule](../BitwardenShared/UI/Platform/Application/AppModule.swift) provides a single entry point for creating all coordinators in the application. This allows the services in the service container to be injected into new coordinators without requiring the services to be passed throughout the coordinator hierarchy.

### Coordinator

Coordinators create processors and views to facilitate navigation between views or flows within the application. In general, a coordinator is responsible for managing navigation within a single container view controller (e.g. `UINavigationController`, `UITabBarController`).

Occasionally, a single coordinator can manage the navigation within an entire feature flow (e.g. [AuthCoordinator](../BitwardenShared/UI/Auth/AuthCoordinator.swift) handles the navigation between authentication views). Once a flow becomes complex enough, or the container view controller changes (e.g. a `UINavigationController` is presented which has its own set of flows), the coordinator can create and display a child coordinator. An example of this is how [VaultCoordinator](../BitwardenShared/UI/Vault/Vault/VaultCoordinator.swift) handles navigation within the vault tab and [VaultItemCoordinator](../BitwardenShared/UI/Vault/VaultItem/VaultItemCoordinator.swift) handles navigation for viewing, adding, or editing vault items in a presented `UINavigationController`.

Coordinators should remain free of business logic. Logic should be handled in the processor prior to navigation or in the new processor after navigation occurs. In rare cases where there is a lot of logic around what view should come next, a router can be implemented to work alongside the coordinator. An example of this is [AuthRouter](../BitwardenShared/UI/Auth/AuthRouter.swift), which makes decisions around which route should be navigated to next within the authentication flow.

### Routes and Events

Coordinators operate on a set of routes and, optionally, events.

Routes are implemented as an enumeration and define the set of screens that the coordinator can navigate to. Most routes will correspond to a specific view in the app, but routes can also be a more generic action that that coordinator needs to take (e.g. dismissing a presented coordinator flow when the flow completes).

Events define a set of actions that occur in a processor that requires navigation, but without the processor prescribing the specific screen that the coordinator navigates to. These will commonly be used in combination with a router and allows the router to determine the next screen that should be shown before any navigation occurs. Some examples of events are app startup (which screen should be shown first?), switching accounts (does the vault need to be unlocked first?), and logout (are there other accounts to switch to after logout?). Events are also implemented as an enumeration.

### Processor

Processors manage the state and business logic for a view. Processors are the only location where state mutation occurs. Processors receive actions and effects from the view, performs any business logic and then updates the state. Whenever a processor updates its state, it automatically publishes the new state to the view.

If a change in state necessitates a navigation change, the processor requests that its coordinator handle the navigation to a new view.

### State

State represents the data and configuration needed to perform the processor's logic and render the UI for a feature. All information needed to configure the UI associated with the processor should be included in the state.

### View

A view renders the UI based on its state. The state within a view is managed by a [Store](../BitwardenKit/UI/Platform/Application/Utilities/Store.swift). The store is the connection between the processor and the view. Views never mutate state directly; instead, they send actions or perform effects via the store which are forwarded back to the processor. Views are updated by the store anytime the state changes.

#### Pass-Y list pages

The vault home, group pages, search results, Send and folders share one construction from the design system (below):
`passYCardList()` (inset-grouped cards; room and a soft scroll edge for the floating bottom bar),
`passYEmptyListState()` (the empty message over an empty list, on the grouped page colour), `passYGroupedBackground()`
(native forms), in [PassYCardList.swift](../BitwardenShared/UI/Platform/Application/Views/PassYDesign/PassYCardList.swift);
the vault-only parts are in [View+PassYVaultList.swift](../BitwardenShared/UI/Vault/Views/View+PassYVaultList.swift):
`passYVaultRow` (row insets and the
Delete / More swipe actions), `passYSelectEditMode` and `PassYSelectModeButtons` (Select mode). Row options are native
menus (`VaultItemOptionsMenuContent`), shared by the context menu and the More swipe action. The minimum is iOS 26: the
UI and app layers have no `#available` checks or fallbacks for earlier versions (left: the Core layer, the 26.2 / 27
checks, `ReviewModifier` and a multi-platform test).

#### Design system (PassYDesign)

**Rule: new and reworked UI uses PassYDesign and SwiftUI/system elements only** (`List`, `Section`, `Form`,
`LabeledContent`, `Menu`, `ContentUnavailableView`, system button styles), never the Bitwarden UI kit
(`ContentBlock`, `SectionView`, `BitwardenTextField`/`Toggle`/`MenuField`, `IllustratedMessageView`, `LoadingView`,
`AsyncButton`, `.styleGuide`, `SharedAsset` colours and icons, `.primary`/`.secondary` button styles, custom
row/divider/card views). Text uses Dynamic Type text styles only; shapes use continuous corners. One file per
component, each with a `#Preview`, in
[PassYDesign/](../BitwardenShared/UI/Platform/Application/Views/PassYDesign):

| Component | Purpose |
|---|---|
| `PassYDesign` | Tokens: radii, 4 pt spacing scale, icon tile sizes (28/40/56, scaled up to 1.6x), row measures (56 pt minimum), text roles (`passYFont(.rowTitle)` ...). |
| `PassYIconTile` | Rounded-square tile: tinted SF Symbol, tinted first letter (stable colour per name, `PassYTilePalette`) or a web icon on a neutral tile. |
| `PassYRow` | The one list row: tile, title, up to two subtitles, inline badges, trailing accessory, chevron; `passYRowButton` (press highlight, hover, identifier on the button), `passYRowContextMenu`, `passYRowSwipeActions`. Works in a `List` and in stacks (`divider:`). |
| `PassYCardList` | `passYCardList()`, `PassYCardSection`, `passYEmptyListState()`, `passYGroupedBackground()`, separator alignment. |
| `PassYSectionHeader` | Section title, count, optional collapse chevron (one toggle button). |
| `PassYEmptyState` | `ContentUnavailableView` with symbol, title, description and actions. |
| `PassYBadge` | Quiet SF Symbol status mark or tinted text capsule. |
| `PassYButtonStyles` | `passYButtonStyle(.primary / .secondary / .destructive)` on the system glass styles. |
| `PassYCodeRow` | Verification code row: large two-group code, `PassYCountdownRing`, accessibility-size layout; `PassYOneTimeCode` (grouping, spoken digits, label). |
| `PassYCountdown` | Countdown maths and tone (orange at 5 s, red at 2 s), `PassYCountdownClock` (one 1 Hz clock per page via `passYCountdownClock`), `PassYCountdownRing`. |
| `PassYSettingsRow` | The settings row (iOS Settings style): small tinted symbol tile, title, value, red count badge, accessory (disclosure, external, checkmark, none), destructive role; one button with the system row highlight, value under the title at accessibility sizes. `PassYSettingsRowLabel` is the same content for `Picker`/`Menu` labels. Navigation stays with the coordinators (the row sends the processor action). |
| `PassYToggleRow` | Settings switch: optional tile, title, explanation, system `Toggle` (identifier on the toggle). |
| `PassYValueRow` | Read-only `LabeledContent` row (optional tile, selectable value). |
| `PassYFooterText` | Section footer text with an optional inline link button ("Learn more"). |
| `PassYSetupSection` | "Set up" prompt as a `Form` section: headline tile and text, action, secondary and dismiss rows. |
| `PassYHeroHeader` | Centred header of auth and one-off pages: `PassYShieldMark` (the Pass-Y shield drawn on the logo grid) or an SF Symbol, title, message; `passYPlainListRow()` puts it on the page background. |
| `PassYActionStack` | Borderless `Form` section for the page actions: one primary button, secondary/plain buttons below. |
| `PassYPasswordField` | Password/PIN field: `SecureField` swapped for a `TextField` while revealed, eye button, no autocorrection; caller adds focus, submit label and content type. |
| `PassYFingerprintPhrase` | Fingerprint phrase row (caption, monospaced pink phrase, selectable). |
| `PassYLoadingContent` | Shows a `LoadingState`: data, error (`PassYEmptyState`) or a delayed system spinner (`PassYDelayedSpinner`). |

Settings (main page and sub-pages) and the auth pages (landing, login, unlock, two-step login, device login, SSO
decryption options, registration and master password pages, login requests) are built from these components: settings
pages are grouped `Form`s of `PassYSettingsRow` / `PassYToggleRow` / `Picker` rows with `PassYFooterText` footers,
auth pages a `PassYHeroHeader`, system fields and one primary action in a `PassYActionStack`.
| `PassYFormField` | Edit-form text row: label left, value right (stacked at accessibility sizes) or `.free` (title as placeholder, the item name); trailing buttons; `PassYTextBuffer` keeps typing apart from store echoes (AutoFill); `PassYFieldFocus` for focus. |
| `PassYSecureField` | Edit-form secret: `SecureField`, eye button (`PassYRevealButton`) swaps to a plain monospaced field with the same identifier, keeps focus. |
| `PassYMultilineField` | Notes, Send text: `TextEditor` (a text view for UI tests) with the title as placeholder. |
| `PassYCopyRow` | Detail row: label + value, tap copies (success haptic; the page shows the toast), long press Copy / Reveal / extras, eye button for secrets, `.stacked` for long values; `PassYValueText` (mask, tinted digits/symbols). |
| `PassYToggleRow`, `PassYPickerRow`, `PassYStepperRow`, `PassYSliderRow`, `PassYDateRow` | System `Toggle` (+ help link), menu choice (tint value, checkmark, extra actions such as Add folder), `Stepper` (optional number field), `Slider` with value, optional calendar day (Add / compact `DatePicker` / clear). |
| `PassYInlineButtonRow`, `PassYDisclosureSection`, `PassYSectionFooter` | Form action row (tinted / plain / destructive, sync or async), "Additional options" disclosure, footnote footer with optional link. |
| `PassYCodeExpiry`, `PassYFieldNavigation`, `passYReadableWidth` | One-time code ring on the page clock that reports the period end; Return/keyboard-bar previous/next order; safe-area side insets that keep cards at 680 pt on wide pages. |

Item view/edit, Send add/edit/view, attachments, collections, move, folders, the generator and the password history
are built from the form components above (no Bitwarden field, toggle, menu, section or card views).

Vault rows adapt their items onto these components in `VaultListItemRowView` (equatable `VaultListRowCell` stays
the performance boundary) and `VaultItemIconTile`; Send and folder rows use `PassYRow` directly.

#### Customize (on-device layout preferences)

[Customize/](../BitwardenShared/UI/Platform/Customize) holds the user's layout choices of this device:
`PassYLayoutPreferences` (Codable, `version` 2, lenient field-by-field decoding; home elements keyed by
`passYHomeElementId`: the type tiles' `VaultListGroup.tileIdentifier`, `folder:<id>`, `noFolder`; sections by vault list
section id; no vault data but folder ids) stored in `AppSettingsStore` (`passYLayoutPreferences`, app group defaults,
never synced). The defaults are "no override", so they draw today's look. `PassYLayoutStore` (`@Observable`, `shared`)
exposes three slices (home, rows, codes) that invalidate independently. Every page is its own hosting controller, so
list pages apply them with `passYLayoutEnvironment()` (vault home, group pages, their search results); rows read only
small environment values: `passYRowOptions` (`PassYRow`, `PassYCodeRow`: subtitle, icon), `passYBadgeOptions` (vault
row badges), `passYCodeOptions` (digit grouping; countdown ring / seconds stay in the model for the code rows but have
no switch since version 2); the home slice is part of the home's `EquatableContent` key. Nothing disappears from the
home: every element is a card or a folder row (`tileRows`: type tiles shown as rows, `folderCards`: folders shown as
cards). `PassYHomeArrangement` builds the cards (types and folder cards in the user's order), a "Types" section
(`PassYTypes`) for the type rows, the folder rows without the folder cards and a "More" section only for the rows of
hidden Types / Folders / Shared folders sections; unknown folder ids are ignored. Cards are drawn by `CategoryTilesView`
in "Bunt" (tinted symbol tile) or "Vollfarbig" (`filledCardColor`, white content at 4.5:1 or more, unit-tested). A card is a
`Menu` with a primary action: a tap opens it, a long press opens its native menu from the card (move to front /
earlier / later / to end, Show as Folder Row, Customize…); a `contextMenu` per card does not work because all cards
share one list row and a list row has one context menu. Type and folder rows have a context menu with Show as Card and
Customize… (group rows have no inner row menu). Sections marked
"collapsed when opened" are added to the persisted chevron state when the home stream starts. `CustomizeView` (plain
grouped `List`, live preview, card switches for every type and top-level folder with `onMove` in `EditMode`, Reset;
folders read through `PassYCustomizeFolders` while the screen is shown) is pushed in the Settings stack from Settings
(its own first section) and from the home menus ("Customize…"); its website icons switch is the existing
`StateService` setting. DEBUG only: `-PassYLayoutPreset default|filled|rows|minimal` seeds a configuration for
screenshots.

#### Pass-Y diagnostics (DEBUG only)

Signposts, counters and startup / navigation marks (`PassYPerf`, `PassYNavigationProbe`) and the XCUITest idle-stall
dump (`PassYAnimationDump`, `PassYAnimationTracker`) live in
[BitwardenKit/UI/Platform/Application/Diagnostics](../BitwardenKit/UI/Platform/Application/Diagnostics). Every file and
every call site is inside `#if DEBUG`, so a Release build contains none of their symbols or strings
(`PassYAppHygieneTests.test_diagnostics_onlyInDebug`).

### Actions and Effects

Actions are triggered by the view and represent interactions with the processor that could potentially cause an update to state or navigation. These will usually be sent because of some user interaction with the UI, such as a button being tapped or a text field's value changing. Actions are processed synchronously by the processor.

Effects are like actions, but usually represent side-effects where the processor needs to communicate with an external repository or service. Effects are asynchronous and may perform some work before updating the state, examples which include loading or subscribing to data for the view or making API requests. Long-running tasks such as subscribing to an [AsyncPublisher](https://developer.apple.com/documentation/combine/asyncpublisher) should use the [task](https://developer.apple.com/documentation/swiftui/view/task(priority:_:)) modifier on the view so that the task is cancelled if the view disappears before the task completes.

Actions and effects are implemented as enumerations so that adding a new action or effect ensures the processor is updated to handle the new case.

### Example

The following example demonstrates the above components in the architecture.

- The coordinator creates the processor and view and handles navigation within its navigator (in this case a [StackNavigator](../BitwardenKit/Core/Platform/Utilities/StackNavigator.swift) which is implemented by a `UINavigationController`).
- The processor and view share:
    - State containing the properties that are used to configure the UI: `data` and `isToggleOn`.
    - Actions that are used by the processor to update the state (`updateToggle`) or trigger navigation (`nextExample`).
    - Effects that perform asynchronous work: `loadData` fetches some data to display from the repository.
- The view builds the UI based on the current state in the store and notifies the processor via actions or effects as interactions occur.
- The processor responds to actions by updating the state or triggering navigation via the coordinator. Effects are used to kick off asynchronous work.

<details>
<summary>Show example</summary>

```swift
enum ExampleRoute {
    case example
    case nextExample
}

final class ExampleCoordinator: Coordinator, HasStackNavigator {
    typealias Event = Void
    typealias Services = HasExampleRepository

    private let services: Services
    private(set) weak var stackNavigator: StackNavigator?

    init(services: Services, stackNavigator: StackNavigator?) {
        self.services = services
        self.stackNavigator = stackNavigator
    }

    func start() {}

    func navigate(to route: ExampleRoute, context: AnyObject?) {
        switch route {
        case .example:
            showExample()
        case .nextExample:
            // ...
        }
    }

    private func showExample() {
        let processor = ExampleProcessor(
            coordinator: asAnyCoordinator(),
            services: services,
            state: ExampleState()
        )
        let view = ExampleView(store: Store(processor: processor))
        stackNavigator?.push(view)
    }
}

struct ExampleState: Equatable {
    var data: String?
    var isToggleOn = false
}

enum ExampleAction: Equatable {
    case nextExample
    case updateToggle(Bool)
}

enum ExampleEffect: Equatable {
    case loadData
}

final class ExampleProcessor: StateProcessor<ExampleState, ExampleAction, ExampleEffect> {
    typealias Services = HasExampleRepository

    private var coordinator: any Coordinator<ExampleRoute, Void>
    private var services: Services

    init(coordinator: any Coordinator<ExampleRoute, Void>, services: Services, state: ExampleState) {
        self.coordinator = coordinator
        self.services = services
        super.init(state: state)
    }

    override func receive(_ action: ExampleAction) {
        switch action {
        case .nextExample:
            coordinator.navigate(to: .nextExample)
        case let .updateToggle(newValue):
            state.isToggleOn = newValue
        }
    }

    override func perform(_ effect: ExampleEffect) async {
        switch effect {
        case .loadData:
            await loadData()
        }
    }

    private func loadData() async {
        do {
            state.data = try await services.exampleRepository.loadData()
        } catch {
            // Handle errors.
        }
    }
}

struct ExampleView: View {
    @ObservedObject var store: Store<ExampleState, ExampleAction, ExampleEffect>

    var body: some View {
        VStack {
            if let data = store.state.data {
                Text(data)
            }

            Toggle(
                Localizations.toggleExample,
                isOn: store.binding(
                    get: \.isToggleOn,
                    send: ExampleAction.updateToggle
                )
            )

            Button(Localizations.next) {
                store.send(.nextExample)
            }
        }
        .task {
            await store.perform(.loadData)
        }
    }
}
```

</details>

## Test Architecture

### Testing Philosophy

The test architecture mirrors the layered structure of the application, ensuring that each layer can be tested in isolation through dependency injection and protocol-based abstractions.

### Test Layer Alignment

#### Core Layer Testing

Tests for the core layer focus on data integrity, business logic, and repository/service behavior:

- **Repositories**: Test data synthesis from multiple sources, error handling, and asynchronous operations
- **Services**: Test discrete responsibilities and interactions with lower-level stores
- **Data Stores**: Test persistence operations (CoreData, Keychain, UserDefaults)
- **Models**: Test data transformations, encoding/decoding, and domain logic

Core layer tests should use mocked dependencies to isolate the system under test from external services.

#### UI Layer Testing

Tests for the UI layer validate the unidirectional data flow and state management:

- **Processors**: Test state mutations in response to actions, effect handling, and coordinator navigation requests
- **Coordinators**: Test route handling and child coordinator creation using mocked modules
- **Views**: Test UI rendering based on state and user interaction handling
- **State**: Test state equality and state transformations

UI layer tests leverage the `Store` abstraction to verify the connection between processors and views.

### Testing Strategies by Component Type

The architecture employs three complementary testing strategies:

1. **Logic Testing**: Unit tests validate business logic, state management, and data transformations using protocol mocks
2. **Interaction Testing**: View inspector tests verify user interactions send correct actions/effects through the store
3. **Visual Testing**: Snapshot tests capture visual regressions across different display modes and accessibility settings

### Test Organization

Test files are co-located with the code they test, maintaining the same folder structure as the main codebase. This organization:

- Makes it easy to find tests for a given type
- Ensures tests evolve alongside the code
- Reinforces the architectural boundaries (see [Architecture Structure](#architecture-structure) for domain list)

### Dependency Mocking

The architecture's use of protocol composition in the `Services` typealias enables comprehensive mocking:

- All services and repositories are defined as protocols
- Mock implementations are generated using Sourcery's `AutoMockable` annotation
- Coordinators can be tested with mocked modules to verify navigation logic
- Processors can be tested with mocked services to verify state management

### Test Isolation

Each architectural layer can be tested independently:

- **Core layer** tests mock network responses, SDK interactions, and persistence layers
- **UI layer** tests mock repositories and services from the core layer
- **Integration points** between layers are tested by verifying protocol conformance

This isolation enables fast, reliable tests that pinpoint failures to specific architectural components.
