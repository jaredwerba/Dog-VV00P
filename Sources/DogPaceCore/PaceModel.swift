import Foundation

/// Meters per counted peak for the two size groups in Kim, Kazmierczak, and Breur,
/// Am J Vet Res 2011;72:1171–7. Those papers measured one paw's stride at a walk.
/// A harness peak may fire once or twice per that stride, so the slider stays editable.
public enum DogStride {
    public static let smallMeters = 0.37
    public static let largeMeters = 0.83
}

/// Published mean dynamic vector magnitudes from Karimjee, Harron, Piercy, and Daley,
/// R Soc Open Sci. 2024;11:240119. Collar Axivity, gravity removed.
/// DogMove (Vehkaoja et al., Mendeley 10.17632/vxhx934tbn) names galloping as its own class.
/// That paper has no gallop mean, so a mean above the published trot mean is Galloping.
public enum CanineActivity {
    public static let lieMeanG = 0.02
    public static let sitMeanG = 0.08
    public static let standMeanG = 0.13
    public static let walkMeanG = 0.26
    public static let trotMeanG = 0.59

    public static let sitCutG = (lieMeanG + sitMeanG) / 2
    public static let standCutG = (sitMeanG + standMeanG) / 2
    public static let walkCutG = (standMeanG + walkMeanG) / 2
    public static let trotCutG = (walkMeanG + trotMeanG) / 2

    public static func classify(meanDynamicG: Double, walkOnsetG: Double) -> CanineMotion {
        if meanDynamicG <= walkOnsetG {
            if meanDynamicG <= sitCutG { return .lying }
            if meanDynamicG <= standCutG { return .sitting }
            return .standing
        }
        if meanDynamicG <= trotCutG { return .walking }
        if meanDynamicG <= trotMeanG { return .trotting }
        return .galloping
    }
}

public enum CanineMotion: String, Equatable, Sendable {
    case lying
    case sitting
    case standing
    case walking
    case trotting
    case galloping

    public var title: String {
        switch self {
        case .lying: return "Lying"
        case .sitting: return "Sitting"
        case .standing: return "Standing"
        case .walking: return "Walking"
        case .trotting: return "Trotting"
        case .galloping: return "Galloping"
        }
    }

    /// Distance uses walk, trot, and gallop. Lie, sit, and stand do not add peaks.
    public var countsDistance: Bool {
        switch self {
        case .walking, .trotting, .galloping:
            return true
        case .lying, .sitting, .standing:
            return false
        }
    }
}

public struct PaceConfig: Equatable, Sendable {
    public var metersPerPeak: Double
    /// One-second mean at or below this value stays standing. The default is the
    /// midpoint of the published stand mean (0.13 g) and walk mean (0.26 g).
    public var thresholdG: Double
    public var minPeakGap: TimeInterval

    public init(metersPerPeak: Double, thresholdG: Double, minPeakGap: TimeInterval) {
        self.metersPerPeak = metersPerPeak
        self.thresholdG = thresholdG
        self.minPeakGap = minPeakGap
    }

    public static let largeDog = PaceConfig(
        metersPerPeak: DogStride.largeMeters,
        thresholdG: CanineActivity.walkCutG,
        minPeakGap: 0.25
    )

    public static let smallDog = PaceConfig(
        metersPerPeak: DogStride.smallMeters,
        thresholdG: CanineActivity.walkCutG,
        minPeakGap: 0.25
    )
}

public struct PaceSnapshot: Equatable, Sendable {
    public var peakCount: Int
    public var distanceMeters: Double
    public var isMoving: Bool
    public var motion: CanineMotion
    public var sampleCount: Int
}

/// Counts motion peaks from accelerometer samples in g.
/// Distance is peak count times `config.metersPerPeak`.
public struct PaceModel {
    public var config: PaceConfig
    public private(set) var peakCount = 0
    public private(set) var sampleCount = 0

    private var window: [(time: TimeInterval, dynamicG: Double)] = []
    private var older: Double?
    private var previous: Double?
    private var lastPeakTime: TimeInterval?

    public init(config: PaceConfig = .largeDog) {
        self.config = config
    }

    /// Clears the session count. The live sample count stays, so a dead stream is still visible.
    public mutating func resetSession() {
        peakCount = 0
        lastPeakTime = nil
        older = nil
        previous = nil
    }

    public mutating func ingest(
        time: TimeInterval,
        x: Double,
        y: Double,
        z: Double,
        counting: Bool
    ) -> PaceSnapshot {
        guard x.isFinite, y.isFinite, z.isFinite, time.isFinite else {
            return snapshot(motion: motion)
        }

        let magnitude = (x * x + y * y + z * z).squareRoot()
        let dynamic = abs(magnitude - 1)
        sampleCount += 1
        window.append((time, dynamic))
        let cutoff = time - 1
        window.removeAll { $0.time < cutoff }
        let motion = self.motion

        if counting, motion.countsDistance, let older, let previous {
            let isPeak = previous >= config.thresholdG && previous >= older && previous > dynamic
            let gap = lastPeakTime.map { time - $0 >= config.minPeakGap } ?? true
            if isPeak, gap {
                peakCount += 1
                lastPeakTime = time
            }
        }
        older = previous
        previous = dynamic
        return snapshot(motion: motion)
    }

    public var motion: CanineMotion {
        guard !window.isEmpty else { return .lying }
        let mean = window.reduce(0) { $0 + $1.dynamicG } / Double(window.count)
        return CanineActivity.classify(meanDynamicG: mean, walkOnsetG: config.thresholdG)
    }

    public var isMoving: Bool {
        motion.countsDistance
    }

    public var distanceMeters: Double {
        Double(peakCount) * config.metersPerPeak
    }

    private func snapshot(motion: CanineMotion) -> PaceSnapshot {
        PaceSnapshot(
            peakCount: peakCount,
            distanceMeters: distanceMeters,
            isMoving: motion.countsDistance,
            motion: motion,
            sampleCount: sampleCount
        )
    }
}

public struct Quat: Equatable, Sendable {
    public var w: Double
    public var x: Double
    public var y: Double
    public var z: Double

    public init(w: Double, x: Double, y: Double, z: Double) {
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }

    public func normalized() -> Quat {
        let length = (w * w + x * x + y * y + z * z).squareRoot()
        guard length > 0, length.isFinite else {
            return Quat(w: 1, x: 0, y: 0, z: 0)
        }
        return Quat(w: w / length, x: x / length, y: y / length, z: z / length)
    }
}

/// Coarse moving flag from orientation, used only when accelerometer samples are absent.
public struct OrientationWindow {
    public static let movingDegrees = 20.0
    private var samples: [(time: TimeInterval, quat: Quat)] = []

    public init() {}

    public mutating func add(time: TimeInterval, quat: Quat) {
        guard time.isFinite else { return }
        samples.append((time, quat.normalized()))
        let cutoff = time - 1
        samples.removeAll { $0.time < cutoff }
    }

    public var isMoving: Bool {
        guard let first = samples.first, let last = samples.last, samples.count >= 2 else {
            return false
        }
        return Self.degrees(from: first.quat, to: last.quat) >= Self.movingDegrees
    }

    public static func degrees(from start: Quat, to end: Quat) -> Double {
        let a = start.normalized()
        let b = end.normalized()
        let dot = abs(a.w * b.w + a.x * b.x + a.y * b.y + a.z * b.z)
        let clamped = min(1, max(0, dot))
        return 2 * acos(clamped) * 180 / .pi
    }
}
