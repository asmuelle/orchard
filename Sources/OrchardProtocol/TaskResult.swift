// The result a node returns for a task. A node may legitimately decline to run work when its
// device conditions aren't met (held), complete it, or fail. The router treats `payload` as
// untrusted until corroborated by other nodes (see TaskSpec.redundancy).

public struct TaskResult: Sendable, Hashable, Codable {
    public enum Status: String, Sendable, Hashable, Codable {
        case completed
        case held
        case failed
    }

    public let taskID: TaskID
    public let nodeID: NodeID
    public let status: Status
    public let payload: [String: JSONValue]?
    public let heldReasons: [String]
    public let errorMessage: String?

    public init(
        taskID: TaskID,
        nodeID: NodeID,
        status: Status,
        payload: [String: JSONValue]? = nil,
        heldReasons: [String] = [],
        errorMessage: String? = nil
    ) {
        self.taskID = taskID
        self.nodeID = nodeID
        self.status = status
        self.payload = payload
        self.heldReasons = heldReasons
        self.errorMessage = errorMessage
    }

    public static func completed(
        taskID: TaskID,
        nodeID: NodeID,
        payload: [String: JSONValue]
    ) -> TaskResult {
        TaskResult(taskID: taskID, nodeID: nodeID, status: .completed, payload: payload)
    }

    public static func held(
        taskID: TaskID,
        nodeID: NodeID,
        reasons: [String]
    ) -> TaskResult {
        TaskResult(taskID: taskID, nodeID: nodeID, status: .held, heldReasons: reasons)
    }

    public static func failed(
        taskID: TaskID,
        nodeID: NodeID,
        message: String
    ) -> TaskResult {
        TaskResult(taskID: taskID, nodeID: nodeID, status: .failed, errorMessage: message)
    }
}
