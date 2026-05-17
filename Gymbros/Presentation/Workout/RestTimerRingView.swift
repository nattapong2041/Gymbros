import SwiftUI

struct RestTimerRingView: View {
    let state: RestTimerState
    var onStop: () -> Void
    var onSkip: () -> Void
    
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var remaining: Int {
        state.remainingSeconds(at: currentTime)
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
                    Text(timeString(from: remaining))
                        .font(.gymNumber(size: 44))
                    
                    Text("workout.timer.rest")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(.secondary)
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
        .background(Color(.systemBackground))
        .onReceive(timer) { input in
            currentTime = input
            if state.remainingSeconds(at: input) <= 0 {
                triggerHaptic()
                timer.upstream.connect().cancel()
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
}

#Preview {
    RestTimerRingView(
        state: RestTimerState.mock,
        onStop: {},
        onSkip: {}
    )
}
