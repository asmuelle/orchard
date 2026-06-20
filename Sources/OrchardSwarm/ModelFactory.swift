public extension ShardableModel {
    /// Builds a deterministic model for tests, demos, and executor parity checks. Weights are
    /// scaled by 1/√dimension for numerical stability through many tanh layers. Pure integer LCG
    /// so results are reproducible without any RNG dependency.
    static func deterministic(dimension: Int, layerCount: Int, seed: UInt64) -> ShardableModel {
        var state = seed
        func nextUnit() -> Float {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let bits = UInt32(truncatingIfNeeded: state >> 32)
            return Float(bits) / Float(UInt32.max) * 2 - 1 // [-1, 1]
        }

        let weightScale = (1.0 / Float(dimension)).squareRoot()
        let layers = (0 ..< layerCount).map { _ in
            LayerWeights(
                weight: (0 ..< dimension * dimension).map { _ in nextUnit() * weightScale },
                bias: (0 ..< dimension).map { _ in nextUnit() * 0.1 }
            )
        }
        return ShardableModel(dimension: dimension, layers: layers)
    }
}
