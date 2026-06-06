import Foundation

/// Protocol abstraction for hardware metrics reads. Allows test doubles to inject mock values.
public protocol IOKitAdapterProtocol {
    /// CPU usage fraction across all cores, [0.0, 1.0]. Returns 0.0 on failure (never throws).
    func cpuUtilization() -> Double

    /// GPU usage fraction, [0.0, 1.0]. Returns 0.0 if no GPU service found (fallback).
    func gpuUtilization() -> Double

    /// Whether the Mac is currently charging. nil for desktop Macs without batteries.
    func isCharging() -> Bool?

    /// Battery charge level as a fraction [0.0, 1.0]. nil for desktop Macs without batteries.
    func batteryLevel() -> Double?
}
