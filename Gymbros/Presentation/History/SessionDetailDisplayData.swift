import Foundation

struct SessionDetailDisplayData {
    var session: WorkoutSession
    var sets: [WorkoutSet]
    var exerciseLookup: [UUID: Exercise]
}
