import Foundation

/// A state that can load and only succeed.
///
/// This is commonly used to represent components whose support a loading state, but whose composer is
/// responsible for rendering a fail state.
public enum LoadingState<Loading, Completed> {
    /// A loading, storing a `Loading` value.
    case loading(Loading)

    /// A completed state, storing the `Completed` value.
    case completed(Completed)
}

// MARK: - Equatable

extension LoadingState: Equatable where Loading: Equatable, Completed: Equatable {}

// MARK: - Hashable

extension LoadingState: Hashable where Loading: Hashable, Completed: Hashable {}

// MARK: - Sendable

extension LoadingState: Sendable where Loading: Sendable, Completed: Sendable {}

// MARK: - Encodable

extension LoadingState: Encodable where Loading: Encodable, Completed: Encodable {}

// MARK: - Decodable

extension LoadingState: Decodable where Loading: Decodable, Completed: Decodable {}

// MARK: - Identifiable

extension LoadingState: Identifiable where Completed: Identifiable<String> {
    public var id: String {
        switch self {
        case let .completed(state): state.id
        case .loading: UUID().uuidString
        }
    }
}

extension LoadingState where Loading == Void {
    /// Loading convenience
    public static var loading: Self { .loading(()) }
}

extension LoadingState where Loading == Nothing {
    /// Loading convenience
    public static var loading: Self { .loading(Nothing()) }
}

extension LoadingState where Completed == Void {
    /// Completed convenience
    public static var completed: Self { .completed(()) }
}

extension LoadingState where Completed == Nothing {
    /// Completed convenience
    public static var completed: Self { .completed(Nothing()) }
}

extension LoadingState {
    /// Is the state is currently loading.
    public var isLoading: Bool {
        switch self {
        case .loading: true
        default: false
        }
    }
}

extension LoadingState {

    /// The progress if the loading state is still loading.
    public var progress: Loading? {
        switch self {
        case let .loading(progress): progress
        default: nil
        }
    }

    /// The value if the loading state succeeded.
    public var value: Completed? {
        switch self {
        case let .completed(value): value
        default: nil
        }
    }
}

extension LoadingState {
    /// Is the other states in the same state as self.
    public func isInSameState(as other: LoadingState<some Any, some Any>) -> Bool {
        switch (self, other) {
        case (.loading, .loading): true
        case (.completed, .completed): true
        default: false
        }
    }
}

public func ~= (lhs: LoadingState<some Any, some Any>, rhs: LoadingState<some Any, some Any>) -> Bool {
    lhs.isInSameState(as: rhs)
}

extension LoadingState {
    /// Returns a new result, mapping any Completed value using the given transformation.
    public func map<NewCompleted>(_ transform: (Completed) -> NewCompleted) -> LoadingState<Loading, NewCompleted> {
        switch self {
        case let .loading(progress): .loading(progress)
        case let .completed(value): .completed(transform(value))
        }
    }

    /// Returns a new result, mapping any Completed value using the given transformation and unwrapping the produced
    /// result.
    public func flatMap<NewCompleted>(_ transform: (Completed) -> LoadingState<Loading, NewCompleted>)
        -> LoadingState<Loading, NewCompleted>
    {
        switch self {
        case let .loading(progress): .loading(progress)
        case let .completed(value): transform(value)
        }
    }

    /// Returns a new result, mapping any loading value using the given transformation.
    public func mapProgress<NewLoading>(_ transform: (Loading) -> NewLoading) -> LoadingState<NewLoading, Completed> {
        switch self {
        case let .loading(progress): .loading(transform(progress))
        case let .completed(value): .completed(value)
        }
    }

    /// Returns a new result, mapping any loading value using the given transformation and unwrapping the produced
    /// result.
    public func flatMapProgress<NewLoading>(_ transform: (Loading) -> LoadingState<NewLoading, Completed>)
        -> LoadingState<NewLoading, Completed>
    {
        switch self {
        case let .loading(progress): transform(progress)
        case let .completed(value): .completed(value)
        }
    }
}

extension LoadingState {
    /// Returns a LoadingState instance based on the passed in value. If the result is an optional and nil then return
    /// `.loading`.
    public init(value: Completed?) where Loading == Void {
        self = switch value {
        case let .some(completedValue): .completed(completedValue)
        case nil: .loading
        }
    }

    /// Returns a LoadingState instance based on the passed in value. If the result is an optional and nil then return
    /// `.loading`.
    public init(value: Completed?) where Loading == Nothing {
        self = switch value {
        case let .some(completedValue): .completed(completedValue)
        case nil: .loading
        }
    }
}

// MARK: CardAction

extension LoadingState {

    /// Triggers the closure passed in with the value when it is in the completed state, if no value exists the closure
    /// will not be invoked.
    ///
    /// Commonly used blocking impressions or card taps when dealing with loadable data.
    public func onValue(_ action: @escaping (Completed) -> Void) -> (() -> Void)? {
        self.value.map { value in { action(value) } }
    }

    /// Intended for displaying a ``Frisbee/Card`` whose action should not be taken while loading.
    ///
    /// When showing components that can appear as loading or completed, the loading state should not
    /// invoke the action.
    public func emptyCardAction(_ action: (@MainActor () -> Void)?) -> (@MainActor () -> Void)? {
        switch self {
        case .loading: nil
        case .completed: action
        }
    }
}
