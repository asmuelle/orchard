import OrchardProtocol
@testable import OrchardRouter
import Testing

struct ConsensusEngineTests {
    private let engine = ConsensusEngine(minimumAgreement: 2)
    private let taskID = TaskID("t1")

    private func completed(_ node: String, _ value: String) -> TaskResult {
        .completed(taskID: taskID, nodeID: NodeID(node), payload: ["v": .string(value)])
    }

    @Test("Agrees when enough nodes return the same payload")
    func agreesOnMajority() {
        let outcome = engine.resolve([
            completed("a", "x"),
            completed("b", "x"),
            completed("c", "y"),
        ])
        #expect(outcome == .agreed(payload: ["v": .string("x")], support: 2, total: 3))
    }

    @Test("Flags the disagreeing node as a dissenter")
    func reportsDissenters() {
        let report = engine.report(taskID: taskID, results: [
            completed("a", "x"),
            completed("b", "x"),
            completed("c", "y"),
        ])
        #expect(report.dissenters == [NodeID("c")])
    }

    @Test("Returns noQuorum on a tie with no clear winner")
    func tieIsNoQuorum() {
        let outcome = engine.resolve([
            completed("a", "x"),
            completed("b", "y"),
        ])
        #expect(outcome == .noQuorum(total: 2))
    }

    @Test("Returns noQuorum when support is below the threshold")
    func belowThresholdIsNoQuorum() {
        let outcome = engine.resolve([completed("a", "x")])
        #expect(outcome == .noQuorum(total: 1))
    }

    @Test("Returns noResults when every node held or failed")
    func noUsableResults() {
        let outcome = engine.resolve([
            .held(taskID: taskID, nodeID: NodeID("a"), reasons: ["notIdle"]),
            .failed(taskID: taskID, nodeID: NodeID("b"), message: "boom"),
        ])
        #expect(outcome == .noResults)
    }
}
