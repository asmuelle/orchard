import Foundation
import OrchardNode
import OrchardProtocol
import OrchardSwarm

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

// --- Micro-swarm demo: a model far too large for a single phone ---
print("\n🌳 Orchard micro-swarm demo")

let local = NodeCapabilities(
    nodeID: NodeID("this-iphone"),
    tier: .phone,
    usableMemoryMB: 4000,
    aneGeneration: 18,
    isOnPower: true
)
let mac = NodeCapabilities(
    nodeID: NodeID("studio-mac"),
    tier: .desktop,
    usableMemoryMB: 32000,
    aneGeneration: 18,
    isOnPower: true
)
let ipad = NodeCapabilities(
    nodeID: NodeID("ipad-pro"),
    tier: .tablet,
    usableMemoryMB: 8000,
    aneGeneration: 18,
    isOnPower: true
)

let swarm = SwarmCoordinator(local: local, discovery: StaticPeerDiscovery([mac, ipad]))
let bigModel = ModelProfile(name: "orchard-30b", layerCount: 48, bytesPerLayerMB: 700)

switch await swarm.formSwarm(for: bigModel) {
case let .soloSufficient(node):
    print("\(bigModel.name) fits on \(node) alone — no swarm needed.")
case let .swarm(coordinatorID, plan):
    print("Formed swarm for \(plan.modelName): \(bigModel.layerCount) layers, coordinator \(coordinatorID)")
    for (index, stage) in plan.stages.enumerated() {
        let range = "\(stage.layerRange.lowerBound)..<\(stage.layerRange.upperBound)"
        print("  stage \(index): \(stage.owner) → layers \(range) (\(stage.layerCount))")
    }
case let .insufficient(required, available):
    print("Insufficient memory: needs \(required)MB, swarm offers \(available)MB.")
}
