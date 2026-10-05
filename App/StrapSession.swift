import Combine
import DogPaceCore
import Foundation
import WhoopBLE

enum DogSize: String, CaseIterable, Identifiable {
    case small
    case large
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Small"
        case .large: return "Large"
        case .custom: return "Custom"
        }
    }
}

@MainActor
final class StrapSession: ObservableObject {
    @Published var status = "Not connected"
    @Published var deviceName = "No strap"
    @Published var isMoving = false
    @Published var motionLabel = "Still"
    @Published var movementSource = "—"
    @Published var peakCount = 0
    @Published var distanceMeters = 0.0
    @Published var sampleCount = 0
    @Published var motionNote = ""
    @Published var counting = false
    @Published var busy = false
    @Published var connected = false
    @Published var metersPerPeak = DogStride.largeMeters
    @Published var thresholdG = PaceConfig.largeDog.thresholdG
    @Published var size: DogSize = .large

    private let client = WhoopBleClient()
    private var model = PaceModel(config: .largeDog)
    private var orientation = OrientationWindow()
    private var device: WhoopDevice?
    private var imuTask: Task<Void, Never>?
    private var realtimeTask: Task<Void, Never>?
    private var missingTask: Task<Void, Never>?
    private var sawIMU = false
    private var connectGeneration = 0
    private var lastSampleTime: TimeInterval = 0
    private let defaults = UserDefaults.standard

    init() {
        if let storedSize = defaults.string(forKey: Keys.size),
           let size = DogSize(rawValue: storedSize) {
            self.size = size
        }
        if defaults.object(forKey: Keys.meters) != nil {
            metersPerPeak = defaults.double(forKey: Keys.meters)
        }
        if defaults.object(forKey: Keys.threshold) != nil {
            thresholdG = defaults.double(forKey: Keys.threshold)
        }
        applyConfig()
    }

    func select(size: DogSize) {
        self.size = size
        switch size {
        case .small:
            metersPerPeak = DogStride.smallMeters
        case .large:
            metersPerPeak = DogStride.largeMeters
        case .custom:
            break
        }
        saveConfig()
    }

    func setMeters(_ meters: Double) {
        metersPerPeak = meters
        if abs(meters - DogStride.smallMeters) < 0.001 {
            size = .small
        } else if abs(meters - DogStride.largeMeters) < 0.001 {
            size = .large
        } else {
            size = .custom
        }
        saveConfig()
    }

    func setThreshold(_ threshold: Double) {
        thresholdG = threshold
        saveConfig()
    }

    func connect() {
        guard !busy else { return }
        busy = true
        status = "Looking for a strap"
        motionNote = ""
        sawIMU = false
        connectGeneration += 1
        let generation = connectGeneration
        startListenersIfNeeded()
        Task {
            let found = await client.discover()
            guard generation == connectGeneration else { return }
            guard let found else {
                status = "No strap found"
                motionNote = "Quit the WHOOP app, then stay close to the band."
                busy = false
                return
            }
            device = found
            deviceName = found.name ?? "WHOOP"
            status = "Connecting"
            do {
                try await client.connect(to: found)
                guard generation == connectGeneration else {
                    client.disconnect()
                    return
                }
                try await client.startImuStreaming()
                guard generation == connectGeneration else {
                    client.disconnect()
                    return
                }
                try await client.requestStoredMotion()
                guard generation == connectGeneration else {
                    client.disconnect()
                    return
                }
                connected = true
                counting = true
                status = "Connected"
                busy = false
                armMissingSampleNote()
            } catch {
                status = "Connection failed"
                motionNote = error.localizedDescription
                busy = false
                connected = false
            }
        }
    }

    func disconnect() {
        connectGeneration += 1
        missingTask?.cancel()
        client.disconnect()
        connected = false
        counting = false
        busy = false
        sawIMU = false
        lastSampleTime = 0
        device = nil
        deviceName = "No strap"
        status = "Not connected"
        movementSource = "—"
        isMoving = false
        motionLabel = "Still"
        motionNote = ""
        sampleCount = 0
        model = PaceModel(config: currentConfig())
        orientation = OrientationWindow()
        publishModel(isMoving: false, motionTitle: "Still", source: "—")
    }

