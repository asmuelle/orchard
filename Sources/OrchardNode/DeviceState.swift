// A point-in-time snapshot of the conditions that gate opportunistic execution. The runtime
// re-reads this before every task so a device that wakes, unplugs, or heats up stops taking work.

public struct DeviceState: Sendable, Equatable {
    public var isPluggedIn: Bool
    public var isOnWiFi: Bool
    public var isIdle: Bool
    public var isThermalNominal: Bool
    /// 0.0 – 1.0.
    public var batteryLevel: Double

    public init(
        isPluggedIn: Bool,
        isOnWiFi: Bool,
        isIdle: Bool,
        isThermalNominal: Bool = true,
        batteryLevel: Double = 1.0
    ) {
        self.isPluggedIn = isPluggedIn
        self.isOnWiFi = isOnWiFi
        self.isIdle = isIdle
        self.isThermalNominal = isThermalNominal
        self.batteryLevel = batteryLevel
    }

    /// An ideal "overnight, charging, on Wi-Fi, idle" state.
    public static let ready = DeviceState(
        isPluggedIn: true,
        isOnWiFi: true,
        isIdle: true,
        isThermalNominal: true,
        batteryLevel: 1.0
    )
}

/// Supplies the current device state. On a real device this is backed by ProcessInfo /
/// power & network monitors; tests inject a deterministic provider.
public protocol DeviceConditionsProvider: Sendable {
    func currentState() async -> DeviceState
}

/// A fixed-state provider for tests, previews, and the demo executable.
public struct StaticConditionsProvider: DeviceConditionsProvider {
    public let state: DeviceState

    public init(_ state: DeviceState) {
        self.state = state
    }

    public func currentState() async -> DeviceState {
        state
    }
}
