import OrchardProtocol

// Aggregates the redundant results for one task into a single trusted answer by majority vote
// over the structured payloads. Nodes are untrusted, so a payload is only accepted when enough
// independent nodes produced the *same* structured output. Ties (no clear winner) and thin
// support resolve to noQuorum rather than guessing — the router can then re-dispatch.

public enum ConsensusOutcome: Sendable, Hashable {
    /// A payload reached the agreement threshold. `support` of `total` completed results matched.
    case agreed(payload: [String: JSONValue], support: Int, total: Int)
    /// Results came back, but none reached the threshold (or there was a tie).
    case noQuorum(total: Int)
    /// No usable (completed, non-nil) results — every assigned node held or failed.
    case noResults
}

public struct ConsensusResult: Sendable, Hashable {
    public let taskID: TaskID
    public let outcome: ConsensusOutcome
    /// Nodes that completed with a payload other than the agreed one — candidates for reputation loss.
    public let dissenters: [NodeID]

    public init(taskID: TaskID, outcome: ConsensusOutcome, dissenters: [NodeID]) {
        self.taskID = taskID
        self.outcome = outcome
        self.dissenters = dissenters
    }
}

public struct ConsensusEngine: Sendable {
    /// Minimum number of matching payloads required to accept an answer.
    public let minimumAgreement: Int

    public init(minimumAgreement: Int = 2) {
        self.minimumAgreement = max(1, minimumAgreement)
    }

    public func resolve(_ results: [TaskResult]) -> ConsensusOutcome {
        let payloads = results
            .filter { $0.status == .completed }
            .compactMap(\.payload)
        guard !payloads.isEmpty else { return .noResults }

        var votes: [[String: JSONValue]: Int] = [:]
        for payload in payloads {
            votes[payload, default: 0] += 1
        }

        let maxCount = votes.values.max() ?? 0
        let winners = votes.filter { $0.value == maxCount }
        guard winners.count == 1, let winner = winners.first, maxCount >= minimumAgreement else {
            return .noQuorum(total: payloads.count)
        }
        return .agreed(payload: winner.key, support: maxCount, total: payloads.count)
    }

    public func report(taskID: TaskID, results: [TaskResult]) -> ConsensusResult {
        let outcome = resolve(results)
        var dissenters: [NodeID] = []
        if case let .agreed(payload, _, _) = outcome {
            dissenters = results
                .filter { $0.status == .completed && $0.payload != nil && $0.payload != payload }
                .map(\.nodeID)
        }
        return ConsensusResult(taskID: taskID, outcome: outcome, dissenters: dissenters)
    }
}
