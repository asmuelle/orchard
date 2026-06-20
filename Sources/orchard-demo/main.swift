import Foundation
import OrchardCrypto
import OrchardNode
import OrchardProtocol
import OrchardRouter
import OrchardSwarm
import OrchardTransport

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

// --- Global task-router demo: redundant assignment + consensus over a faulty node ---
print("\n🌳 Orchard task-router demo")

let routerNodes = [NodeID("node-a"), NodeID("node-b"), NodeID("node-c")]
let indexJob = Job(
    id: "web-index",
    kind: .index,
    schema: StructuredSchema.required([("topic", .string)]),
    units: (1 ... 3).map { WorkUnit(id: "page\($0)", prompt: "Summarize public page \($0)") },
    redundancy: 3
)

let router = TaskRouter(dispatcher: DemoDispatcher(faulty: [NodeID("node-c")]))
let jobOutcome = try await router.run(job: indexJob, nodes: routerNodes)

print("Job \(jobOutcome.jobID): \(jobOutcome.agreedCount)/\(jobOutcome.results.count) tasks reached consensus")
for report in jobOutcome.results {
    switch report.outcome {
    case let .agreed(_, support, total):
        let dissent = report.dissenters.isEmpty
            ? ""
            : " — rejected \(report.dissenters.map(\.value).joined(separator: ", "))"
        print("  \(report.taskID): agreed \(support)/\(total)\(dissent)")
    case let .noQuorum(total):
        print("  \(report.taskID): no quorum (\(total) results)")
    case .noResults:
        print("  \(report.taskID): no results")
    }
}

// --- Secure-aggregation demo: server recovers the mean gradient, sees no raw gradient ---
print("\n🌳 Orchard secure-aggregation demo")

var dpRng = SeededGenerator(seed: 2026)
let gradients = [
    [0.8, -0.3, 1.2],
    [0.6, -0.1, 0.9],
    [0.7, -0.2, 1.0],
    [0.9, 0.0, 1.1],
]
let cryptoConfig = FederatedConfig(clipNorm: 5, noiseSigma: 0.02, quantizationScale: 1_000_000)

func format(_ values: [Double]) -> String {
    "[" + values.map { String(format: "%.3f", $0) }.joined(separator: ", ") + "]"
}

do {
    let secureMean = try FederatedRound.secureMean(
        gradients: gradients,
        config: cryptoConfig,
        using: &dpRng
    )
    let plaintextMean = (0 ..< gradients[0].count).map { column in
        gradients.reduce(0) { $0 + $1[column] } / Double(gradients.count)
    }
    print("  participants:    \(gradients.count) (raw gradients never leave a device)")
    print("  plaintext mean:  \(format(plaintextMean))")
    print("  secure DP mean:  \(format(secureMean))")
    print("  → reconstructed from masked vectors only, with SecAgg + differential privacy")
} catch {
    print("  secure aggregation failed: \(error)")
}

// --- Cross-device transport demo: shard a model across two TCP services, activations on the wire ---
print("\n🌳 Orchard cross-device transport demo")

let transportModel = ShardableModel.deterministic(dimension: 16, layerCount: 8, seed: 99)
let transportInput = [Float](repeating: 0.1, count: 16)

let stageA = ShardService(executor: LocalShardExecutor(), model: transportModel)
let stageB = ShardService(executor: LocalShardExecutor(), model: transportModel)
do {
    let portA = try await stageA.start()
    let portB = try await stageB.start()
    print("  stage A listening on 127.0.0.1:\(portA), stage B on 127.0.0.1:\(portB)")

    let transportPlan = ShardPlan(modelName: transportModel.layerCount.description, stages: [
        LayerShard(owner: NodeID("a"), layerRange: 0 ..< 5),
        LayerShard(owner: NodeID("b"), layerRange: 5 ..< 8),
    ])
    let remoteExecutors: [NodeID: any ShardExecutor] = [
        NodeID("a"): RemoteShardExecutor(endpoint: NodeEndpoint(port: portA)),
        NodeID("b"): RemoteShardExecutor(endpoint: NodeEndpoint(port: portB)),
    ]
    let distributed = try await PipelineRunner().run(
        plan: transportPlan, model: transportModel, input: transportInput, executors: remoteExecutors
    )
    let monolithic = try await LocalShardExecutor().execute(
        layerRange: 0 ..< transportModel.layerCount, of: transportModel, input: transportInput
    )
    let drift = zip(distributed, monolithic).map { abs($0 - $1) }.max() ?? 0
    print("  ran 8 layers across 2 services; activations crossed TCP between stages")
    print("  distributed vs monolithic max |Δ| = \(String(format: "%.2e", drift))  → \(drift < 1e-4 ? "MATCH ✅" : "MISMATCH ❌")")
    await stageA.stop()
    await stageB.stop()
} catch {
    print("  transport demo failed: \(error)")
}

// MARK: - Demo dispatcher

/// Runs each task through a real NodeRuntime + stub engine; one node is wired to diverge so the
/// router's consensus visibly outvotes and flags it.
struct DemoDispatcher: NodeDispatcher {
    let faulty: Set<NodeID>

    func dispatch(_ task: TaskSpec, to node: NodeID) async -> TaskResult {
        let engine: InferenceEngine = faulty.contains(node)
            ? DivergentStubEngine()
            : StubInferenceEngine()
        let runtime = NodeRuntime(
            nodeID: node,
            engine: engine,
            conditions: StaticConditionsProvider(.ready)
        )
        return await runtime.process(task)
    }
}

/// A stub that returns schema-valid but deliberately different output.
struct DivergentStubEngine: InferenceEngine {
    let identifier = "divergent-stub"

    func run(_ request: InferenceRequest) async throws -> InferenceResponse {
        var payload: [String: JSONValue] = [:]
        for field in request.schema.fields where field.type == .string {
            payload[field.name] = .string("divergent:\(field.name)")
        }
        return InferenceResponse(payload: payload, rawText: "divergent")
    }
}
