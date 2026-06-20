@testable import OrchardNode
import Testing

struct SchedulerTests {
    let scheduler = OpportunisticScheduler()

    @Test("An ideal charging/idle state runs")
    func readyStateRuns() {
        #expect(scheduler.decide(for: .ready) == .run)
    }

    @Test("An unplugged device holds")
    func unpluggedHolds() {
        var state = DeviceState.ready
        state.isPluggedIn = false
        #expect(scheduler.decide(for: state) == .hold(reasons: [.notPluggedIn]))
    }

    @Test("Every unmet condition is reported")
    func multipleUnmetConditionsReported() {
        let state = DeviceState(
            isPluggedIn: false,
            isOnWiFi: false,
            isIdle: false,
            isThermalNominal: true,
            batteryLevel: 1.0
        )
        guard case let .hold(reasons) = scheduler.decide(for: state) else {
            Issue.record("expected a hold decision")
            return
        }
        #expect(Set(reasons) == [.notPluggedIn, .notOnWiFi, .notIdle])
    }

    @Test("A throttled device holds")
    func thermalThrottleHolds() {
        var state = DeviceState.ready
        state.isThermalNominal = false
        #expect(scheduler.decide(for: state) == .hold(reasons: [.thermalThrottled]))
    }

    @Test("Low battery holds even while plugged in")
    func lowBatteryHoldsEvenWhenPluggedIn() {
        var state = DeviceState.ready
        state.batteryLevel = 0.1
        #expect(scheduler.decide(for: state) == .hold(reasons: [.batteryTooLow]))
    }

    @Test("A relaxed policy can ignore Wi-Fi")
    func relaxedPolicyIgnoresWiFi() {
        let relaxed = OpportunisticScheduler(policy: SchedulerPolicy(requireWiFi: false))
        var state = DeviceState.ready
        state.isOnWiFi = false
        #expect(relaxed.decide(for: state) == .run)
    }
}
