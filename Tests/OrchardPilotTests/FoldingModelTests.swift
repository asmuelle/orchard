@testable import OrchardPilot
import Testing

struct FoldingModelTests {
    @Test("Energy is zero at the native state and positive elsewhere")
    func energyMinimizedAtNative() {
        #expect(FoldingModel.energy(FoldingModel.nativeState) == 0)
        #expect(FoldingModel.energy([0, 0, 0]) > 0)
    }

    @Test("Gradient vanishes at the native state")
    func gradientZeroAtNative() {
        #expect(FoldingModel.gradient(at: FoldingModel.nativeState) == [0, 0, 0])
    }

    @Test("A descent step strictly reduces energy away from the minimum")
    func descentReducesEnergy() {
        let theta = [2.0, 2.0, 2.0]
        let grad = FoldingModel.gradient(at: theta)
        let stepped = zip(theta, grad).map { $0 - 0.1 * $1 }
        #expect(FoldingModel.energy(stepped) < FoldingModel.energy(theta))
    }
}
