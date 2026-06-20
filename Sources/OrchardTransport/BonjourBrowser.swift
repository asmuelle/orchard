#if canImport(Network)
    import Foundation
    import Network
    import OrchardProtocol

    /// The Bonjour service type Orchard nodes advertise and browse for.
    public let orchardServiceType = "_orchard._tcp"

    /// Encodes/decodes a node's capabilities into a Bonjour TXT record, so a browsing device learns a
    /// peer's memory/tier/ANE before deciding whether to recruit it into a swarm.
    enum CapabilityTXT {
        static func encode(_ capabilities: NodeCapabilities) -> NWTXTRecord {
            var txt = NWTXTRecord()
            txt["id"] = capabilities.nodeID.value
            txt["tier"] = capabilities.tier.rawValue
            txt["mem"] = String(capabilities.usableMemoryMB)
            txt["ane"] = String(capabilities.aneGeneration)
            txt["pow"] = capabilities.isOnPower ? "1" : "0"
            return txt
        }

        static func decode(_ txt: NWTXTRecord, fallbackName: String) -> NodeCapabilities {
            NodeCapabilities(
                nodeID: NodeID(txt["id"] ?? fallbackName),
                tier: DeviceTier(rawValue: txt["tier"] ?? "") ?? .phone,
                usableMemoryMB: Double(txt["mem"] ?? "") ?? 0,
                aneGeneration: Int(txt["ane"] ?? "") ?? 0,
                isOnPower: (txt["pow"] ?? "0") == "1"
            )
        }
    }

    /// Browses the LAN for advertised Orchard services via NWBrowser. Collects results for a fixed
    /// window, then returns them as DiscoveredPeers. `@unchecked Sendable`: NWBrowser is queue-confined
    /// and the results-changed handler maps each result to a Sendable DiscoveredPeer in place rather
    /// than capturing the non-Sendable NWBrowser.Result.
    public final class BonjourBrowser: PeerBrowser, @unchecked Sendable {
        private let serviceType: String

        public init(serviceType: String = orchardServiceType) {
            self.serviceType = serviceType
        }

        public func discoverPeers(within duration: Duration) async -> [DiscoveredPeer] {
            let box = PeerBox()
            let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .tcp)
            browser.browseResultsChangedHandler = { results, _ in
                box.store(results.compactMap(Self.peer(from:)))
            }
            browser.start(queue: DispatchQueue(label: "orchard.bonjour.browser"))
            try? await Task.sleep(for: duration)
            browser.cancel()
            return box.snapshot()
        }

        private static func peer(from result: NWBrowser.Result) -> DiscoveredPeer? {
            guard case let .service(name, _, _, _) = result.endpoint else { return nil }
            var capabilities: NodeCapabilities?
            if case let .bonjour(txt) = result.metadata {
                capabilities = CapabilityTXT.decode(txt, fallbackName: name)
            }
            return DiscoveredPeer(
                nodeID: capabilities?.nodeID ?? NodeID(name),
                capabilities: capabilities,
                endpoint: result.endpoint
            )
        }
    }

    private final class PeerBox: @unchecked Sendable {
        private var peers: [DiscoveredPeer] = []
        private let lock = NSLock()

        func store(_ peers: [DiscoveredPeer]) {
            lock.lock()
            self.peers = peers
            lock.unlock()
        }

        func snapshot() -> [DiscoveredPeer] {
            lock.lock()
            defer { lock.unlock() }
            return peers
        }
    }
#endif
