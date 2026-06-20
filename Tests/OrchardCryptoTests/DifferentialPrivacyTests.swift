@testable import OrchardCrypto
import Testing

struct DifferentialPrivacyTests {
    private let dp = DifferentialPrivacy()

    @Test("Clipping scales an over-norm vector down to the bound")
    func clipReducesNorm() {
        let clipped = dp.clip([3.0, 4.0], maxL2Norm: 1.0) // norm 5 → 1
        let norm = (clipped[0] * clipped[0] + clipped[1] * clipped[1]).squareRoot()
        #expect(abs(norm - 1.0) < 1e-9)
    }

    @Test("Clipping leaves an under-norm vector unchanged")
    func clipLeavesSmallVectors() {
        let v = [0.1, 0.2]
        #expect(dp.clip(v, maxL2Norm: 1.0) == v)
    }

    @Test("Noise is reproducible for a fixed seed")
    func noiseIsDeterministic() {
        var r1 = SeededGenerator(seed: 42)
        var r2 = SeededGenerator(seed: 42)
        let a = dp.addGaussianNoise([0, 0, 0, 0], sigma: 1.0, using: &r1)
        let b = dp.addGaussianNoise([0, 0, 0, 0], sigma: 1.0, using: &r2)
        #expect(a == b)
    }

    @Test("Mean of many Gaussian samples is near zero")
    func noiseIsCentered() {
        var rng = SeededGenerator(seed: 1)
        let samples = (0 ..< 5000).map { _ in dp.sampleGaussian(sigma: 1.0, using: &rng) }
        let mean = samples.reduce(0, +) / Double(samples.count)
        #expect(abs(mean) < 0.05)
    }
}
