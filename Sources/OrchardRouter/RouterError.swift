public enum RouterError: Error, Sendable, Hashable {
    case noNodes
    case invalidJob(String)
}
