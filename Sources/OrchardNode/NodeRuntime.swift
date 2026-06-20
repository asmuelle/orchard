import OrchardProtocol

// The single-node runtime: the heart of a participating device. For each task it (1) re-reads
// device conditions, (2) consults the opportunistic scheduler, and only if cleared (3) runs
// on-device inference and validates the structured output before returning it. An actor so a
// node processes its assigned work serially and safely under Swift concurrency.

public actor NodeRuntime {
    public let nodeID: NodeID
    private let scheduler: OpportunisticScheduler
    private let engine: InferenceEngine
    private let conditions: DeviceConditionsProvider

    public init(
        nodeID: NodeID,
        engine: InferenceEngine,
        conditions: DeviceConditionsProvider,
        scheduler: OpportunisticScheduler = OpportunisticScheduler()
    ) {
        self.nodeID = nodeID
        self.engine = engine
        self.conditions = conditions
        self.scheduler = scheduler
    }

    /// Processes one task, honoring the opportunistic gate. Never throws — an unmet condition,
    /// engine error, or schema violation is reported as a structured ``TaskResult`` the router
    /// can reason about, rather than crashing the node.
    public func process(_ task: TaskSpec) async -> TaskResult {
        let state = await conditions.currentState()

        switch scheduler.decide(for: state) {
        case let .hold(reasons):
            return .held(
                taskID: task.id,
                nodeID: nodeID,
                reasons: reasons.map(\.rawValue)
            )

        case .run:
            do {
                let response = try await engine.run(
                    InferenceRequest(prompt: task.prompt, schema: task.outputSchema)
                )
                try SchemaValidator.validate(response.payload, against: task.outputSchema)
                return .completed(taskID: task.id, nodeID: nodeID, payload: response.payload)
            } catch {
                return .failed(taskID: task.id, nodeID: nodeID, message: "\(error)")
            }
        }
    }
}
