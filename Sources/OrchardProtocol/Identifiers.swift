// Typed identifiers for the Orchard wire protocol. String-backed so they serialize
// transparently, but distinct types so a NodeID can never be passed where a TaskID is expected.

/// Identifies a single unit of work fragmented out by the Task Router.
public struct TaskID: Sendable, Hashable, Codable, CustomStringConvertible {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public var description: String {
        value
    }
}

/// Identifies a participating device (node) in the swarm.
public struct NodeID: Sendable, Hashable, Codable, CustomStringConvertible {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public var description: String {
        value
    }
}
