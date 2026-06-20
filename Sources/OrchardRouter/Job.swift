import OrchardProtocol

// A massive problem submitted to the swarm, expressed as many small, independent work units that
// share an output schema — e.g. "index these 10M URLs" or "evaluate this model on these fragments".
// The router fragments a Job into one TaskSpec per unit and assigns each redundantly.

public struct WorkUnit: Sendable, Hashable {
    public let id: String
    public let prompt: String

    public init(id: String, prompt: String) {
        self.id = id
        self.prompt = prompt
    }
}

public struct Job: Sendable {
    public let id: String
    public let kind: TaskKind
    public let schema: StructuredSchema
    public let units: [WorkUnit]
    /// How many independent nodes should run each unit so results can be cross-checked.
    public let redundancy: Int

    public init(
        id: String,
        kind: TaskKind,
        schema: StructuredSchema,
        units: [WorkUnit],
        redundancy: Int = 3
    ) {
        self.id = id
        self.kind = kind
        self.schema = schema
        self.units = units
        self.redundancy = redundancy
    }
}
