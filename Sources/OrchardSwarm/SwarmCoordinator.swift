import OrchardProtocol

// Forms a micro-swarm to run a model. Decides the cheapest viable arrangement: if the local
// device can hold the model alone, no swarm is formed (avoid needless cross-device hops); else
// it shards across the local device plus discovered LAN peers, electing a coordinator. The
// actual layer execution / tensor transport (MLX over Network.framework) plugs in later behind
// a ShardExecutor; this type owns the formation decision.

public enum SwarmFormation: Sendable, Hashable {
    /// The local device alone can hold the model — run locally, no swarm needed.
    case soloSufficient(NodeID)
    /// A swarm was formed across multiple peers.
    case swarm(coordinator: NodeID, plan: ShardPlan)
    /// Even the combined swarm cannot hold the model.
    case insufficient(requiredMB: Double, availableMB: Double)
}

public actor SwarmCoordinator {
    private let local: NodeCapabilities
    private let discovery: PeerDiscovery
    private let planner: ShardPlanner

    public init(
        local: NodeCapabilities,
        discovery: PeerDiscovery,
        planner: ShardPlanner = ShardPlanner()
    ) {
        self.local = local
        self.discovery = discovery
        self.planner = planner
    }

    public func formSwarm(for model: ModelProfile) async -> SwarmFormation {
        let budget = local.usableMemoryMB * (1 - planner.memoryHeadroom)
        if budget >= model.totalMemoryMB {
            return .soloSufficient(local.nodeID)
        }

        let members = await combinedMembers(with: discovery.currentPeers())
        do {
            let plan = try planner.plan(model: model, across: members)
            let coordinator = CoordinatorElection.elect(among: members) ?? local.nodeID
            return .swarm(coordinator: coordinator, plan: plan)
        } catch let .insufficientMemory(requiredMB, availableMB) {
            return .insufficient(requiredMB: requiredMB, availableMB: availableMB)
        } catch {
            // noPeers / invalidModel: fall back to the local-only memory accounting.
            return .insufficient(requiredMB: model.totalMemoryMB, availableMB: budget)
        }
    }

    /// Local device plus discovered peers, de-duplicated by node id (local wins).
    private func combinedMembers(with peers: [NodeCapabilities]) -> [NodeCapabilities] {
        var seen: Set<NodeID> = [local.nodeID]
        var members = [local]
        for peer in peers where !seen.contains(peer.nodeID) {
            seen.insert(peer.nodeID)
            members.append(peer)
        }
        return members
    }
}
