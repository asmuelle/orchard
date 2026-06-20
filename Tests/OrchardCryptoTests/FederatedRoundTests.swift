@testable import OrchardCrypto
import Testing

struct FederatedRoundTests {
    private func approx(_ a: [Double], _ b: [Double], tol: Double) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < tol }
    }

    @Test("Recovers the exact mean from masked vectors when noise is off")
    func recoversMeanWithoutNoise() throws {
        var rng = SeededGenerator(seed: 1)
        let gradients = [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]] // true mean [3, 4]
        let config = FederatedConfig(clipNorm: 100, noiseSigma: 0, quantizationScale: 1_000_000)

        let mean = try FederatedRound.secureMean(gradients: gradients, config: config, using: &rng)
        #expect(approx(mean, [3.0, 4.0], tol: 1e-4))
    }

    @Test("Clipping bounds an outlier's contribution to the mean")
    func clippingBoundsOutlier() throws {
        var rng = SeededGenerator(seed: 2)
        // Second gradient is a huge outlier; clipping to norm 1 caps its pull on the mean.
        let gradients = [[0.0], [1000.0]]
        let config = FederatedConfig(clipNorm: 1, noiseSigma: 0, quantizationScale: 1_000_000)

        let mean = try FederatedRound.secureMean(gradients: gradients, config: config, using: &rng)
        // Clipped outlier contributes at most 1.0 → mean ≤ 0.5.
        #expect(mean[0] <= 0.5 + 1e-6)
    }

    @Test("Differential-privacy noise stays within a small tolerance of the true mean")
    func noiseStaysWithinTolerance() throws {
        var rng = SeededGenerator(seed: 7)
        let gradients = Array(repeating: [0.0, 0.0, 0.0, 0.0], count: 20)
        let config = FederatedConfig(clipNorm: 1, noiseSigma: 0.01, quantizationScale: 1_000_000)

        let mean = try FederatedRound.secureMean(gradients: gradients, config: config, using: &rng)
        #expect(mean.allSatisfy { abs($0) < 0.05 })
    }

    @Test("An empty cohort yields an empty result")
    func emptyCohort() throws {
        var rng = SeededGenerator(seed: 0)
        let mean = try FederatedRound.secureMean(gradients: [], config: FederatedConfig(), using: &rng)
        #expect(mean.isEmpty)
    }
}
