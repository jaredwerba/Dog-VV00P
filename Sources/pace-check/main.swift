import Darwin
import DogPaceCore

let failures = PaceChecks.failures()
if failures.isEmpty {
    print("pace-check passed")
} else {
    for failure in failures {
        print("FAIL \(failure)")
    }
    exit(1)
}
