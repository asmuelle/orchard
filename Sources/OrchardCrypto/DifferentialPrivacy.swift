import Foundation

// Differential privacy primitives applied locally, before masking. Gradient clipping bounds each
// contribution's L2 norm (and hence the mechanism's sensitivity); the Gaussian mechanism then adds
// calibrated noise. Together they bound what any aggregate can reveal about one participant.

public struct DifferentialPrivacy: Sendable {
    public init() {}

    /// Scales a vector down so its L2 norm is at most `maxL2Norm`. Smaller vectors pass through.
    public func clip(_ vector: [Double], maxL2Norm: Double) -> [Double] {
        let norm = vector.reduce(0) { $0 + $1 * $1 }.squareRoot()
        guard norm > maxL2Norm, norm > 0 else { return vector }
        let factor = maxL2Norm / norm
        return vector.map { $0 * factor }
    }

    public func addGaussianNoise(
        _ vector: [Double],
        sigma: Double,
        using rng: inout some RandomNumberGenerator
    ) -> [Double] {
        vector.map { $0 + sampleGaussian(sigma: sigma, using: &rng) }
    }

    /// One Gaussian sample via the Box–Muller transform.
    func sampleGaussian(sigma: Double, using rng: inout some RandomNumberGenerator) -> Double {
        let u1 = Double.random(in: Double.leastNonzeroMagnitude ... 1, using: &rng)
        let u2 = Double.random(in: 0 ..< 1, using: &rng)
        let magnitude = (-2 * Foundation.log(u1)).squareRoot()
        return sigma * magnitude * Foundation.cos(2 * Double.pi * u2)
    }
}
