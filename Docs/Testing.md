# Testing Guide

## Table of Contents

- [Testing Philosophy](#testing-philosophy)
- [Test File Naming and Location](#test-file-naming-and-location)
- [Decision Tree: What Tests to Write](#decision-tree-what-tests-to-write)
- [Testing Strategies](#testing-strategies)
- [Testing by Component Type](#testing-by-component-type)
  - [Testing Processors](#testing-processors)
  - [Testing Services](#testing-services)
  - [Testing Repositories](#testing-repositories)
  - [Testing Views](#testing-views)
  - [Testing Coordinators](#testing-coordinators)
- [Common Testing Patterns](#common-testing-patterns)
- [Mock Generation and Usage](#mock-generation-and-usage)
- [Running Tests](#running-tests)
  - [Test Plans](#test-plans)
  - [Running Tests from Command Line](#running-tests-from-command-line)
  - [Running Tests from Xcode](#running-tests-from-xcode)
  - [Simulator Configuration](#simulator-configuration)
  - [Recording New Snapshots](#recording-new-snapshots)
- [Test Maintenance](#test-maintenance)
  - [When to Update Tests](#when-to-update-tests)
  - [Test Smells to Avoid](#test-smells-to-avoid)
  - [Test Coverage Guidelines](#test-coverage-guidelines)
  - [Debugging Failing Tests](#debugging-failing-tests)
  - [Continuous Integration](#continuous-integration)
- [Quick Reference for AI Agents](#quick-reference-for-ai-agents)
  - [Decision Matrix: Test Type Selection](#decision-matrix-test-type-selection)
  - [Common Test Patterns Quick Reference](#common-test-patterns-quick-reference)
  - [Test Checklist for AI Agents](#test-checklist-for-ai-agents)
  - [Test Ordering Guidelines](#test-ordering-guidelines)

## Testing Philosophy

Every type containing logic **must** be tested. The test suite should:

1. Validate business logic and state management
2. Verify user interactions trigger correct behaviors
3. Catch visual regressions across display modes
4. Enable confident refactoring through comprehensive coverage

## Test File Naming and Location

### Naming Conventions

- **Unit tests**: `<TypeToTest>Tests.swift`
- **Snapshot tests**: `<TypeToTest>+SnapshotTests.swift`
- **View Inspector tests**: `<TypeToTest>+ViewInspectorTests.swift`

### File Location

Test files **must** be co-located with the implementation file in the same folder:

```
BitwardenShared/UI/Platform/Application/
├── AppProcessor.swift
├── AppProcessorTests.swift          # Unit tests
├── AppView.swift
├── AppView+SnapshotTests.swift      # Snapshot tests
└── AppView+ViewInspectorTests.swift # View inspector tests
```

This makes it easy to:
- Find tests for a specific type
- Open implementation and tests side-by-side
- Ensure tests evolve with the code

## Decision Tree: What Tests to Write

Use this decision tree to determine which tests to write for a new or modified component:

```
┌─────────────────────────────────────┐
│ What type of component is this?     │
└─────────────────────────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
┌───▼────┐  ┌────▼───┐  ┌─────▼──┐
│ Model  │  │ Logic  │  │  View  │
└───┬────┘  └───┬────┘  └────┬───┘

┌──────────────────────────────────────┐
│ Model (Domain/Request/Response)      │
│ ✓ Unit tests for:                    │
│   - Codable conformance              │
│   - Custom init logic                │
│   - Computed properties              │
│   - Validation methods               │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ Logic Component                      │
│ (Processor/Service/Repository/Store) │
│ ✓ Unit tests for:                    │
│   - All public methods               │
│   - State mutations                  │
│   - Error handling                   │
│   - Async operations                 │
│   - Edge cases                       │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ View (SwiftUI)                       │
│ ✓ ViewInspector tests for:           │
│   - Button taps send actions         │
│   - Toggle changes send actions      │
│   - TextField bindings work          │
│   - Navigation triggers              │
│ ✓ Snapshot tests for:                │
│   - Light mode                       │
│   - Dark mode                        │
│   - Large dynamic type               │
│   - Loading/error/empty states       │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ Coordinator                          │
│ ✓ Unit tests for:                    │
│   - Route navigation                 │
│   - Child coordinator creation       │
│   - Event handling                   │
│   - Context passing                  │
└──────────────────────────────────────┘
```

## Testing Strategies

### 1. Unit Tests (XCTest / Swift Testing)

**Purpose**: Validate business logic, state management, and data transformations

**Tools**:
- [XCTest](https://developer.apple.com/documentation/xctest) (legacy, still widely used)
- [Swift Testing Framework](https://developer.apple.com/xcode/swift-testing/) (preferred for new tests)

**Framework Selection**:
- **New test files**: Use Swift Testing (`import Testing`, `@Test`, `#expect`)
- **Existing XCTest files**: Keep as XCTest — do not mix frameworks in the same file
- **Fallback to XCTest**: When the test requires `BitwardenTestCase` subclassing, ViewInspector, SnapshotTesting, or other XCTest-only features

**Use for**:
- Processors (state mutations, action handling, effects)
- Services (business logic, data transformations)
- Repositories (data synthesis, error handling)
- Data Stores (persistence operations)
- Models (codable, computed properties, validation)
- Coordinators (navigation logic)

### 2. ViewInspector Tests

**Purpose**: Verify user interactions send correct actions/effects through the Store

**Tool**: [ViewInspector](https://github.com/nalexn/ViewInspector)

**Use for**:
- Button taps trigger actions
- Toggle changes send state updates
- TextField bindings work correctly
- Sheet/alert presentations
- Navigation link triggers

### 3. Snapshot Tests

**Purpose**: Catch visual regressions across different display modes

**Tool**: [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing)

**Use for**:
- All user-facing views
- Different states (loading, error, empty, populated)
- Accessibility configurations

**Required Snapshots**:
- ✅ Light mode
- ✅ Dark mode
- ✅ Large dynamic type (accessibility)

**Important**: Snapshot tests **must** run on the specific simulator defined in:
- Device: [.test-simulator-device-name](../.test-simulator-device-name)
- iOS Version: [.test-simulator-ios-version](../.test-simulator-ios-version)

Otherwise, tests will fail due to rendering differences between iOS versions.

## Testing by Component Type

### Testing Processors

Processors manage state and handle actions/effects. Focus on:

#### What to Test
- ✅ Initial state is correct
- ✅ Actions update state correctly
- ✅ Effects perform async work and update state
- ✅ Navigation requests are sent to coordinator
- ✅ Error handling updates state appropriately

#### Example Test Structure

```swift
@testable import BitwardenShared
import XCTest

class ExampleProcessorTests: BitwardenTestCase {
    var subject: ExampleProcessor!
    var coordinator: MockCoordinator<ExampleRoute, Void>!
    var exampleRepository: MockExampleRepository!

    override func setUp() {
        super.setUp()
        coordinator = MockCoordinator()
        exampleRepository = MockExampleRepository()

        subject = ExampleProcessor(
            coordinator: coordinator.asAnyCoordinator(),
            services: ServiceContainer.withMocks(
                exampleRepository: exampleRepository
            ),
            state: ExampleState()
        )
    }

    override func tearDown() {
        super.tearDown()
        subject = nil
        coordinator = nil
        exampleRepository = nil
    }

    // Test action handling
    func test_receive_toggleAction_updatesState() {
        subject.state.isToggleOn = false

        subject.receive(.toggleChanged(true))

        XCTAssertTrue(subject.state.isToggleOn)
    }

    // Test effect handling
    func test_perform_loadData_success_updatesState() async {
        exampleRepository.loadDataResult = .success("Test Data")

        await subject.perform(.loadData)

        XCTAssertEqual(subject.state.data, "Test Data")
        XCTAssertFalse(subject.state.isLoading)
    }

    // Test navigation
    func test_receive_nextAction_navigatesToNextScreen() {
        subject.receive(.next)

        XCTAssertEqual(coordinator.routes.last, .nextExample)
    }

    // Test error handling
    func test_perform_loadData_failure_showsError() async {
        exampleRepository.loadDataResult = .failure(BitwardenTestError.example)

        await subject.perform(.loadData)

        XCTAssertNotNil(subject.state.errorAlert)
    }
}
```

#### Swift Testing Example

```swift
import BitwardenKit
import BitwardenKitMocks
import Testing

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// MARK: - ExampleProcessorTests

@MainActor
struct ExampleProcessorTests {
    // MARK: Properties

    let coordinator: MockCoordinator<ExampleRoute, Void>
    let exampleRepository: MockExampleRepository
    let subject: ExampleProcessor

    // MARK: Initialization

    init() {
        coordinator = MockCoordinator()
        exampleRepository = MockExampleRepository()

        subject = ExampleProcessor(
            coordinator: coordinator.asAnyCoordinator(),
            services: ServiceContainer.withMocks(
                exampleRepository: exampleRepository,
            ),
            state: ExampleState(),
        )
    }

    // MARK: Tests

    /// `receive(.toggleChanged)` updates state with the new value.
    @Test
    func receive_toggleAction_updatesState() {
        subject.state.isToggleOn = false

        subject.receive(.toggleChanged(true))

        #expect(subject.state.isToggleOn == true)
    }

    /// `perform(.loadData)` loads data and updates state on success.
    @Test
    func perform_loadData_success_updatesState() async {
        exampleRepository.loadDataResult = .success("Test Data")

        await subject.perform(.loadData)

        #expect(subject.state.data == "Test Data")
        #expect(subject.state.isLoading == false)
    }

    /// `perform(.loadData)` shows an error alert when loading fails.
    @Test
    func perform_loadData_failure_showsError() async {
        exampleRepository.loadDataResult = .failure(BitwardenTestError.example)

        await subject.perform(.loadData)

        #expect(subject.state.errorAlert != nil)
    }
}
```

**Key differences from XCTest**:
- `struct` with `init()` instead of `class` with `setUp()`/`tearDown()` — no teardown needed, value types are discarded after each test
- `@Test` attribute instead of `test_` prefix on function names
- `#expect()` instead of `XCTAssert*()` — supports inline expressions with clear failure messages
- `#require()` instead of `XCTUnwrap()` — for force-unwrapping with test failure
- `@MainActor` on the struct rather than individual methods when all tests need it
- No `BitwardenTestCase` subclass — Swift Testing uses structs, not class inheritance

### Testing Services

Services have discrete responsibilities. Focus on:

#### What to Test
- ✅ All public method signatures
- ✅ Data transformations
- ✅ Error propagation
- ✅ Interaction with dependencies (use mocks)
- ✅ Edge cases and boundary conditions

#### Example Pattern

```swift
class ExampleServiceTests: BitwardenTestCase {
    var subject: DefaultExampleService!
    var dataStore: MockDataStore!
    var apiService: MockAPIService!

    override func setUp() {
        super.setUp()
        dataStore = MockDataStore()
        apiService = MockAPIService()
        subject = DefaultExampleService(
            dataStore: dataStore,
            apiService: apiService
        )
    }

    func test_fetchData_returnsMergedData() async throws {
        // Arrange
        dataStore.fetchResult = [/* local data */]
        apiService.fetchResult = .success(/* remote data */)

        // Act
        let result = try await subject.fetchData()

        // Assert
        XCTAssertEqual(result.count, expectedCount)
        XCTAssertTrue(dataStore.fetchCalled)
        XCTAssertTrue(apiService.fetchCalled)
    }
}
```

### Testing Repositories

Repositories synthesize data from multiple sources. Focus on:

#### What to Test
- ✅ Data synthesis from multiple services
- ✅ Async operation coordination
- ✅ Error handling from various sources
- ✅ Publisher streams emit correct values
- ✅ State synchronization

#### Example Pattern

```swift
class ExampleRepositoryTests: BitwardenTestCase {
    var subject: DefaultExampleRepository!
    var exampleService: MockExampleService!
    var otherService: MockOtherService!

    func test_loadData_combinesMultipleSources() async throws {
        exampleService.dataResult = .success(data1)
        otherService.dataResult = .success(data2)

        let result = try await subject.loadData()

        // Verify data was combined correctly
        XCTAssertEqual(result.combinedField, expectedValue)
    }
}
```

### Testing Views

Views render state and send actions. Focus on:

#### ViewInspector Tests: User Interactions

```swift
@testable import BitwardenShared
import ViewInspector
import XCTest

class ExampleViewTests: BitwardenTestCase {
    var processor: MockProcessor<ExampleState, ExampleAction, ExampleEffect>!
    var subject: ExampleView!

    override func setUp() {
        super.setUp()
        processor = MockProcessor(state: ExampleState())
        subject = ExampleView(store: Store(processor: processor))
    }

    // Test button tap
    func test_nextButton_tapped_sendsAction() throws {
        let button = try subject.inspect().find(button: "Next")
        try button.tap()

        XCTAssertEqual(processor.actions.last, .next)
    }

    // Test toggle
    func test_toggle_changed_sendsAction() throws {
        let toggle = try subject.inspect().find(ViewType.Toggle.self)
        try toggle.tap()

        XCTAssertEqual(processor.actions.last, .toggleChanged(true))
    }
}
```

#### Snapshot Tests: Visual Verification

```swift
@testable import BitwardenShared
import SnapshotTesting
import XCTest

class ExampleView_SnapshotTests: BitwardenTestCase {
    var subject: ExampleView!

    override func setUp() {
        super.setUp()
        subject = ExampleView(
            store: Store(
                processor: StateProcessor(
                    state: ExampleState(/* configure state */)
                )
            )
        )
    }

    // Test all required modes
    func test_snapshot_lightMode() {
        assertSnapshot(of: subject, as: .defaultPortrait)
    }

    func test_snapshot_darkMode() {
        assertSnapshot(of: subject, as: .defaultPortraitDark)
    }

    func test_snapshot_largeDynamicType() {
        assertSnapshot(of: subject, as: .defaultPortraitAX5)
    }

    // Test different states
    func test_snapshot_loadingState() {
        subject.store.state.isLoading = true
        assertSnapshot(of: subject, as: .defaultPortrait)
    }

    func test_snapshot_errorState() {
        subject.store.state.errorMessage = "Something went wrong"
        assertSnapshot(of: subject, as: .defaultPortrait)
    }
}
```

### Testing Coordinators

Coordinators handle navigation. Focus on:

#### What to Test
- ✅ Route navigation creates correct views/coordinators
- ✅ Child coordinators are created with correct dependencies
- ✅ Event handling triggers correct routes
- ✅ Context is passed correctly

#### Example Pattern

```swift
class ExampleCoordinatorTests: BitwardenTestCase {
    var subject: ExampleCoordinator!
    var module: MockAppModule!
    var stackNavigator: MockStackNavigator!

    override func setUp() {
        super.setUp()
        module = MockAppModule()
        stackNavigator = MockStackNavigator()
        subject = ExampleCoordinator(
            module: module,
            services: ServiceContainer.withMocks(),
            stackNavigator: stackNavigator
        )
    }

    func test_navigate_example_showsView() {
        subject.navigate(to: .example)

        XCTAssertTrue(stackNavigator.pushed)
        XCTAssertTrue(stackNavigator.pushedView is ExampleView)
    }

    func test_navigate_nextExample_createsChildCoordinator() {
        subject.navigate(to: .nextExample)

        XCTAssertTrue(module.makeNextExampleCoordinatorCalled)
    }
}
```

#### Swift Testing Example

```swift
import BitwardenKit
import BitwardenKitMocks
import Testing

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// MARK: - ExampleCoordinatorTests

@MainActor
struct ExampleCoordinatorTests {
    // MARK: Properties

    let module: MockAppModule
    let stackNavigator: MockStackNavigator
    let subject: ExampleCoordinator

    // MARK: Initialization

    init() {
        module = MockAppModule()
        stackNavigator = MockStackNavigator()
        subject = ExampleCoordinator(
            module: module,
            services: ServiceContainer.withMocks(),
            stackNavigator: stackNavigator,
        )
    }

    // MARK: Tests

    /// `navigate(to: .someScreen)` pushes the correct view.
    @Test
    func navigate_someScreen_pushesView() throws {
        subject.navigate(to: .someScreen)

        let action = try #require(stackNavigator.actions.last)
        #expect(action.type == .pushed)
        #expect(action.view is SomeView)
    }

    /// `navigate(to: .dismiss)` dismisses the current screen.
    @Test
    func navigate_dismiss_dismisses() {
        subject.navigate(to: .dismiss)

        #expect(stackNavigator.actions.last?.type == .dismissed)
    }
}
```

## Common Testing Patterns

### Pattern 1: Testing Async Operations

```swift
func test_asyncOperation_updatesState() async {
    // Setup mock result
    mockService.result = .success(expectedData)

    // Perform async effect
    await subject.perform(.loadData)

    // Assert state was updated
    XCTAssertEqual(subject.state.data, expectedData)
    XCTAssertFalse(subject.state.isLoading)
}
```

### Pattern 2: Testing Error Handling

```swift
func test_operation_failure_showsAlert() async {
    mockService.result = .failure(TestError.example)

    await subject.perform(.loadData)

    XCTAssertNotNil(subject.state.alert)
    XCTAssertEqual(subject.state.alert?.title, "Error")
}
```

### Pattern 3: Testing Publisher Streams

```swift
func test_publisher_emitsCorrectValues() async throws {
    var receivedValues: [String] = []

    let cancellable = subject.dataPublisher
        .sink { value in
            receivedValues.append(value)
        }

    // Trigger updates
    await subject.updateData("Value1")
    await subject.updateData("Value2")

    XCTAssertEqual(receivedValues, ["Value1", "Value2"])
    cancellable.cancel()
}
```

### Pattern 4: Testing State Equality

```swift
func test_state_equality() {
    let state1 = ExampleState(data: "test", isLoading: false)
    let state2 = ExampleState(data: "test", isLoading: false)
    let state3 = ExampleState(data: "other", isLoading: false)

    XCTAssertEqual(state1, state2)
    XCTAssertNotEqual(state1, state3)
}
```

## Mock Generation and Usage

### Generating Mocks with Sourcery

The codebase uses [Sourcery](https://github.com/krzysztofzablocki/Sourcery) to auto-generate mocks.

#### Mark a Protocol for Mocking

```swift
protocol ExampleService { // sourcery: AutoMockable
    func fetchData() async throws -> [String]
    var dataPublisher: AnyPublisher<[String], Never> { get }
}
```

#### Generated Mock Location

Mocks are generated in:
- `AuthenticatorBridgeKit/Sourcery/Generated/AutoMockable.generated.swift`
- `AuthenticatorShared/Sourcery/Generated/AutoMockable.generated.swift`
- `BitwardenKit/Sourcery/Generated/AutoMockable.generated.swift`
- `BitwardenShared/Sourcery/Generated/AutoMockable.generated.swift`

#### Using Generated Mocks

```swift
class ExampleTests: BitwardenTestCase {
    var mockService: MockExampleService!

    override func setUp() {
        super.setUp()
        mockService = MockExampleService()
    }

    func test_example() async throws {
        // Setup mock behavior
        mockService.fetchDataResult = .success(["data1", "data2"])

        // Use in system under test
        let result = try await mockService.fetchData()

        // Verify
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(mockService.fetchDataCalled)
    }
}
```

### ServiceContainer with Mocks

Use `ServiceContainer.withMocks()` to inject dependencies:

```swift
let services = ServiceContainer.withMocks(
    exampleRepository: mockExampleRepository,
    exampleService: mockExampleService
)

let processor = ExampleProcessor(
    coordinator: coordinator.asAnyCoordinator(),
    services: services,
    state: ExampleState()
)
```

## Running Tests

### Test Plans

Test plans are organized in the `TestPlans` folder. Each project has multiple test plans to allow running specific subsets of tests:

#### Test Plan Structure

- `{ProjectName}-Default.xctestplan`: All tests (unit, snapshot, view inspector)
- `{ProjectName}-Unit.xctestplan`: Unit tests only (any simulator)
- `{ProjectName}-Snapshot.xctestplan`: Snapshot tests only (specific simulator required)
- `{ProjectName}-ViewInspector.xctestplan`: View inspector tests only

#### Available Projects

- `Bitwarden`: Password Manager app
- `Authenticator`: Authenticator app
- `BitwardenKit`: Shared framework

### Running Tests from Command Line

#### Run All Tests

```bash
xcodebuild test \
  -project Bitwarden.xcodeproj \
  -scheme Bitwarden \
  -testPlan Bitwarden-Default \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

#### Run Unit Tests Only

```bash
xcodebuild test \
  -project Bitwarden.xcodeproj \
  -scheme Bitwarden \
  -testPlan Bitwarden-Unit \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

#### Run Snapshot Tests Only

**Important**: Must use the specific simulator from configuration files:

```bash
# Read the required simulator configuration
DEVICE=$(cat .test-simulator-device-name)
IOS_VERSION=$(cat .test-simulator-ios-version)

xcodebuild test \
  -project Bitwarden.xcodeproj \
  -scheme Bitwarden \
  -testPlan Bitwarden-Snapshot \
  -destination "platform=iOS Simulator,name=$DEVICE,OS=$IOS_VERSION"
```

#### Run a Specific Test

```bash
xcodebuild test \
  -project Bitwarden.xcodeproj \
  -scheme Bitwarden \
  -only-testing:BitwardenShared-Tests/ExampleProcessorTests/test_receive_action_updatesState
```

### Running Tests from Xcode

1. **Select Test Plan**: Product → Scheme → Edit Scheme → Test → Select Test Plan
2. **Run All Tests**: Cmd+U
3. **Run Specific Test**: Click the diamond icon next to the test method
4. **Run Test Class**: Click the diamond icon next to the class name

### Simulator Configuration

#### Unit Tests

Unit tests can run on **any simulator** thanks to the `SKIP_SIMULATOR_CHECK_FOR_TESTS` environment variable enabled in all Unit test plans.

#### Snapshot Tests

Snapshot tests **must** run on the specific simulator to avoid false failures:

- **Device**: Defined in [.test-simulator-device-name](../.test-simulator-device-name)
- **iOS Version**: Defined in [.test-simulator-ios-version](../.test-simulator-ios-version)

To verify you're using the correct simulator:

```bash
cat .test-simulator-device-name  # e.g., "iPhone 15 Pro"
cat .test-simulator-ios-version   # e.g., "17.0"
```

### Recording New Snapshots

When creating new snapshot tests or updating UI:

1. Run snapshot tests with recording enabled:
   ```bash
   # Set environment variable to record new snapshots
   RECORD_MODE=1 xcodebuild test -testPlan Bitwarden-Snapshot ...
   ```

2. Or in Xcode, edit the test scheme and add environment variable:
   - Key: `RECORD_MODE`
   - Value: `1`

3. Run the tests to record snapshots

4. Remove the environment variable and run tests again to verify

5. Commit the new snapshot images with your changes

## Test Maintenance

### When to Update Tests

#### After Changing Logic
- ✅ Update tests immediately after changing business logic
- ✅ Ensure all affected test cases pass
- ✅ Add new test cases for new branches/edge cases

#### After Changing UI
- ✅ Update ViewInspector tests if interactions changed
- ✅ Re-record snapshots if visual changes are intentional
- ✅ Verify snapshots in all modes (light, dark, accessibility)

#### After Refactoring
- ✅ Update test setup if dependencies changed
- ✅ Ensure tests still cover the same scenarios
- ✅ Remove obsolete tests for deleted code

### Test Smells to Avoid

#### ❌ Flaky Tests

**Symptoms**:
- Tests pass sometimes, fail other times
- Tests depend on timing or order
- Tests depend on external state

**Solutions**:
- Use async/await properly with proper waits
- Mock time-dependent operations
- Reset state in `setUp()` and `tearDown()`
- Avoid shared mutable state between tests

#### ❌ Testing Multiple Concerns

**Bad**: One test validates multiple unrelated things

```swift
// Bad: Testing too much in one test
func test_everything() async {
    await subject.perform(.loadData)
    XCTAssertFalse(subject.state.isLoading)
    XCTAssertNotNil(subject.state.data)

    subject.receive(.toggleChanged(true))
    XCTAssertTrue(subject.state.isToggleOn)

    subject.receive(.next)
    XCTAssertEqual(coordinator.routes.last, .next)
}
```

**Good**: Separate tests for separate concerns

```swift
// Good: One test, one concern
func test_perform_loadData_updatesState() async {
    await subject.perform(.loadData)
    XCTAssertEqual(subject.state.data, expectedData)
}

func test_receive_toggleChanged_updatesToggle() {
    subject.receive(.toggleChanged(true))
    XCTAssertTrue(subject.state.isToggleOn)
}

func test_receive_next_navigates() {
    subject.receive(.next)
    XCTAssertEqual(coordinator.routes.last, .next)
}
```

#### ❌ Not Using Mocks

**Bad**: Tests that depend on real services/network

```swift
// Bad: Using real repository
func test_loadData() async {
    let repository = DefaultExampleRepository(/* real dependencies */)
    // This makes real API calls!
}
```

**Good**: Tests that use mocks for isolation

```swift
// Good: Using mocked repository
func test_loadData() async {
    mockRepository.loadDataResult = .success(testData)
    await subject.perform(.loadData)
    XCTAssertEqual(subject.state.data, testData)
}
```

### Test Coverage Guidelines

#### Aim for High Coverage

- **Processors**: 100% coverage of actions, effects, state mutations
- **Services**: 90%+ coverage of public methods
- **Repositories**: 90%+ coverage of public methods
- **Coordinators**: 80%+ coverage of routes
- **Views**: All user interactions tested with ViewInspector
- **Models**: Test custom logic, computed properties, validation

#### What NOT to Test

- ❌ Third-party framework internals
- ❌ Apple SDK behaviors
- ❌ Simple getters/setters without logic
- ❌ Trivial computed properties that delegate to another property

### Debugging Failing Tests

#### Step 1: Isolate the Failure

```bash
# Run only the failing test
xcodebuild test -only-testing:Target/TestClass/testMethod
```

#### Step 2: Check Test Output

- Read the failure message carefully
- Check expected vs actual values
- Look for assertion failures

#### Step 3: Add Debugging

```swift
func test_example() async {
    print("State before: \(subject.state)")
    await subject.perform(.loadData)
    print("State after: \(subject.state)")
    print("Mock was called: \(mockService.fetchDataCalled)")

    XCTAssertEqual(subject.state.data, expectedData)
}
```

#### Step 4: Check Mock Setup

```swift
// Verify mock is configured correctly
func test_example() async {
    // Explicitly verify mock result is set
    XCTAssertNotNil(mockService.fetchDataResult)

    await subject.perform(.loadData)

    // Verify mock was called
    XCTAssertTrue(mockService.fetchDataCalled)
}
```

#### Step 5: Snapshot Test Failures

For snapshot test failures:

1. Check if you're using the correct simulator
2. Review the failure diff images in the test results
3. If visual changes are intentional, re-record the snapshot
4. If unintentional, fix the UI bug

### Continuous Integration

Tests run automatically on CI for:
- ✅ Pull requests to `main`
- ✅ Commits to `main`
- ✅ Release branches

CI runs all test plans:
- Unit tests (fast feedback)
- Snapshot tests (visual regression detection)
- View inspector tests (interaction validation)

Ensure all tests pass locally before pushing to prevent CI failures.

## Quick Reference for AI Agents

### Decision Matrix: Test Type Selection

| Component Type | Unit Tests | ViewInspector | Snapshots |
|---------------|------------|---------------|-----------|
| Processor     | ✅ Required | ❌ N/A        | ❌ N/A    |
| Service       | ✅ Required | ❌ N/A        | ❌ N/A    |
| Repository    | ✅ Required | ❌ N/A        | ❌ N/A    |
| Store         | ✅ Required | ❌ N/A        | ❌ N/A    |
| Coordinator   | ✅ Required | ❌ N/A        | ❌ N/A    |
| Model         | ✅ If logic | ❌ N/A        | ❌ N/A    |
| View          | ❌ N/A     | ✅ Required   | ✅ Required |

### Common Test Patterns Quick Reference

#### XCTest Patterns

```swift
// 1. Processor Test Template
func test_action_behavior() {
    subject.receive(.action)
    XCTAssertEqual(subject.state.property, expected)
}

// 2. Async Effect Test Template
func test_effect_behavior() async {
    mockService.result = .success(data)
    await subject.perform(.effect)
    XCTAssertEqual(subject.state.data, data)
}

// 3. Navigation Test Template
func test_action_navigates() {
    subject.receive(.action)
    XCTAssertEqual(coordinator.routes.last, .expectedRoute)
}

// 4. ViewInspector Test Template
func test_button_sendsAction() throws {
    let button = try subject.inspect().find(button: "Title")
    try button.tap()
    XCTAssertEqual(processor.actions.last, .expectedAction)
}

// 5. Snapshot Test Template
func test_snapshot_mode() {
    assertSnapshot(of: subject, as: .defaultPortrait)
}
```

#### Swift Testing Patterns

```swift
// 1. Processor Test Template
@Test func action_behavior() {
    subject.receive(.action)
    #expect(subject.state.property == expected)
}

// 2. Async Effect Test Template
@Test func effect_behavior() async {
    mockService.result = .success(data)
    await subject.perform(.effect)
    #expect(subject.state.data == data)
}

// 3. Navigation Test Template
@Test func action_navigates() {
    subject.receive(.action)
    #expect(coordinator.routes.last == .expectedRoute)
}

// 4. Force-Unwrap Template (replaces XCTUnwrap)
@Test func navigate_pushesView() throws {
    subject.navigate(to: .someScreen)
    let action = try #require(stackNavigator.actions.last)
    #expect(action.view is SomeView)
}
```

### Test Checklist for AI Agents

When writing tests for a component, ensure:

**General (both frameworks)**:
- [ ] Test file named correctly (`ComponentTests.swift`)
- [ ] Test file in same folder as implementation
- [ ] All public methods tested
- [ ] Error cases tested
- [ ] Edge cases tested
- [ ] Mocks used for dependencies
- [ ] Assertions are specific (not just "not nil")
- [ ] Tests ordered by function name (see ordering guidelines below)
- [ ] Async tests use `async`/`await`
- [ ] Views tested with ViewInspector AND Snapshots
- [ ] Snapshots include light/dark/accessibility modes

**XCTest-specific** (existing test files, ViewInspector, snapshot tests):
- [ ] Inherits from `BitwardenTestCase`
- [ ] `setUp()` creates fresh instances
- [ ] `tearDown()` cleans up (sets to `nil`)
- [ ] Test names use `test_action_outcome` pattern

**Swift Testing-specific** (new test files):
- [ ] `struct` with `init()` for setup (no teardown needed)
- [ ] `@Test` attribute on each test function
- [ ] `#expect()` for assertions, `#require()` for unwrapping
- [ ] `@MainActor` on the struct when all tests need main actor isolation
- [ ] Test names use `action_outcome` pattern (no `test_` prefix — `@Test` provides it)

### Test Ordering Guidelines

Tests should be organized to maximize readability and maintainability:

#### Ordering Principle

**Primary Sort**: Alphabetically by the function/method being tested (second part of test name)
**Secondary Sort**: Logically by behavior cluster (not strictly alphabetical)

#### Test Naming Pattern

```
test_<functionName>_<behaviorDescription>
```

- **Part 1**: Always `test_`
- **Part 2**: The function/method/action being tested (e.g., `receive`, `perform`, `loadData`)
- **Part 3**: The behavior being verified (e.g., `updatesState`, `showsError`, `navigates`)

#### Ordering Examples

**✅ Correct Ordering**:

```swift
class ExampleProcessorTests: BitwardenTestCase {
    // Tests for loadData() - grouped together, ordered logically
    func test_loadData_success_updatesState() async { }
    func test_loadData_failure_showsError() async { }
    func test_loadData_emptyResponse_setsEmptyState() async { }

    // Tests for receive(_:) with different actions - grouped by action
    func test_receive_cancelAction_dismissesView() { }
    func test_receive_nextAction_navigates() { }
    func test_receive_nextAction_whenInvalid_showsError() { }
    func test_receive_toggleAction_updatesState() { }
    func test_receive_toggleAction_whenDisabled_doesNothing() { }

    // Tests for saveData() - grouped together
    func test_saveData_success_showsConfirmation() async { }
    func test_saveData_failure_showsError() async { }

    // Tests for validateInput() - grouped together
    func test_validateInput_validEmail_returnsTrue() { }
    func test_validateInput_invalidEmail_returnsFalse() { }
}
```

**❌ Incorrect Ordering**:

```swift
class ExampleProcessorTests: BitwardenTestCase {
    // Bad: Tests scattered, not grouped by function
    func test_loadData_success_updatesState() async { }
    func test_receive_toggleAction_updatesState() { }
    func test_saveData_failure_showsError() async { }
    func test_loadData_failure_showsError() async { }

    // Bad: Strictly alphabetical by behavior ignores logical clustering
    func test_receive_cancelAction_dismissesView() { }
    func test_receive_nextAction_navigates() { }
    func test_receive_toggleAction_updatesState() { }
    func test_receive_toggleAction_whenDisabled_doesNothing() { }
    func test_receive_nextAction_whenInvalid_showsError() { } // Should be with other nextAction tests
}
```

#### Rationale

**Why group by function name?**
- Related tests stay together
- Easy to find all tests for a specific function
- Makes gaps in test coverage obvious

**Why not strict alphabetical on behavior?**
- Logical flow is more important (success → failure → edge cases)
- Related behaviors should cluster together
- "Happy path" tests typically come before error cases

#### Common Grouping Patterns

1. **Success → Failure → Edge Cases**
   ```swift
   func test_fetchData_success_returnsData() async { }
   func test_fetchData_failure_throwsError() async { }
   func test_fetchData_emptyResponse_returnsEmptyArray() async { }
   func test_fetchData_timeout_throwsTimeoutError() async { }
   ```

2. **By Action Type (for receive/perform tests)**
   ```swift
   // Group all tests for the same action together
   func test_receive_submitAction_validInput_savesData() { }
   func test_receive_submitAction_invalidInput_showsError() { }
   func test_receive_submitAction_emptyInput_showsValidationError() { }
   ```

3. **By State Condition**
   ```swift
   func test_appear_authenticated_loadsData() async { }
   func test_appear_unauthenticated_showsLogin() async { }
   func test_appear_offline_showsOfflineMessage() async { }
   ```

#### Special Cases

**Lifecycle Methods**: Group together at the top
```swift
class ExampleTests: BitwardenTestCase {
    // Initialization tests first
    func test_init_setsInitialState() { }
    func test_init_withParameters_configuresCorrectly() { }

    // Then alphabetically by function
    func test_loadData_success() async { }
    // ...
}
```

**Computed Properties**: Group by property name
```swift
func test_isValid_whenAllFieldsPopulated_returnsTrue() { }
func test_isValid_whenMissingFields_returnsFalse() { }
```

#### Quick Reference for AI Agents

When adding a new test:
1. Find the group of tests for the same function/method
2. Add the new test within that group
3. Order within the group by logical flow (not strict alphabetical)
4. If testing a new function, insert the group alphabetically by function name

## Pass-Y UI tests (PassYUITests)

UI tests run against a throwaway local Vaultwarden (`Scripts-passy/vaultwarden/`). They are grouped by **feature**
(class name) and by **tier** (directory); the tier decides when a test runs and whether it gates.

### Structure

| Directory | Classes (feature) | Tier |
|---|---|---|
| `Core/` | `AuthLandingTests`, `AuthLoginTests`, `AvatarMenuTests`, `ItemCrudTests`, `LockUnlockTests`, `SearchTests`, `VaultHomeTests` (15 tests) | core |
| `Full/` | `AccessibilityTests`, `AppearanceTests`, `AuthScreensTests`, `AuthTwoFactorTests`, `FoldersTests`, `GeneratorTests`, `ItemDetailTests`, `ItemListActionsTests`, `NavigationTests`, `PendingRequestsTests`, `SendTests`, `SettingsTests` (44) | full |
| `Full/iPad/` | `IPadLandingTests` (1, fresh install, sorts first), `IPadTests` (2), own iPad simulator | full |
| `Full/Perf/` | `PerfTests`, `PerfCompareTests` (9, own 2000 item account `passy-perf@example.test`) | full |
| `Shots/`, `Shots/iPad/` | `Shots*Tests` (17): screenshot export only | shots (never gating) |
| `Diagnostics/` | `DiagnosticsTests`, `KeystrokeProbeTests` | none, run by name |
| `Support/` | `PassYUITestCase` (base class, shared helpers), `PassYUITestSupport.swift` (session, typing, login) | |

A new test goes into the feature class it belongs to, in the directory of its tier; the chain picks the classes up
from the directories and counts the expected tests from the sources (no list to maintain). Every class derives from
`PassYUITestCase` (`continueAfterFailure = false`).

### Tiers

- **core** (`TIER=core`, gating, mandatory before a merge): the critical paths: first launch (server first, no cloud
  preset), login and sync, lock/unlock, vault home and list, search, open an item, add/edit/delete, avatar menu
  navigation. One simulator boot, one fresh install, one `xcodebuild test-without-building` run, one Vaultwarden. The
  app is launched and logged in once and stays running: `launchApp` reuses it and `returnToRoot` brings it back to the
  vault home between tests (only `LockUnlockTests` relaunches on purpose). No retry: a retry would be a FAIL.
  `AuthLandingTests` sorts first and needs the fresh install the step starts with.
- **full** (`TIER=full`, gating): core, then everything functional: `Full/` on the phone (fresh install, shared session:
  2FA, login sub-screens, log in with device, registration, dark mode, Dynamic Type up to AX-XXXL, accessibility audit,
  idle-stall loop, pending requests, folders, send, settings, navigation, list actions), `Full/iPad/` on an own iPad
  simulator, `Full/Perf/` against the 2000 item perf account (the perf items never slow down the other tests). Tests
  that need light and dark loop over both inside one run (`passYModes()`, `TEST_RUNNER_PASSY_MODE` picks one).
- **shots** (`TIER=shots`, never gating): `Shots/` exports screenshots to `$PASSY_SCRATCH/out/shots/<step>/`
  (`ShotsOnboardingTests` in its own fresh step, then the rest; iPad landscape with the `ipad_landscape_shots.sh` driver).

### Running

```sh
# own paths/port/simulators per parallel run (the chain never touches other runs' directories, sims or processes)
export PASSY_SCRATCH=~/Library/Caches/passy-scratch-x PASSY_DD=~/Library/Caches/passy-dd-x VW_PORT=8094 PASSY_SIM_PREFIX=PassY-X
TIER=core nohup Scripts-passy/ui_chain.sh > /dev/null 2>&1 &     # PID: $PASSY_SCRATCH/out/chain.pid
cat $PASSY_SCRATCH/out/summary.txt                                # one line per step + "TIER core: PASS|FAIL (wall ...)"
# ad hoc, after a build (Scripts-passy/build_ui.sh <name> or a chain run):
Scripts-passy/run_ui.sh one 0 PassYUITests/SearchTests/test_cancelRestoresVault
```

The chain builds once (`build-for-testing`, skip with `PASSY_SKIP_BUILD=1`), starts its own Vaultwarden (data in the
scratch directory, seeded once: `passy-test` with 25 items, `passy-2fa` with authenticator 2FA, `passy-perf` with
2000 items for full), creates its simulators (`<prefix>-Phone`, `<prefix>-iPad`, iOS 27.0, keyboard defaults once:
English QWERTY, no autocorrection/prediction/smart punctuation, no slide-to-type intro) and before every run waits PID
based until no foreign `xcodebuild` runs (at most 45 min, `PASSY_FOREIGN_WAIT`). A fresh install is uninstall +
keychain reset + removal of the app group containers (they survive `simctl uninstall`; a leftover account made the app
start on the unlock screen), so no step erases or reboots a simulator.

**Strict PASS per step** (unchanged): `** TEST SUCCEEDED **` (for `test-without-building`: `** TEST EXECUTE SUCCEEDED **`),
no `Test Case ... failed`, no `Failing tests:` entry, no `TEST FAILED` marker, no runner restart, at least the number of
test methods of the step's classes passed. `PASSY_RETRIES=1` allows one retry of the failed tests; a step green only
after it is `FLAKY` and the tier is then FAIL. Each summary line also reports wall time, app launches, `PASSY-RETYPE`
and `LOGIN-ALERT` counts and the load. Only PIDs the chain started are ended (xcodebuild after its result line,
its Vaultwarden, the landscape driver).

### Typing and lost keystrokes

All credentials, names and search terms are typed with verified helpers: `replaceText` (clears, types, compares the
field; secure fields by dot count), `typeSearch` (key by key, then compares the search field), `ensureText` (after
an append). Every mismatch prints `PASSY-RETYPE <n> field=... want=... got=... load=...` and is typed again; the third
mismatch fails the test, so a real stall cannot hide behind the retries. `focus()` waits for keyboard focus and the end
of the keyboard animation before typing. `KeystrokeProbeTests` (Diagnostics) measures losses per field.

**Finding (2026-11-23, iOS 27.0 simulator, `KeystrokeProbeTests`, own simulator with the keyboard defaults above):**

- Hardware keyboard: not involved (`ConnectHardwareKeyboard` = 0, Simulator.app not running during the runs).
- **Add/edit-form masked fields keep only the last key: an XCUITest artifact, not a user-facing bug.** In the add-login
  form the masked `LoginPasswordEntry` held 1 of 21 characters in all 10 measurements (key by key and as one
  `typeText`, focus never lost; revealed it really contained 1 character), the masked `LoginTotpEntry` 1 of 16. Not a
  re-creation of the field (one `onAppear`, no `onDisappear`) and not focus, tap or row layout (switched off one by one,
  no change). Debug logging of the field bindings showed every key also changing the *other* masked field (cleared,
  then one character). `typeText` loses keys only while a second password-like secure field is mounted (a secure field
  without content type counts as one): with the authenticator key revealed the masked password kept 21/21; with both
  masked fields set to `.oneTimeCode` (experiment only, not committed) 21/21 and 16/16 in 10/10 measurements each.
  Consistent with iOS password AutoFill treating the editor as a sign-up/password-change form. The same fields in the
  upstream layout (ScrollView instead of the native Form) lost the same way, so upstream tests would see it too.
  Software keyboard key taps (`app.keyboards.keys`) kept 21/21 with both fields masked, and a real iPhone Air
  (v1.26-ui-r9) keeps the whole typed password: product behaviour is not changed. The stray character the cross-write
  puts into the authenticator key made an add-login save fail ("An error has occurred") in an ad-hoc run.
  Test-side handling: `revealAuthenticatorKey` (Support) shows the authenticator key as a plain field first, then the
  password is the only masked field and is typed verified (`replaceText`); `addLogin`, `typePassword`,
  `ItemCrudTests` and the TOTP test use it. `KeystrokeProbeTests.test_probeAddLoginOneMaskedField` keeps the
  discriminator (one masked field, key taps). In the same earlier session the unlock screen's `SecureField` lost 0 of 21
  in 8 measurements, the search bar 0.
- **Occasional loss in the unlock field right after a relaunch:** 3 `PASSY-RETYPE` lines in about 30 unlocks of the
  ad-hoc full runs (got 17 and 20 of 21, once 26 after lost delete keys), at load 3 to 4 with keyboard focus and the
  keyboard on screen; 0 in 8 probe rounds once the screen had settled (the probe waits until the app's own focus from
  the `appeared` effect is set). It is timing on a screen that is still settling after launch, not load: the verified
  retype repairs it and every case is logged. Counted runs: 0 retypes in the core runs; the final full run had 2 (both in the unlock field after the text-size relaunches of `test_addMenuOpenCloseLoopNoIdleStall`, got 18 and 17 of 21, load 2 to 3).
- One fast `typeText` into the search bar once showed 25 of 21 (a leftover after lost delete keys); 0 key by key.
- Since the shared session unlocks once per run instead of once per test, the master password is typed about 30 times
  in a full run instead of ~90, and core types it twice.


### Former flakes and their causes

The ui-r9 final validation (`Docs/verdicts/2026-11-23-ui-r9-final.md`) needed a retry for four steps; causes and fixes:

| Former flake | Cause (evidence) | Fix |
|---|---|---|
| `test02_pendingRequestsFromMenu` (now `PendingRequestsTests.test_opensFromAvatarMenu`) | Two order/time dependencies. (1) The assertion accepted "No pending requests" or a navigation-bar `Close` button; the sheet has no `Close` (its toolbar button is `cancelToolbarItem`: label Cancel, id `CancelButton`, `View+Toolbar.swift`), so only the empty state could pass. The chain ran the "log in with device" steps (each creates an auth request for the test account) right before ui-r9; with a recent request the sheet shows the list, not the empty state. The retry ran later, the request had expired, green; three later single runs green. (2) `avatar.tap(); sleep(1)` then `menuButton` looked the entry up once, without waiting. | The sheet is asserted by its title, then "empty state or `LoginRequestCell`", then `CancelButton`; `openAvatarMenu` waits for the menu (state driven, one tap). |
| 2FA dark (`AuthTwoFactorTests`) | The master password went into the revealed field with an unverified `typeText`; a lost key gives "Username or password is incorrect" and the two-step screen never appears (the README's earlier server-log evidence for the same account). The step also started from an uninstall, not from a defined screen. | `replaceText` into the revealed field (exact value compared, retypes logged), `reachLoginPasswordScreen` starts from any state, a login alert is logged as `LOGIN-ALERT 2fa`. |
| iPad light (`IPadTests`) | "Login keeps failing": the Vaultwarden log showed the user name `passy-test@exam.`, i.e. the e-mail typed by `ensureUnlockedVault` with an unverified `typeText` right after the server sheet closed, on a freshly erased simulator. | Server URL and e-mail are typed with `replaceText` (verified, after keyboard focus and the end of the keyboard animation); the landing's remembered e-mail is replaced, never appended to. |
| iPad landscape (`ShotsIPadLandscapeTests`) | Screenshot collector with an out-of-process handshake over the shared `/tmp/r6hold` (parallel validators share it) and a 600 s driver wait; the first run restarted the runner ("Interface orientation changed to Portrait"). No functional assertion. | Moved to the shots tier (never gating); own hold directory (`TEST_RUNNER_PASSY_HOLD_DIR`), whole-screen shots also attached in the test, orientation reset in a teardown block. |

Other causes found on the way (all fixed): `deleteCurrentItem` slept 3 s before "item deleted" (now waits for the row
to go); the "copied" toast lives 3 s (`ToastView`) and was looked for after a fixed `sleep(1)` (now polled right
after the tap; the second copy waits for the first toast to go instead of 4 s); favorite toggling slept 3 s;
`menuButton` returned a never-existing element while a menu was still opening (now a query that matches when it
appears); swipe actions were asserted 1 s after the swipe without waiting; folder, send, item names and search terms
were typed unverified (the "empty folder row" and "no keyboard focus" reds of ui-r8/r9); every test relaunched the app
and typed the master password again (about one unlock per test, each a chance to lose a key; now one launch per run plus
deliberate relaunches); after a green run `xcodebuild` sat up to 600 s in `simctl diagnose` (sampled:
`XCTHRunDestinationAllocator.collectSimulatorDiagnostics`), now `-collect-test-diagnostics never`; app group
containers survive `simctl uninstall` (fresh install now removes them, no erase).


Measured on this branch (Vaultwarden 1.37.5, iOS 27.0, own simulators, no foreign xcodebuild running at the
starts): `TIER=core` three runs in a row 305 s, 325 s, 314 s wall (15/15 tests each, 0 retries, 0 retypes, 2 app
launches); the step itself 272 to 289 s. `TIER=full` (commit 8fd4e7af3): PASS, wall 4319 s (72 min): core 311 s, full-phone 2897 s
(43/43; `test_addMenuOpenCloseLoopNoIdleStall` alone ~7 min), iPad 338 s (2/2), perf 704 s (9/9), 0 retries.

**iPad finding (fixed on `passy/next-fixes`):** after the first-launch server sheet was cancelled, tapping "Server: Not
set" did not open it again on the iPad. The tap never reached the button action (no `.regionPressed`): the row is a
plain-style `Button` whose label is `Label`, `Spacer`, value, chevron, and a plain button hit-tests only its content, not
the `Spacer`; XCUITest taps the middle of the element, which on the wide iPad row is empty space. The row now has
`.contentShape(Rectangle())` (landing and registration). `Full/iPad/IPadLandingTests.test_serverSheetReopensAfterCancel`
(fresh install, sorts before `IPadTests`) cancels the sheet and reopens it twice.

### Old to new test names

All 88 former UI tests are kept; bodies were moved verbatim first (commit "restructure by feature and tier": the
sorted set of `XCTAssert*`/`XCTFail`/`XCTSkip` lines equals `main`, 415 lines). Assertion changes made afterwards are
listed below the table.

| Old test | New test | Tier |
|---|---|---|
| `PassYAuditShotsTests.test_a_onboarding` | `ShotsOnboardingTests.test2_auditOnboarding` | shots |
| `PassYAuditShotsTests.test_b_mainScreens` | `ShotsMainScreensTests.test_auditMainScreens` | shots |
| `PassYAuditShotsTests.test_c_unlock` | `ShotsMainScreensTests.test_auditUnlock` | shots |
| `PassYAuditShotsTests.test_d_send` | `ShotsMainScreensTests.test_auditSend` | shots |
| `PassYAuditShotsTests.test_e_sheets` | `ShotsMainScreensTests.test_auditSheets` | shots |
| `PassYFlowTests.test01_landingAsksForServerAndHasNoCloudPreset` | `AuthLandingTests.test_landingAsksForServerAndHasNoCloudPreset` | core |
| `PassYFlowTests.test02_loginAndSync` | `AuthLoginTests.test_loginAndSync` | core |
| `PassYFlowTests.test03_createSearchEditDelete` | `ItemCrudTests.test_createSearchEditDelete` | core |
| `PassYFlowTests.test04_totpCodeShown` | `ItemDetailTests.test_totpCodeShown` | full |
| `PassYFlowTests.test05_generator` | `GeneratorTests.test_generatorRegenerates` | full |
| `PassYFlowTests.test06_settingsHasNoPremiumUpsell` | `SettingsTests.test_noPremiumUpsellNoBranding` | full |
| `PassYFlowTests.test07_lockAndUnlock` | `LockUnlockTests.test_lockedAfterRestartWrongPasswordRejectedThenUnlock` | core |
| `PassYFlowTests.test08_addMenuOpensWithEntries` | `ItemCrudTests.test_addMenuOpensWithEntries` | core |
| `PassYFlowTests.test09_searchCancelRestoresVault` | `SearchTests.test_cancelRestoresVault` | core |
| `PassYFlowTests.test10_searchOpenCloseCancel` | `SearchTests.test_openResultCloseThenCancel` | core |
| `PassYFlowTests.test12_itemViewRevealAndCopyTaps` | `ItemDetailTests.test_revealCopyAndFavoriteTaps` | full |
| `PassYFlowTests.test13_settingsAccountMenu` | `SettingsTests.test_accountRowMenuLockAndLogoutConfirm` | full |
| `PassYFlowTests.test14_settingsSubscreens` | `SettingsTests.test_subscreensAppearanceOtherVaultFolders` | full |
| `PassYFlowTests.test15_sendTabAddMenu` | `SendTests.test_addMenuOffersTextAndOpensForm` | full |
| `PassYFlowTests.test16_createSendAndShowList` | `SendTests.test_createTextSendAndList` | full |
| `PassYFlowTests.test16_settingsAccountSecurityAutofillAbout` | `SettingsTests.test_accountSecurityAutofillAbout` | full |
| `PassYFlowTests.test17_foldersListLastRowClearOfAddButton` | `FoldersTests.test_foldersListLastRowClearOfBar` | full |
| `PassYFlowTests.test18_noOptionalTextAndLastRowsClearOfBar` | `NavigationTests.test_noOptionalTextAndLastRowsClearOfBar` | full |
| `PassYFlowTests.test19_noTabBarAndAvatarMenuNavigates` | `AvatarMenuTests.test_noTabBarAndMenuNavigates` | core |
| `PassYFlowTests.test20_searchBarPersistentAtBottom` | `NavigationTests.test_searchBarPersistentAtBottom` | full |
| `PassYFlowTests.test21_categoryTilesAreLarge` | `VaultHomeTests.test_categoryTilesAreLarge` | core |
| `PassYFlowTests.test22_editInToolbarAndSendInfoInMenu` | `ItemDetailTests.test_editInToolbarAndSendInfoInMenu` | full |
| `PassYFlowTests.test23_barBackdropIsPageIndependent` | `NavigationTests.test_barBackdropIsPageIndependent` | full |
| `PassYFlowTests.test24_settingsFoldersNative` | `FoldersTests.test_settingsFoldersNative` | full |
| `PassYFlowTests.test25_tilesEqualHeightNoWrap` | `VaultHomeTests.test_tilesEqualHeightNoWrap` | core |
| `PassYFlowTests.test26_itemViewItemEditAndSendAddAreNativeForms` | `ItemDetailTests.test_viewEditAndSendAddAreNativeForms` | full |
| `PassYFlowTests.test27_setupSectionIsNativeRows` | `SettingsTests.test_autofillSetupSectionNativeAndDismissPersists` | full |
| `PassYFlowTests.test28_homeLargeTitleAndInlineItemRows` | `VaultHomeTests.test_largeTitleAndInlineItemRows` | core |
| `PassYImportRegShotsTests.test_exportVault` | `SettingsTests.test_exportVaultForm` | full |
| `PassYImportRegShotsTests.test_registrationStart` | `AuthScreensTests.test_registrationStart` | full |
| `PassYLandingShotsTests.test_landingShot` | `ShotsOnboardingTests.test1_landing` | shots |
| `PassYPerfTests.test_perf_scroll` | `PerfTests.test_perf_scroll` | full (perf) |
| `PassYPerfTests.test_perf_scrollMetrics` | `PerfTests.test_perf_scrollMetrics` | full (perf) |
| `PassYPerfTests.test_perf_search` | `PerfTests.test_perf_search` | full (perf) |
| `PassYPerfTests.test_perf_singleTapOpensItem_2000` | `PerfTests.test_perf_singleTapOpensItem_2000` | full (perf) |
| `PassYPerfTests.test_perf_tapToPush_signposts` | `PerfTests.test_perf_tapToPush_signposts` | full (perf) |
| `PassYPerfTests.test_perf_unlockToVault` | `PerfTests.test_perf_unlockToVault` | full (perf) |
| `PassYShotsTests.test_shots` | `ShotsMainScreensTests.test_mainScreens` | shots |
| `PassYUiR4ShotsTests.test_a_auth` | `ShotsOnboardingTests.test3_loginSubscreens` | shots |
| `PassYUiR4ShotsTests.test_addTypes` | `ShotsItemTests.test_addFormOfEveryType` | shots |
| `PassYUiR4ShotsTests.test_ipad` | `IPadTests.test_mainScreensLightAndDark` | full (iPad) |
| `PassYUiR4ShotsTests.test_item` | `ShotsItemTests.test_itemViewAndEdit` | shots |
| `PassYUiR4ShotsTests.test_send` | `ShotsSendTests.test_sendFormsAndPasswordHistory` | shots |
| `PassYUiR4ShotsTests.test_sendTypeList` | `ShotsSendTests.test_sendTypeList` | shots |
| `PassYUiR4ShotsTests.test_setupSections` | `ShotsSettingsTests.test_setupSections` | shots |
| `PassYUiR4ShotsTests.test_tiles` | `ShotsHomeTests.test_tiles` | shots |
| `PassYUiR5ShotsTests.test_addMenuAccessibilityXXXL` | `AccessibilityTests.test_addMenuReachableAtAXXXL` | full |
| `PassYUiR5ShotsTests.test_compare` | `ShotsItemTests.test_appleComparison` | shots |
| `PassYUiR5ShotsTests.test_dynamicTypeForms` | `AccessibilityTests.test_dynamicTypeAddForms` | full |
| `PassYUiR5ShotsTests.test_ipadShell` | `IPadTests.test_shellPortraitAndLandscape` | full (iPad) |
| `PassYUiR5ShotsTests.test_newTypeForms` | `ItemDetailTests.test_newItemTypeForms` | full |
| `PassYUiR5ShotsTests.test_voiceOverLabels` | `AccessibilityTests.test_voiceOverLabelsAndAudit` | full |
| `PassYUiR6ShotsTests.test_auth2FAScreens` | `AuthTwoFactorTests.test_twoStepLoginScreens` | full |
| `PassYUiR6ShotsTests.test_authPagesInRunningApp` | `AuthScreensTests.test_loginSubscreens` | full |
| `PassYUiR6ShotsTests.test_ipadLandscapeHold` | `ShotsIPadLandscapeTests.test_landscapeHold` | shots (iPad) |
| `PassYUiR6ShotsTests.test_loginWithDeviceAfterLogout` | `AuthScreensTests.test_loginWithDeviceAfterLogout` | full |
| `PassYUiR6ShotsTests.test_rowChevronContextMenuSwipe` | `ItemListActionsTests.test_rowChevronContextMenuSwipe` | full |
| `PassYUiR6ShotsTests.test_selectModeDelete` | `ItemListActionsTests.test_selectModeDelete` | full |
| `PassYUiR6ShotsTests.test_swipeDelete` | `ItemListActionsTests.test_swipeDelete` | full |
| `PassYUiR7ShotsTests.test_addEditFormsAreInlineRows` | `ItemDetailTests.test_addEditFormsAreInlineRows` | full |
| `PassYUiR7ShotsTests.test_editFormOfEveryType` | `ShotsItemTests.test_editFormOfEveryType` | shots |
| `PassYUiR7ShotsTests.test_homeSearchSelectDelete` | `ItemListActionsTests.test_searchResultsContextMenuSelectSwipeDelete` | full |
| `PassYUiR7ShotsTests.test_loginPasswordSaveAndRevealRoundTrip` | `ItemDetailTests.test_passwordSaveAndRevealRoundTrip` | full |
| `PassYUiR7ShotsTests.test_secureFieldTypingDiagnostic` | `DiagnosticsTests.test_secureFieldTypingDiagnostic` | none (by name) |
| `PassYUiR8CompareTests.test_cmp_rowTapOpensItem` | `PerfCompareTests.test_cmp_rowTapOpensItem` | full (perf) |
| `PassYUiR8CompareTests.test_cmp_tileTapToList` | `PerfCompareTests.test_cmp_tileTapToList` | full (perf) |
| `PassYUiR8CompareTests.test_cmp_unlockToFirstRow` | `PerfCompareTests.test_cmp_unlockToFirstRow` | full (perf) |
| `PassYUiR8Tests.test00_dumpGroupListTree` | `DiagnosticsTests.test_dumpGroupListTree` | none (by name) |
| `PassYUiR8Tests.test01_singleTapOpensItemFromBlankArea` | `ItemCrudTests.test_singleTapOnBlankAreaOpensItem` | core |
| `PassYUiR8Tests.test02_singleTapOpensFolder` | `FoldersTests.test_singleTapOpensFolder` | full |
| `PassYUiR8Tests.test03_largeTitlesCollapse` | `NavigationTests.test_largeTitlesCollapse` | full |
| `PassYUiR8Tests.test04_vaultButtonLeftOfSearch` | `NavigationTests.test_vaultButtonLeftOfSearch` | full |
| `PassYUiR8Tests.test05_noBackdropBehindBar` | `FoldersTests.test_emptyFolderNoBackdropBehindBar` | full |
| `PassYUiR8Tests.test06_backAndCloseEverywhere` | `NavigationTests.test_backAndCloseEverywhere` | full |
| `PassYUiR9Tests.test01_avatarMenu` | `AvatarMenuTests.test_menuEntriesServerUrlNoAccountEntries` | core |
| `PassYUiR9Tests.test02_pendingRequestsFromMenu` | `PendingRequestsTests.test_opensFromAvatarMenu` | full |
| `PassYUiR9Tests.test03_settingsAccountRowAndNoWebVaultNoWatch` | `SettingsTests.test_accountRowServerAddAccountNoWebVaultNoWatch` | full |
| `PassYUiR9Tests.test04_itemOpensWithoutSpinner` | `ItemCrudTests.test_itemOpensWithoutSpinner` | core |
| `PassYUiR9Tests.test05_listNoSpinner_vaultButtonFollowsStack` | `VaultHomeTests.test_listNoSpinnerVaultButtonFollowsStack` | core |
| `PassYUiR9Tests.test06_contentScrollsUnderBars` | `NavigationTests.test_contentScrollsUnderBars` | full |
| `PassYUiR9Tests.test07_addMenuOpenCloseLoop` | `AccessibilityTests.test_addMenuOpenCloseLoopNoIdleStall` | full |
| `PassYZAppearanceTests.test_darkMode` | `AppearanceTests.test_darkModeWalk` | full |
| `PassYZAppearanceTests.test_largeText` | `AccessibilityTests.test_largeTextWalk` | full |

Assertion changes after the move (diff of the sorted assertion lines `main` vs. this branch):

- `PendingRequestsTests.test_opensFromAvatarMenu`: `"No pending requests" || navigationBars.buttons["Close"]` replaced by
  three assertions (title "Pending login requests"; empty state or `LoginRequestCell`; `CancelButton`). Stronger, and
  no longer dependent on server state.
- `AuthScreensTests.test_loginSubscreens`, `AuthTwoFactorTests.test_twoStepLoginScreens`: the start-up assertions
  `logIn.waitForExistence(20)` and `email.waitForExistence(10)` moved into `reachLoginPasswordScreen` (it fails the test
  when the login screen is not reached); the fresh-install intro ("Log in") and server sheet are asserted by
  `AuthLandingTests` (core). Both tests (and `test_loginWithDeviceAfterLogout`, `IPadTests.test_shellPortraitAndLandscape`)
  now run light and dark in one run instead of one chain step per appearance.
- Added: `openAvatarMenu` checks (3x), "account menu offers Log out" (2x), helper failures with the caller's line
  (`ensureUnlockedVault`, `reachLoginPasswordScreen`, `replaceText` after three lost-keystroke attempts).
- `continueAfterFailure` is `false` for every class (it was `true` in the former ui-r4..r9/audit classes): a test stops at
  its first failure; a passing run checks the same assertions.


Pass-Y unit/ViewInspector tests (BitwardenShared, `UI/Platform/Application/Views/`) are named by feature; the former
round names map as follows: `PassYUiR9Tests` -> `PassYAppHygieneTests` (`PassYAppHygieneTests.swift`, run by CI),
`PassYUiR9IdleTests` -> `PassYIdleTests` and `PassYUiR9NoRefreshControlTests` -> `PassYVaultNoRefreshControlTests`
(`PassYIdleTests.swift`), `PassYUiR9PreloadTests` -> `PassYItemPreloadTests` (`PassYItemPreloadTests.swift`, together
with `PassYPreloadSecurityTests`), `PassYUiR9ViewInspectorTests` -> `PassYAvatarMenuViewInspectorTests`
(`PassYAvatarMenu+ViewInspectorTests.swift`). Unit plans: `Scripts-passy/run_plan.sh`.
