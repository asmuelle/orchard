#if canImport(Network)
    import Foundation
    import OrchardProtocol
    import OrchardSwarm
    @testable import OrchardTransport
    import Testing

    struct BonjourTests {
        private let model = ShardableModel.deterministic(dimension: 8, layerCount: 4, seed: 3)
        private let input = [Float](repeating: 0.1, count: 8)

        private func approxEqual(_ a: [Float], _ b: [Float], tol: Float = 1e-5) -> Bool {
            a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) <= tol }
        }

        @Test("Capabilities round-trip through a Bonjour TXT record")
        func capabilityTXTRoundTrips() {
            let capabilities = NodeCapabilities(
                nodeID: NodeID("mac-studio"),
                tier: .desktop,
                usableMemoryMB: 32000,
                aneGeneration: 18,
                isOnPower: true
            )
            let decoded = CapabilityTXT.decode(CapabilityTXT.encode(capabilities), fallbackName: "x")
            #expect(decoded == capabilities)
        }

        @Test("A discovered peer drives a RemoteShardExecutor end to end")
        func discoveredPeerExecutes() async throws {
            let service = ShardService(executor: LocalShardExecutor(), model: model)
            let port = try await service.start()
            defer { Task { await service.stop() } }

            // Discovery is behind a protocol; StaticPeerBrowser stands in for Bonjour so this stays
            // deterministic in CI. The discovered peer flows straight into the executor.
            let browser = StaticPeerBrowser([DiscoveredPeer(nodeID: NodeID("peer"), port: port)])
            let peer = try #require(await browser.discoverPeers(within: .milliseconds(1)).first)

            let overTCP = try await RemoteShardExecutor(peer: peer).execute(
                layerRange: 0 ..< 4, of: model, input: input
            )
            let local = try await LocalShardExecutor().execute(layerRange: 0 ..< 4, of: model, input: input)
            #expect(approxEqual(overTCP, local))
        }

        /// Live mDNS: advertise a service, discover it via NWBrowser, connect, execute. Gated off by
        /// default — multicast in CI sandboxes is unreliable. Run locally with ORCHARD_LIVE_BONJOUR=1
        /// (see `just bonjour-test`).
        @Test(
            "Live Bonjour: advertise → discover → connect → execute",
            .enabled(if: ProcessInfo.processInfo.environment["ORCHARD_LIVE_BONJOUR"] != nil)
        )
        func liveBonjourDiscovery() async throws {
            let capabilities = NodeCapabilities(
                nodeID: NodeID("live-node-\(UInt16.random(in: 1000 ... 9999))"),
                tier: .desktop,
                usableMemoryMB: 16000,
                aneGeneration: 18,
                isOnPower: true
            )
            let service = ShardService(executor: LocalShardExecutor(), model: model, advertiseAs: capabilities)
            _ = try await service.start()
            defer { Task { await service.stop() } }

            let browser = BonjourBrowser()
            let peers = await browser.discoverPeers(within: .seconds(4))
            let peer = try #require(peers.first { $0.nodeID == capabilities.nodeID })

            // Core guarantee: the discovered endpoint drives a working remote executor over the LAN.
            let overTCP = try await RemoteShardExecutor(peer: peer).execute(
                layerRange: 0 ..< 4, of: model, input: input
            )
            let local = try await LocalShardExecutor().execute(layerRange: 0 ..< 4, of: model, input: input)
            #expect(approxEqual(overTCP, local))

            // TXT metadata delivery through NWBrowser is environment-dependent; when present it must
            // be correct. (Capability encode/decode itself is covered by `capabilityTXTRoundTrips`.)
            if let memory = peer.capabilities?.usableMemoryMB {
                #expect(memory == 16000)
            }
        }
    }
#endif
