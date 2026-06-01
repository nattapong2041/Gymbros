import SwiftUI

struct RestTimerRingView: View {
    let state: RestTimerState
    var onStop: () -> Void
    var onSkip: () -> Void
    var onComplete: () -> Void = {}
    
    @State private var currentTime = Date()
    @State private var scale = 1.0
    @State private var didComplete = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var remaining: Int {
        state.remainingSeconds(at: currentTime)
    }

    private var isComplete: Bool {
        didComplete || remaining <= 0
    }
    
    private var progress: Double {
        let total = Double(state.targetSeconds)
        let elapsed = total - Double(remaining)
        return min(1.0, elapsed / total)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(.quaternary, lineWidth: 12)
                
                // Progress Ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                
                // Time Text
                VStack(spacing: 4) {
                    if isComplete {
                        Text("workout.timer.ready")
                            .font(.system(.title, design: .rounded).bold())

                        Text("workout.timer.ready_message")
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(timeString(from: remaining))
                            .font(.gymNumber(size: 44))

                        Text("workout.timer.rest")
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 200, height: 200)
            
            HStack(spacing: 20) {
                Button("workout.timer.stop", action: onStop)
                    .font(.system(.body, design: .rounded).bold())
                    .tint(.red)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("accessibility.workout.timer.stop")

                Button("workout.timer.skip", action: onSkip)
                    .font(.system(.body, design: .rounded).bold())
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("accessibility.workout.timer.skip")
            }
            .padding(.horizontal)
        }
        .padding()
        .scaleEffect(scale)
        .background(Color(.systemBackground))
        .onAppear {
            if remaining <= 0 {
                didComplete = true
                currentTime = state.endsAt
            }
        }
        .onReceive(timer) { input in
            guard didComplete == false else { return }
            currentTime = input
            if state.remainingSeconds(at: input) <= 0, didComplete == false {
                didComplete = true
                currentTime = state.endsAt
                triggerHaptic()
                triggerCompletionPulse()
                onComplete()
            }
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func triggerCompletionPulse() {
        guard UIAccessibility.isReduceMotionEnabled == false else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5).repeatCount(2, autoreverses: true)) {
            scale = 1.08
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            scale = 1.0
        }
    }
}

#Preview {
    RestTimerRingView(
        state: RestTimerState.mock,
        onStop: {},
        onSkip: {}
    )
}
