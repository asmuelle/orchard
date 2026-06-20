import Foundation
import MLX
import OrchardMLX
import OrchardProtocol
import OrchardSwarm

// Runs the same model two ways and proves they agree: a 2-device sharded pipeline on the Metal
// GPU (MLXShardExecutor) vs. the pure-Swift oracle. Requires Apple Silicon + Metal.
// Build/run with: just mlx-demo  (sets ORCHARD_ENABLE_MLX=1).

func maxAbsDiff(_ a: [Float], _ b: [Float]) -> Float {
    zip(a, b).map { abs($0 - $1) }.max() ?? 0
}

let dimension = 64
let layerCount = 24
let model = ShardableModel.deterministic(dimension: dimension, layerCount: layerCount, seed: 2026)
let input = (0 ..< dimension).map { Float($0 % 7) * 0.05 }

// Shard the layers across two "devices" using the real planner.
let planner = ShardPlanner(memoryHeadroom: 0)
let profile = ModelProfile(name: "mlx-demo", layerCount: layerCount, bytesPerLayerMB: 100)
let peers = [
    NodeCapabilities(nodeID: NodeID("gpu-a"), tier: .desktop, usableMemoryMB: 1500, aneGeneration: 18, isOnPower: true),
    NodeCapabilities(nodeID: NodeID("gpu-b"), tier: .desktop, usableMemoryMB: 1500, aneGeneration: 18, isOnPower: true),
]

print("🌳 Orchard MLX sharded-execution demo")
do {
    let plan = try planner.plan(model: profile, across: peers)
    print("  model:   \(layerCount) layers, dim \(dimension)")
    for (i, stage) in plan.stages.enumerated() {
        print("  stage \(i): \(stage.owner) → layers \(stage.layerRange.lowerBound)..<\(stage.layerRange.upperBound)")
    }

    // Headless SwiftPM executables can't load MLX's Metal library, so compute on the CPU stream.
    // Inside a bundled app this would be `.default` (GPU).
    let mlxExecutors: [NodeID: any ShardExecutor] = [
        NodeID("gpu-a"): MLXShardExecutor(stream: .cpu),
        NodeID("gpu-b"): MLXShardExecutor(stream: .cpu),
    ]
    let mlxOutput = try await PipelineRunner().run(
        plan: plan, model: model, input: input, executors: mlxExecutors
    )
    let referenceOutput = try await LocalShardExecutor().execute(
        layerRange: 0 ..< layerCount, of: model, input: input
    )

    let diff = maxAbsDiff(mlxOutput, referenceOutput)
    print("  MLX (Metal) sharded output[0..3]: \(mlxOutput.prefix(3).map { String(format: "%.5f", $0) })")
    print("  pure-Swift reference   [0..3]: \(referenceOutput.prefix(3).map { String(format: "%.5f", $0) })")
    print("  max |Δ| = \(String(format: "%.2e", diff))  → \(diff < 1e-3 ? "MATCH ✅" : "MISMATCH ❌")")
} catch {
    print("  MLX demo failed: \(error)")
}
