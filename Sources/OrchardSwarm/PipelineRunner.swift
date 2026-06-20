import OrchardProtocol

// Drives a ShardPlan to completion: feeds the input through each pipeline stage in order, handing
// one stage's output activations to the next stage's owner. This is the runtime counterpart to
// ShardPlanner — together they turn "this model is too big for one device" into an actual
// distributed forward pass that yields the same result a single device would.

public struct PipelineRunner: Sendable {
    public enum RunError: Error, Sendable, Hashable {
        case missingExecutor(NodeID)
    }

    public init() {}

    public func run(
        plan: ShardPlan,
        model: ShardableModel,
        input: [Float],
        executors: [NodeID: any ShardExecutor]
    ) async throws -> [Float] {
        var activations = input
        for stage in plan.stages {
            guard let executor = executors[stage.owner] else {
                throw RunError.missingExecutor(stage.owner)
            }
            activations = try await executor.execute(
                layerRange: stage.layerRange,
                of: model,
                input: activations
            )
        }
        return activations
    }
}
