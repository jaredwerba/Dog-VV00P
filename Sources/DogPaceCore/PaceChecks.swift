import Foundation

/// Shared checks for the command-line runner and the XCTest target.
public enum PaceChecks {
    public static func failures() -> [String] {
        var failures: [String] = []
        func expect(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }

        let still = hold(PaceModel(config: .largeDog), dynamicG: 0, from: 0, until: 1)
        expect(still.peakCount == 0, "still samples counted peaks")
        expect(still.motion == .lying, "gravity looked like \(still.motion)")
        expect(still.isMoving == false, "still samples looked like movement")
        expect(still.distanceMeters == 0, "still samples produced distance")

        expect(hold(PaceModel(config: .largeDog), dynamicG: 0.08, from: 0, until: 1).motion == .sitting, "sit mean was not sitting")
        expect(hold(PaceModel(config: .largeDog), dynamicG: 0.13, from: 0, until: 1).motion == .standing, "stand mean was not standing")
        expect(hold(PaceModel(config: .largeDog), dynamicG: 0.26, from: 0, until: 1).motion == .walking, "walk mean was not walking")
        expect(hold(PaceModel(config: .largeDog), dynamicG: 0.50, from: 0, until: 1).motion == .trotting, "trot band was not trotting")
        expect(hold(PaceModel(config: .largeDog), dynamicG: 0.80, from: 0, until: 1).motion == .galloping, "above the trot mean was not galloping")

        var standing = PaceModel(config: .largeDog)
        _ = hold(&standing, dynamicG: CanineActivity.standMeanG, from: 0, until: 1)
        let fidget = spike(into: &standing, at: 1.2, baseline: CanineActivity.standMeanG, crest: 0.50)
        expect(fidget.motion == .standing, "a stand fidget became \(fidget.motion)")
        expect(fidget.peakCount == 0, "a stand fidget counted a peak")

        var walking = PaceModel(config: .largeDog)
        _ = hold(&walking, dynamicG: CanineActivity.walkMeanG, from: 0, until: 1)
        var walkSnapshot = walkingSnapshot()
        for peakTime in [1.4, 1.9, 2.4, 2.9] {
            walkSnapshot = spike(into: &walking, at: peakTime, baseline: CanineActivity.walkMeanG, crest: 0.50)
        }
        expect(walkSnapshot.motion == .walking, "walk peaks were labeled \(walkSnapshot.motion)")
        expect(walkSnapshot.peakCount == 4, "walk peaks were \(walkSnapshot.peakCount), expected 4")
        expect(abs(walkSnapshot.distanceMeters - 3.32) < 0.001, "large-dog distance was \(walkSnapshot.distanceMeters)")

        walking.config.metersPerPeak = DogStride.smallMeters
        expect(abs(walking.distanceMeters - 1.48) < 0.001, "small-dog distance did not follow the slider")

        var bounced = PaceModel(config: .largeDog)
        _ = hold(&bounced, dynamicG: CanineActivity.walkMeanG, from: 0, until: 1)
        _ = spike(into: &bounced, at: 1.4, baseline: CanineActivity.walkMeanG, crest: 0.50)
        let held = spike(into: &bounced, at: 1.50, baseline: CanineActivity.walkMeanG, crest: 0.50)
        expect(held.peakCount == 1, "a bounce inside 0.25 s counted as another peak")
        let next = spike(into: &bounced, at: 2.0, baseline: CanineActivity.walkMeanG, crest: 0.50)
        expect(next.peakCount == 2, "a later peak was dropped")

        var paused = PaceModel(config: .largeDog)
        _ = hold(&paused, dynamicG: CanineActivity.walkMeanG, from: 0, until: 1)
        let ignored = spike(into: &paused, at: 1.4, baseline: CanineActivity.walkMeanG, crest: 0.50, counting: false)
        expect(ignored.peakCount == 0, "peaks counted while the session was stopped")

        let plateau = hold(PaceModel(config: .largeDog), dynamicG: 0.40, from: 0, until: 1)
        expect(plateau.motion == .walking, "a walk-level plateau was \(plateau.motion)")
        expect(plateau.isMoving, "a walk-level plateau was not moving")
        expect(plateau.peakCount == 0, "a flat acceleration counted peaks")

        var turned = OrientationWindow()
        turned.add(time: 0, quat: Quat(w: 1, x: 0, y: 0, z: 0))
        turned.add(time: 0.2, quat: Quat(w: 1, x: 0, y: 0, z: 0))
        expect(turned.isMoving == false, "a steady orientation looked like movement")
        turned.add(time: 0.4, quat: Quat(w: 0.70710678118, x: 0, y: 0, z: 0.70710678118))
        expect(turned.isMoving, "a quarter turn was ignored")

        return failures
    }

    private static func walkingSnapshot() -> PaceSnapshot {
        PaceSnapshot(peakCount: 0, distanceMeters: 0, isMoving: false, motion: .lying, sampleCount: 0)
    }

    private static func hold(
        _ model: PaceModel,
        dynamicG: Double,
        from start: TimeInterval,
        until end: TimeInterval
    ) -> PaceSnapshot {
        var model = model
        return hold(&model, dynamicG: dynamicG, from: start, until: end)
    }

    private static func hold(
        _ model: inout PaceModel,
        dynamicG: Double,
        from start: TimeInterval,
        until end: TimeInterval,
        counting: Bool = true
    ) -> PaceSnapshot {
        var snapshot = walkingSnapshot()
        var time = start
        while time <= end + 0.000_001 {
            snapshot = model.ingest(time: time, x: 0, y: 0, z: 1 + dynamicG, counting: counting)
            time += 0.02
        }
        return snapshot
    }

    private static func spike(
        into model: inout PaceModel,
        at time: TimeInterval,
        baseline: Double,
        crest: Double,
        counting: Bool = true
    ) -> PaceSnapshot {
        _ = model.ingest(time: time - 0.02, x: 0, y: 0, z: 1 + baseline, counting: counting)
        _ = model.ingest(time: time, x: 0, y: 0, z: 1 + crest, counting: counting)
        return model.ingest(time: time + 0.02, x: 0, y: 0, z: 1 + baseline, counting: counting)
    }
}
