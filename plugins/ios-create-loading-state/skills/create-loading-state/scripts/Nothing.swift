/// A blank type that is similar to Void but allows Equatable, Hashable,
/// Codable, and Proto3Codable conformance.
public struct Nothing: Hashable, Sendable, Error {
    public init() {}
}

// MARK: - Codable

extension Nothing: Codable {
    public init(from decoder: any Decoder) throws {}
}

/// A type alias when the "empty" better describes the type than "nothing".
public typealias Empty = Nothing
