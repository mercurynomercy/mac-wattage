import CoreFoundation
import Darwin
import Foundation

/// Measured SoC power via the private (no-root) IOReport "Energy Model" group —
/// the same per-subsystem energy counters `powermetrics` reports. We sample
/// cumulative energy at two points in time and divide the delta by the elapsed
/// interval to get watts (the same technique `macmon`/`asitop` use).
///
/// Symbols are resolved at runtime from libIOReport (private framework) via
/// dlopen/dlsym — matching the dlopen idiom already used in Store.swift — so this
/// file stays self-contained and is excluded from the SPM target (Xcode-only),
/// like IOKitImplementation.swift. Every failure path returns `nil` so the caller
/// gracefully falls back to the TDP estimate.
public final class IOReportPowerReader: SoCPowerReaderProtocol {

    // MARK: - Resolved IOReport functions (nil if unavailable)

    private typealias CopyChannelsFunc = @convention(c)
        (CFString?, CFString?, UInt64, UInt64, UInt64) -> Unmanaged<CFDictionary>?
    private typealias CreateSubFunc = @convention(c)
        (UnsafeRawPointer?, CFMutableDictionary, UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>?, UInt64, CFTypeRef?) -> Unmanaged<AnyObject>?
    private typealias CreateSamplesFunc = @convention(c)
        (UnsafeRawPointer?, CFMutableDictionary, CFTypeRef?) -> Unmanaged<CFDictionary>?
    private typealias CreateDeltaFunc = @convention(c)
        (CFDictionary, CFDictionary, CFTypeRef?) -> Unmanaged<CFDictionary>?
    private typealias ChannelStringFunc = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias IntegerValueFunc = @convention(c) (CFDictionary, Int32) -> Int64

    private let createSamples: CreateSamplesFunc
    private let createDelta: CreateDeltaFunc
    private let channelName: ChannelStringFunc
    private let unitLabel: ChannelStringFunc
    private let integerValue: IntegerValueFunc

    /// IOReportSubscriptionRef — a CF type held as AnyObject so ARC releases it.
    private let subscription: AnyObject
    /// Subscribed channel set, passed to each CreateSamples call.
    private let subscribedChannels: CFMutableDictionary

    /// Previous cumulative-energy sample + its timestamp, for delta computation.
    private var previousSample: CFDictionary?
    private var previousTime: CFAbsoluteTime = 0
    private let lock = NSLock()

    // MARK: - Init

    /// Returns `nil` if libIOReport or the Energy Model group is unavailable —
    /// the app then runs entirely on the TDP estimate.
    public init?() {
        guard let handle = dlopen("/usr/lib/libIOReport.dylib", RTLD_LAZY) else { return nil }

        func sym<T>(_ name: String, as type: T.Type) -> T? {
            guard let p = dlsym(handle, name) else { return nil }
            return unsafeBitCast(p, to: T.self)
        }

        guard
            let copyChannels = sym("IOReportCopyChannelsInGroup", as: CopyChannelsFunc.self),
            let createSub = sym("IOReportCreateSubscription", as: CreateSubFunc.self),
            let createSamples = sym("IOReportCreateSamples", as: CreateSamplesFunc.self),
            let createDelta = sym("IOReportCreateSamplesDelta", as: CreateDeltaFunc.self),
            let channelName = sym("IOReportChannelGetChannelName", as: ChannelStringFunc.self),
            let unitLabel = sym("IOReportChannelGetUnitLabel", as: ChannelStringFunc.self),
            let integerValue = sym("IOReportSimpleGetIntegerValue", as: IntegerValueFunc.self)
        else { return nil }

        // Channels for the SoC energy counters.
        guard let channels = copyChannels("Energy Model" as CFString, nil, 0, 0, 0)?
            .takeRetainedValue() else { return nil }
        let desired = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, channels)

        var subbed: Unmanaged<CFMutableDictionary>?
        guard let sub = createSub(nil, desired!, &subbed, 0, nil)?.takeRetainedValue(),
              let subbedChannels = subbed?.takeRetainedValue() else { return nil }

        self.createSamples = createSamples
        self.createDelta = createDelta
        self.channelName = channelName
        self.unitLabel = unitLabel
        self.integerValue = integerValue
        self.subscription = sub
        self.subscribedChannels = subbedChannels
    }

    // MARK: - Sampling

    /// Measured SoC power (CPU+GPU+ANE, + DRAM if present) in watts since the last
    /// call. First call seeds the baseline and returns `nil`.
    public func socPowerWatts() -> Double? {
        lock.lock()
        defer { lock.unlock() }

        let subPtr = Unmanaged.passUnretained(subscription).toOpaque()
        guard let current = createSamples(subPtr, subscribedChannels, nil)?.takeRetainedValue()
        else { return nil }
        let now = CFAbsoluteTimeGetCurrent()

        defer { previousSample = current; previousTime = now }

        // Need a previous sample and a positive interval to form a delta.
        guard let previous = previousSample, now > previousTime else { return nil }
        let elapsed = now - previousTime
        guard elapsed > 0,
              let delta = createDelta(previous, current, nil)?.takeRetainedValue()
        else { return nil }

        // The delta dict exposes channels under "IOReportChannels".
        guard let dict = delta as? [String: Any],
              let items = dict["IOReportChannels"] as? [CFDictionary]
        else { return nil }

        var joules = 0.0
        for item in items {
            // ChannelName/UnitLabel are "Get" accessors — they return a borrowed (unowned)
            // reference, so use takeUnretainedValue(); takeRetainedValue() over-releases and crashes.
            guard let name = channelName(item)?.takeUnretainedValue() as String?,
                  name.lowercased().contains("energy") else { continue }
            let raw = Double(integerValue(item, 0))
            let unit = (unitLabel(item)?.takeUnretainedValue() as String?) ?? ""
            joules += raw * energyToJoules(unit: unit)
        }

        let watts = joules / elapsed
        // Guard against bogus readings (negative deltas across counter resets).
        return watts.isFinite && watts >= 0 ? watts : nil
    }

    /// Convert an IOReport energy unit label to joules.
    private func energyToJoules(unit: String) -> Double {
        switch unit.lowercased() {
        case "mj": return 1e-3
        case "uj", "µj": return 1e-6
        case "nj": return 1e-9
        case "j":  return 1.0
        default:   return 1e-9 // Energy Model defaults to nanojoules on current chips.
        }
    }
}
