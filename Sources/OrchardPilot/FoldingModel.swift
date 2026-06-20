// A stand-in scientific objective: an energy surface whose global minimum is the "folded" state.
// Real folding landscapes are rugged and multi-well; this smooth bowl keeps the pilot's results
// deterministic and verifiable while still exercising the full distributed pipeline (evaluate a
// space in parallel, reach consensus, then refine by federated gradient descent).

public enum FoldingModel {
    /// The conformation that minimizes the energy (E = 0 here).
    public static let nativeState: [Double] = [0.5, -0.3, 0.8]

    /// Energy of a conformation: squared distance from the native state.
    public static func energy(_ theta: [Double], center: [Double] = nativeState) -> Double {
        zip(theta, center).reduce(0) { sum, pair in
            let delta = pair.0 - pair.1
            return sum + delta * delta
        }
    }

    /// ∇E — points away from the native state, so a descent step moves toward it.
    public static func gradient(at theta: [Double], center: [Double] = nativeState) -> [Double] {
        zip(theta, center).map { 2 * ($0.0 - $0.1) }
    }
}
