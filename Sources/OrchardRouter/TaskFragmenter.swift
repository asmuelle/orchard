import OrchardProtocol

// Splits a Job into micro-tasks: one TaskSpec per work unit, each carrying the job's schema and
// redundancy. Task ids are namespaced as "<jobID>/<unitID>" so results route back unambiguously.
// Validation failures (empty prompt, bad redundancy) surface as RouterError.invalidJob.

public struct TaskFragmenter: Sendable {
    public init() {}

    public func fragment(_ job: Job) throws(RouterError) -> [TaskSpec] {
        var tasks: [TaskSpec] = []
        tasks.reserveCapacity(job.units.count)
        for unit in job.units {
            do {
                try tasks.append(TaskSpec(
                    id: TaskID("\(job.id)/\(unit.id)"),
                    kind: job.kind,
                    prompt: unit.prompt,
                    outputSchema: job.schema,
                    redundancy: job.redundancy
                ))
            } catch {
                throw RouterError.invalidJob("\(error)")
            }
        }
        return tasks
    }
}
