import Foundation
import OrchardNode
import OrchardProtocol

// Runs a single web-indexing task through a node runtime end to end. Uses the on-device
// Foundation Models engine when the platform provides it (OS 26+), otherwise the deterministic
// stub — so `just build && .build/debug/orchard-demo` works on any machine.

func makeEngine() -> InferenceEngine {
    #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            return FoundationModelsEngine()
        }
    #endif
    return StubInferenceEngine()
}

let schema = StructuredSchema.required([
    ("title", .string),
    ("summary", .string),
    ("topics", .array),
])

let task = try TaskSpec(
    id: TaskID("demo-001"),
    kind: .index,
    prompt: "Summarize for indexing: 'The Apple Neural Engine accelerates on-device ML.'",
    outputSchema: schema
)

let engine = makeEngine()
let runtime = NodeRuntime(
    nodeID: NodeID("demo-node"),
    engine: engine,
    conditions: StaticConditionsProvider(.ready)
)

print("🌳 Orchard node demo — engine: \(engine.identifier)")
let result = await runtime.process(task)

print("Node:   \(result.nodeID)")
print("Task:   \(result.taskID)")
print("Status: \(result.status.rawValue)")

if let payload = result.payload {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(payload),
       let json = String(data: data, encoding: .utf8)
    {
        print("Payload:\n\(json)")
    }
}

if !result.heldReasons.isEmpty {
    print("Held: \(result.heldReasons.joined(separator: ", "))")
}

if let error = result.errorMessage {
    print("Error: \(error)")
}
