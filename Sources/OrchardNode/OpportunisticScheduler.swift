// The gate that protects battery health and respects OS background limits: heavy work runs
// only when the device is plugged in, on Wi-Fi, idle, and thermally nominal. This is pure,
// synchronous decision logic — trivially testable and free of side effects.

public struct SchedulerPolicy: Sendable, Equatable {
    public var requirePower: Bool
    public var requireWiFi: Bool
    public var requireIdle: Bool
    public var requireNominalThermal: Bool
    /// Minimum battery level to take work even while plugged in (defends against a device
    /// that reports "plugged in" but is draining faster than it charges).
    public var minimumBatteryLevel: Double

    public init(
        requirePower: Bool = true,
        requireWiFi: Bool = true,
        requireIdle: Bool = true,
        requireNominalThermal: Bool = true,
        minimumBatteryLevel: Double = 0.5
    ) {
        self.requirePower = requirePower
        self.requireWiFi = requireWiFi
        self.requireIdle = requireIdle
        self.requireNominalThermal = requireNominalThermal
        self.minimumBatteryLevel = minimumBatteryLevel
    }

    public static let `default` = SchedulerPolicy()
}

public enum HoldReason: String, Sendable, Equatable {
    case notPluggedIn
    case notOnWiFi
    case notIdle
    case thermalThrottled
    case batteryTooLow
}

public enum SchedulingDecision: Sendable, Equatable {
    case run
    case hold(reasons: [HoldReason])

    public var canRun: Bool {
        if case .run = self { return true }
        return false
    }
}

public struct OpportunisticScheduler: Sendable {
    public let policy: SchedulerPolicy

    public init(policy: SchedulerPolicy = .default) {
        self.policy = policy
    }

    /// Decides whether the node may take work given the current device state.
    public func decide(for state: DeviceState) -> SchedulingDecision {
        var reasons: [HoldReason] = []
        if policy.requirePower, !state.isPluggedIn { reasons.append(.notPluggedIn) }
        if policy.requireWiFi, !state.isOnWiFi { reasons.append(.notOnWiFi) }
        if policy.requireIdle, !state.isIdle { reasons.append(.notIdle) }
        if policy.requireNominalThermal, !state.isThermalNominal { reasons.append(.thermalThrottled) }
        if state.batteryLevel < policy.minimumBatteryLevel { reasons.append(.batteryTooLow) }
        return reasons.isEmpty ? .run : .hold(reasons: reasons)
    }
}