    func startSession() {
        model.resetSession()
        counting = true
        if movementSource == "IMU" {
            publishModel(isMoving: model.isMoving, motionTitle: model.motion.title, source: movementSource)
        } else {
            publishModel(isMoving: isMoving, motionTitle: motionLabel, source: movementSource)
        }
    }

    func stopSession() {
        counting = false
    }

    private func startListenersIfNeeded() {
        if imuTask == nil {
            let stream = client.imuSamples()
            imuTask = Task { [weak self] in
                for await sample in stream {
                    await self?.receiveIMU(sample)
                }
            }
        }
        if realtimeTask == nil {
            let stream = client.realtimeSamples()
            realtimeTask = Task { [weak self] in
                for await sample in stream {
                    await self?.receiveRealtime(sample)
                }
            }
        }
    }

    /// Stored frames arrive as a burst. Each frame is one second at `samplesInFrame` Hz.
    /// Peak spacing has to follow that second, not the moment the burst was parsed.
    private func sampleTime(_ sample: WhoopImuSample) -> TimeInterval {
        let rate = max(sample.samplesInFrame, 1)
        let step = 1.0 / Double(rate)
        let stamped: TimeInterval
        if sample.timestampSeconds > 1_000_000_000 {
            stamped = Double(sample.timestampSeconds) + Double(sample.sampleIndex) * step
        } else {
            stamped = lastSampleTime + step
        }
        let time = stamped > lastSampleTime ? stamped : lastSampleTime + step
        lastSampleTime = time
        return time
    }

    private func receiveIMU(_ sample: WhoopImuSample) {
        sawIMU = true
        motionNote = ""
        let snapshot = model.ingest(
            time: sampleTime(sample),
            x: Double(sample.accelerometerX),
            y: Double(sample.accelerometerY),
            z: Double(sample.accelerometerZ),
            counting: counting
        )
        publishModel(isMoving: snapshot.isMoving, motionTitle: snapshot.motion.title, source: "IMU")
    }

    private func receiveRealtime(_ sample: WhoopRealtimeDataSample) {
        guard !sawIMU else { return }
        let now = ProcessInfo.processInfo.systemUptime
        orientation.add(
            time: now,
            quat: Quat(
                w: Double(sample.quaternionW),
                x: Double(sample.quaternionX),
                y: Double(sample.quaternionY),
                z: Double(sample.quaternionZ)
            )
        )
        let moving = orientation.isMoving
        publishModel(isMoving: moving, motionTitle: moving ? "Moving" : "Still", source: "orientation")
    }

    private func armMissingSampleNote() {
        missingTask?.cancel()
        missingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.showMissingSamplesIfNeeded()
        }
    }

    private func showMissingSamplesIfNeeded() {
        guard connected, !sawIMU else { return }
        motionNote = "No motion samples."
    }

    private func currentConfig() -> PaceConfig {
        PaceConfig(
            metersPerPeak: metersPerPeak,
            thresholdG: thresholdG,
            minPeakGap: 0.25
        )
    }

    private func applyConfig() {
        model.config = currentConfig()
        distanceMeters = model.distanceMeters
    }

    private func saveConfig() {
        defaults.set(size.rawValue, forKey: Keys.size)
        defaults.set(metersPerPeak, forKey: Keys.meters)
        defaults.set(thresholdG, forKey: Keys.threshold)
        applyConfig()
    }

    private func publishModel(isMoving: Bool, motionTitle: String, source: String) {
        self.isMoving = isMoving
        motionLabel = motionTitle
        movementSource = source
        peakCount = model.peakCount
        distanceMeters = model.distanceMeters
        sampleCount = model.sampleCount
    }

    private enum Keys {
        static let size = "dogpace.size"
        static let meters = "dogpace.metersPerPeak"
        static let threshold = "dogpace.thresholdG"
    }
}
