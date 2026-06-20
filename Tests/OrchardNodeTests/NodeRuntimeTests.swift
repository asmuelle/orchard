@testable import OrchardNode
import OrchardProtocol
import Testing

struct NodeRuntimeTests {
    let schema = StructuredSchema.required([("title", .string)])

    private func makeTask() throws -> TaskSpec {
        try TaskSpec(id: TaskID("t1"), kind: .index, prompt: "summarize", outputSchema: schema)
    }

    @Test("Completes and returns a validated payload when conditions are met")
    func completesWhenConditionsMet() async throws {
        let runtime = NodeRuntime(
            nodeID: NodeID("n1"),
            engine: StubInferenceEngine(),
            conditions: StaticConditionsProvider(.ready)
        )
        let result = try await runtime.process(makeTask())
        #expect(result.status == .completed)
        #expect(result.payload?["title"] == .string("stub:title"))
    }

    @Test("Holds work, with reasons, when conditions are not met")
    func holdsWhenConditionsNotMet() async throws {
        var state = DeviceState.ready
        state.isIdle = false
        let runtime = NodeRuntime(
            nodeID: NodeID("n1"),
            engine: StubInferenceEngine(),
            conditions: StaticConditionsProvider(state)
        )
        let result = try await runtime.process(makeTask())
        #expect(result.status == .held)
        #expect(result.heldReasons == [HoldReason.notIdle.rawValue])
        #expect(result.payload == nil)
    }

    @Test("Fails gracefully when the engine throws")
    func failsWhenEngineThrows() async throws {
        let runtime = NodeRuntime(
            nodeID: NodeID("n1"),
            engine: ThrowingEngine(),
            conditions: StaticConditionsProvider(.ready)
        )
        let result = try await runtime.process(makeTask())
        #expect(result.status == .failed)
        #expect(result.errorMessage != nil)
    }

    @Test("Fails when engine output violates the schema")
    func failsWhenOutputViolatesSchema() async throws {
        let runtime = NodeRuntime(
            nodeID: NodeID("n1"),
            engine: WrongShapeEngine(),
            conditions: StaticConditionsProvider(.ready)
        )
        let result = try await runtime.process(makeTask())
        #expect(result.status == .failed)
    }
}

// MARK: - Test doubles

private struct ThrowingEngine: InferenceEngine {
    let identifier = "throwing"
    struct Boom: Error {}
    func run(_: InferenceRequest) async throws -> InferenceResponse {
        throw Boom()
    }
}

private struct WrongShapeEngine: InferenceEngine {
    let identifier = "wrong-shape"
    func run(_: InferenceRequest) async throws -> InferenceResponse {
        // Returns a number where the schema requires a string.
        InferenceResponse(payload: ["title": .number(42)], rawText: "42")
    }
}
