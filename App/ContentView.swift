import SwiftUI

struct ContentView: View {
    @StateObject private var session = StrapSession()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statusBlock
                    distanceBlock
                    countsBlock
                    sessionButtons
                    tuners
                    connectButtons
                }
                .padding(20)
            }
            .navigationTitle("Dog Pace")
        }
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.deviceName)
                .font(.title2.weight(.semibold))
            Text(session.status)
                .foregroundStyle(.secondary)
            if !session.motionNote.isEmpty {
                Text(session.motionNote)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var distanceBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Distance")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(distanceText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var countsBlock: some View {
        HStack(spacing: 16) {
            metric("Peaks", "\(session.peakCount)")
            metric("Movement", session.motionLabel)
            metric("Samples", "\(session.sampleCount)")
        }
    }

    private var sessionButtons: some View {
        HStack {
            Button(session.counting ? "Stop" : "Start") {
                if session.counting {
                    session.stopSession()
                } else {
                    session.startSession()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!session.connected)
            Text(session.movementSource == "—" ? "Waiting for motion" : session.movementSource)
                .foregroundStyle(.secondary)
        }
    }

    private var tuners: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dog size")
                .font(.headline)
            Picker("Dog size", selection: sizeBinding) {
                ForEach(DogSize.allCases) { size in
                    Text(size.title).tag(size)
                }
            }
            .pickerStyle(.segmented)

            labeledSlider(
                title: "Meters per peak",
                value: metersBinding,
                range: 0.15...1.5,
                format: metersText
            )
            labeledSlider(
                title: "Walk onset",
                value: thresholdBinding,
                range: 0.05...0.80,
                format: thresholdText
            )
            Text("Activity uses published collar means for lie, sit, stand, walk, and trot. Distance counts peaks during walk, trot, and gallop. After a known walk, set meters per peak to the measured distance divided by the peak count.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var connectButtons: some View {
        HStack {
            Button(session.busy ? "Connecting…" : "Connect") {
                session.connect()
            }
            .buttonStyle(.borderedProminent)
            .disabled(session.busy || session.connected)

            Button("Disconnect") {
                session.disconnect()
            }
            .disabled(!session.connected && !session.busy)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(format)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private var sizeBinding: Binding<DogSize> {
        Binding(
            get: { session.size },
            set: { session.select(size: $0) }
        )
    }

    private var metersBinding: Binding<Double> {
        Binding(
            get: { session.metersPerPeak },
            set: { session.setMeters($0) }
        )
    }

    private var thresholdBinding: Binding<Double> {
        Binding(
            get: { session.thresholdG },
            set: { session.setThreshold($0) }
        )
    }

    private var distanceText: String {
        String(format: "%.1f m", session.distanceMeters)
    }

    private var metersText: String {
        String(format: "%.2f m", session.metersPerPeak)
    }

    private var thresholdText: String {
        String(format: "%.2f g", session.thresholdG)
    }
}
