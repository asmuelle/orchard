#if canImport(Network)
    import Foundation
    import Network

    // A thin async wrapper over a single NWConnection. `@unchecked Sendable` because NWConnection is
    // not Sendable, but all access is serialized on its own dispatch queue and the callback→async
    // bridges below capture only Sendable values (the ResumeOnce box / continuation).

    final class TCPChannel: @unchecked Sendable {
        private let connection: NWConnection
        private let queue = DispatchQueue(label: "orchard.transport.channel")

        init(connection: NWConnection) {
            self.connection = connection
        }

        /// Connects to any endpoint — a host:port, or a Bonjour `.service(...)` endpoint discovered
        /// by `BonjourBrowser` (Network.framework resolves the service to an address).
        convenience init(endpoint: NWEndpoint) {
            self.init(connection: NWConnection(to: endpoint, using: .tcp))
        }

        func start() async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let once = ResumeOnce(continuation)
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready: once.resume(returning: ())
                    case let .failed(error): once.resume(throwing: error)
                    case .cancelled: once.resume(throwing: TransportError.connectionClosed)
                    default: break
                    }
                }
                connection.start(queue: queue)
            }
        }

        func send(_ data: Data) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                })
            }
        }

        /// Receives exactly `count` bytes (blocking until they arrive or the peer closes).
        func receive(exactly count: Int) async throws -> Data {
            guard count > 0 else { return Data() }
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data, data.count == count {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: TransportError.connectionClosed)
                    }
                }
            }
        }

        func close() {
            connection.cancel()
        }
    }
#endif
