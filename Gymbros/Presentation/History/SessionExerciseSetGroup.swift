import Foundation

struct SessionExerciseSetGroup: Identifiable {
    let id: UUID
    let name: String
    let sets: [WorkoutSet]
}
