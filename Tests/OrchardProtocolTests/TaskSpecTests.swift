import Foundation
@testable import OrchardProtocol
import Testing

struct TaskSpecTests {
    let schema = StructuredSchema.required([("title", .string)])

    @Test("A valid task is created with defaults")
    func validTaskIsCreated() throws {
        let task = try TaskSpec(
            id: TaskID("t1"),
            kind: .index,
            prompt: "Summarize this page",
            outputSchema: schema
        )
        #expect(task.id == TaskID("t1"))
        #expect(task.redundancy == 1)
    }

    @Test("An empty or whitespace-only prompt is rejected")
    func emptyPromptRejected() {
        #expect(throws: ProtocolError.emptyPrompt) {
            try TaskSpec(id: TaskID("t1"), kind: .infer, prompt: "   \n", outputSchema: schema)
        }
    }

    @Test("Redundancy below 1 is rejected")
    func invalidRedundancyRejected() {
        #expect(throws: ProtocolError.invalidRedundancy(0)) {
            try TaskSpec(
                id: TaskID("t1"),
                kind: .infer,
                prompt: "ok",
                outputSchema: schema,
                redundancy: 0
            )
        }
    }

    @Test("A task round-trips through Codable")
    func roundTripsThroughCodable() throws {
        let task = try TaskSpec(
            id: TaskID("t1"),
            kind: .simulate,
            prompt: "Fold protein fragment",
            outputSchema: schema,
            redundancy: 3
        )
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(TaskSpec.self, from: data)
        #expect(decoded == task)
    }
}
