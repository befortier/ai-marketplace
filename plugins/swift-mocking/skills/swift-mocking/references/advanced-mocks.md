# Advanced mocks

## Contents
- Property mocking (read-only and read-write)
- Checking returned values
- Static members
- Manual mocks (@MockedMembers)
- Implementation-type reference table

## Property mocking

### Read-only properties

```swift
@Mocked
protocol MetadataProvider: Sendable {
    var userIdentifier: String? { get }
}

let mock = MetadataProviderMock()
mock._userIdentifier.getter.implementation = .returns("user123")
```

### Read-write properties

```swift
@Mocked
protocol Configuration {
    var timeout: TimeInterval { get set }
}

mock._timeout.getter.implementation = .returns(30.0)
mock._timeout.setter.implementation = .invokes { newValue in /* track */ }

#expect(mock._timeout.setter.callCount == 2)
#expect(mock._timeout.setter.lastInvocation == 60.0)
```

## Checking returned values

```swift
let returned = mock._method.returnedValues   // all returned values
let last = mock._method.lastReturnedValue    // most recent
```

## Static members

Protocols with static requirements generate static mock handles. Reset them
between tests so stubs don't leak:

```swift
@Mocked
protocol CameraPermissionsProviding {
    static func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus
}

// setup/teardown:
CameraPermissionsProvidingMock.resetMockedStaticMembers()
```

## Manual mocks (@MockedMembers)

When `@Mocked` can't be applied directly — e.g. a protocol that inherits another —
hand-write the mock with `@MockedMembers` and `@MockableProperty`:

```swift
protocol SomeProtocol {
    var readOnlyProperty: Int { get }
}

protocol Dependency: SomeProtocol {
    var readWriteProperty: String { get set }
    func method()
}

#if SWIFT_MOCKING_ENABLED
@MockedMembers
final class DependencyMock: Dependency {
    @MockableProperty(.readOnly)
    var readOnlyProperty: Int

    @MockableProperty(.readWrite)
    var readWriteProperty: String

    func method()
}
#endif
```

## Implementation-type reference table

The macro picks a method-implementation type from the member's shape (return,
throwing, async, parameterized):

| Return | Throwing | Async | Parameterized | Implementation type |
|--------|----------|-------|---------------|---------------------|
| Value | No  | No  | No  | `MockReturningNonParameterizedMethod` |
| Value | No  | No  | Yes | `MockReturningParameterizedMethod` |
| Value | Yes | No  | Yes | `MockReturningParameterizedThrowingMethod` |
| Value | No  | Yes | Yes | `MockReturningParameterizedAsyncMethod` |
| Value | Yes | Yes | Yes | `MockReturningParameterizedAsyncThrowingMethod` |
| Void  | No  | No  | Yes | `MockVoidParameterizedMethod` |
| Void  | No  | Yes | Yes | `MockVoidParameterizedAsyncMethod` |
