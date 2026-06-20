import OrchardProtocol

// The global orchestrator: fragments a Job into micro-tasks, assigns each redundantly across the
// fleet, dispatches every (task, node) pair concurrently, then resolves each task by consensus.
// This is the "synthesized consensus" step — millions of structured outputs collapsed into one
// trusted answer per task.

public struct JobOutcome: Sendable {
    public let jobID: String
    public let results: [ConsensusResult]

    public init(jobID: String, results: [ConsensusResult]) {
        self.jobID = jobID
        self.results = results
    }

    public var agreedCount: Int {
        results.count(where: { if case .agreed = $0.outcome { true } else { false } })
    }

    public var unresolvedCount: Int {
        results.count - agreedCount
    }
}

public actor TaskRouter {
    private let fragmenter: TaskFragmenter
    private let assigner: AssignmentPlanner
    private let consensus: ConsensusEngine
    private let dispatcher: NodeDispatcher

    public init(
        dispatcher: NodeDispatcher,
        fragmenter: TaskFragmenter = TaskFragmenter(),
        assigner: AssignmentPlanner = AssignmentPlanner(),
        consensus: ConsensusEngine = ConsensusEngine()
    ) {
        self.dispatcher = dispatcher
        self.fragmenter = fragmenter
        self.assigner = assigner
        self.consensus = consensus
    }

    public func run(job: Job, nodes: [NodeID]) async throws(RouterError) -> JobOutcome {
        let tasks = try fragmenter.fragment(job)
        let assignments = try assigner.assign(tasks: tasks, to: nodes)
        let specByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })

        var grouped: [TaskID: [TaskResult]] = [:]
        await withTaskGroup(of: (TaskID, TaskResult).self) { group in
            for assignment in assignments {
                guard let spec = specByID[assignment.taskID] else { continue }
                for node in assignment.nodes {
                    group.addTask { [dispatcher] in
                        await (assignment.taskID, dispatcher.dispatch(spec, to: node))
                    }
                }
            }
            for await (taskID, result) in group {
                grouped[taskID, default: []].append(result)
            }
        }

        let results = tasks.map { consensus.report(taskID: $0.id, results: grouped[$0.id] ?? []) }
        return JobOutcome(jobID: job.id, results: results)
    }
}
