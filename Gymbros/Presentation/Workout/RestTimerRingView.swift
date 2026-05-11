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
                    .stroke(Color.gymSurface, lineWidth: 12)
                
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
                Button(action: onStop) {
                    Text("workout.timer.stop")
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.gymSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("accessibility.workout.timer.stop")
                
                Button(action: onSkip) {
                    Text("workout.timer.skip")
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("accessibility.workout.timer.skip")
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.gymBackground)
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
