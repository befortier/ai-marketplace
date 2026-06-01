/// A data structure representing the given state of any asynchronous loading operation.
///
/// Similar to `Result` but useful you need that extra state to describe when you are in a loading state.
///
/// NOTE: If you need an `idle`, `initial`, `default`, or `none` case, define the usage of of loading state as an
/// optional, ex: `FailableLoadingState<...>?`.
/// If we find that we are doing that a lot a we can either add an additional case or make a new enum type.
public enum FailableLoadingState<Loading, Success, Failure: Error> {
    /// A loading, storing a `Loading` value.
    case loading(Loading)
    /// A success, storing a `Success` value.
    case success(Success)
    /// A failure, storing a `Failure` value.
    case failure(Failure)
}

// MARK: - Equatable

extension FailableLoadingState: Equatable where Loading: Equatable, Success: Equatable, Failure: Equatable {}

// MARK: - Hashable

extension FailableLoadingState: Hashable where Loading: Hashable, Success: Hashable, Failure: Hashable {}

// MARK: - Sendable

extension FailableLoadingState: Sendable where Loading: Sendable, Success: Sendable {}

// MARK: - Encodable

extension FailableLoadingState: Encodable where Loading: Encodable, Success: Encodable, Failure: Encodable {}

// MARK: - Decodable

extension FailableLoadingState: Decodable where Loading: Decodable, Success: Decodable, Failure: Decodable {}

extension FailableLoadingState where Loading == Void {
    /// Loading convenience
    public static var loading: Self { .loading(()) }
}

extension FailableLoadingState where Loading == Nothing {
    /// Loading convenience
    public static var loading: Self { .loading(Nothing()) }
}

extension FailableLoadingState where Success == Void {
    /// Success convenience
    public static var success: Self { .success(()) }
}

extension FailableLoadingState where Success == Nothing {
    /// Success convenience
    public static var success: Self { .success(Nothing()) }
}

extension FailableLoadingState where Failure == Nothing {
    /// Failure convenience.
    public static var failure: Self { .failure(Nothing()) }
}

extension FailableLoadingState {
    /// Is the state is currently loading.
    public var isLoading: Bool {
        switch self {
        case .loading: true
        default: false
        }
    }

    /// Did the loading state succeed.
    public var isSuccess: Bool {
        switch self {
        case .success: true
        default: false
        }
    }

    /// Did the loading state fail.
    public var isFailure: Bool {
        switch self {
        case .failure: true
        default: false
        }
    }
}

extension FailableLoadingState {

    /// The progress if the loading state is still loading.
    public var progress: Loading? {
        switch self {
        case let .loading(progress): progress
        default: nil
        }
    }

    /// The value if the loading state succeeded.
    public var value: Success? {
        switch self {
        case let .success(value): value
        default: nil
        }
    }

    /// The error if the loading state failed.
    public var error: Failure? {
        switch self {
        case let .failure(error): error
        default: nil
        }
    }
}

extension FailableLoadingState {
    /// Is the other states in the same state as self.
    public func isInSameState(as other: FailableLoadingState<some Any, some Any, some Any>) -> Bool {
        switch (self, other) {
        case (.loading, .loading): true
        case (.success, .success): true
        case (.failure, .failure): true
        default: false
        }
    }
}

public func ~= (
    lhs: FailableLoadingState<some Any, some Any, some Any>,
    rhs: FailableLoadingState<some Any, some Any, some Any>
) -> Bool {
    lhs.isInSameState(as: rhs)
}

extension FailableLoadingState {
    /// Mutates the success value in place using the given closure.
    ///
    /// No-op when the state is not `.success`.
    public mutating func modifySuccess(_ body: (inout Success) -> Void) {
        guard case var .success(value) = self else {
            return
        }
        body(&value)
        self = .success(value)
    }
}

extension FailableLoadingState {
    /// Returns a new result, mapping any success value using the given transformation.
    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess)
        -> FailableLoadingState<Loading, NewSuccess, Failure>
    {
        switch self {
        case let .loading(progress): .loading(progress)
        case let .success(value): .success(transform(value))
        case let .failure(error): .failure(error)
        }
    }

    /// Returns a new result, mapping any success value using the given transformation and unwrapping the produced
    /// result.
    public func flatMap<NewSuccess>(_ transform: (Success) -> FailableLoadingState<Loading, NewSuccess, Failure>)
        -> FailableLoadingState<Loading, NewSuccess, Failure>
    {
        switch self {
        case let .loading(progress): .loading(progress)
        case let .success(value): transform(value)
        case let .failure(error): .failure(error)
        }
    }

    /// Returns a new result, mapping any loading value using the given transformation.
    public func mapProgress<NewLoading>(_ transform: (Loading) -> NewLoading)
        -> FailableLoadingState<NewLoading, Success, Failure>
    {
        switch self {
        case let .loading(progress): .loading(transform(progress))
        case let .success(value): .success(value)
        case let .failure(error): .failure(error)
        }
    }

    /// Returns a new result, mapping any loading value using the given transformation and unwrapping the produced
    /// result.
    public func flatMapProgress<NewLoading>(_ transform: (Loading)
        -> FailableLoadingState<NewLoading, Success, Failure>
    ) -> FailableLoadingState<NewLoading, Success, Failure> {
        switch self {
        case let .loading(progress): transform(progress)
        case let .success(value): .success(value)
        case let .failure(error): .failure(error)
        }
    }

    /// Returns a new result, mapping any failure value using the given transformation.
    public func mapError<NewFailure>(_ transform: (Failure) -> NewFailure)
        -> FailableLoadingState<Loading, Success, NewFailure> where NewFailure: Error
    {
        switch self {
        case let .loading(progress): .loading(progress)
        case let .success(value): .success(value)
        case let .failure(error): .failure(transform(error))
        }
    }

    /// Returns a new result, mapping any failure value using the given transformation and unwrapping the produced
    /// result.
    public func flatMapError<NewFailure>(_ transform: (Failure) -> FailableLoadingState<Loading, Success, NewFailure>)
        -> FailableLoadingState<Loading, Success, NewFailure> where NewFailure: Error
    {
        switch self {
        case let .loading(progress): .loading(progress)
        case let .success(value): .success(value)
        case let .failure(error): transform(error)
        }
    }
}

extension FailableLoadingState {
    /// Returns a FailableLoadingState instance based on the passed in result. If the result is an optional and nil then
    /// return `.loading`.
    public init(result: Result<Success, Failure>?) where Loading == Void {
        self = switch result {
        case let .success(value): .success(value)
        case let .failure(error): .failure(error)
        case nil: .loading
        }
    }

    /// Returns a FailableLoadingState instance based on the passed in result. If the result is an optional and nil then
    /// return `.loading`.
    public init(result: Result<Success, Failure>?) where Loading == Nothing {
        self = switch result {
        case let .success(value): .success(value)
        case let .failure(error): .failure(error)
        case nil: .loading
        }
    }

    /// Returns a Swift.Result instance based on the current loading state.
    public var result: Result<Success, Failure>? {
        switch self {
        case let .success(value): .success(value)
        case let .failure(error): .failure(error)
        default: nil
        }
    }
}
