import Foundation

extension WorkoutSessionData {
    static var mock: WorkoutSessionData {
        let sessionId = UUID()
        let userId = UUID()
        let programDayId = UUID()
        let exerciseId = UUID()
        let programExerciseId = UUID()
        
        let exercise = Exercise(
            id: exerciseId,
            ownerUserId: userId,
            slug: "bench-press",
            name: "Bench Press",
            movementPattern: .push,
            primaryMuscle: .chest,
            secondaryMuscles: [.shoulders, .triceps],
            equipment: .barbell,
            isCompound: true,
            createdAt: Date()
        )
        
        let programExercise = ProgramExercise(
            id: programExerciseId,
            programDayId: programDayId,
            exerciseId: exerciseId,
            targetSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetRestSeconds: 90,
            exerciseOrder: 1,
            notes: "Keep chest up",
            createdAt: Date()
        )
        
        let session = WorkoutSession(
            id: sessionId,
            userId: userId,
            programDayId: programDayId,
            startedAt: Date(),
            createdAt: Date()
        )
        
        let day = ProgramDay(
            id: programDayId,
            programId: UUID(),
            name: "Push Day A",
            dayOrder: 1,
            createdAt: Date()
        )
        
        let sets = [
            WorkoutSetRowState(
                id: UUID(),
                exerciseId: exerciseId,
                programExerciseId: programExerciseId,
                setNumber: 1,
                weightText: "60",
                repsText: "10",
                rpe: 8.0,
                targetRestSeconds: 90,
                syncState: .uploaded,
                isCompleted: true
            ),
            WorkoutSetRowState(
                id: UUID(),
                exerciseId: exerciseId,
                programExerciseId: programExerciseId,
                setNumber: 2,
                weightText: "60",
                repsText: "9",
                rpe: 9.0,
                targetRestSeconds: 90,
                syncState: .uploading,
                isCompleted: true
            ),
            WorkoutSetRowState(
                id: UUID(),
                exerciseId: exerciseId,
                programExerciseId: programExerciseId,
                setNumber: 3,
                weightText: "60",
                repsText: "",
                rpe: nil,
                targetRestSeconds: 90,
                syncState: .pending,
                isCompleted: false
            )
        ]
        
        let section = WorkoutExerciseSection(
            programExercise: programExercise,
            exercise: exercise,
            sets: sets
        )
        
        return WorkoutSessionData(
            session: session,
            day: day,
            exerciseSections: [section],
            exerciseLookup: [exerciseId: exercise],
            startedAt: Date()
        )
    }

    static var emptyMock: WorkoutSessionData {
        let sessionId = UUID()
        let userId = UUID()
        let programDayId = UUID()
        
        let session = WorkoutSession(
            id: sessionId,
            userId: userId,
            programDayId: programDayId,
            startedAt: Date(),
            createdAt: Date()
        )
        
        let day = ProgramDay(
            id: programDayId,
            programId: UUID(),
            name: "Rest Day",
            dayOrder: 7,
            createdAt: Date()
        )
        
        return WorkoutSessionData(
            session: session,
            day: day,
            exerciseSections: [],
            exerciseLookup: [:],
            startedAt: Date()
        )
    }
}

extension RestTimerState {
    static var mock: RestTimerState {
        let now = Date()
        return RestTimerState(
            sourceSetId: UUID(),
            targetSeconds: 90,
            startedAt: now,
            endsAt: now.addingTimeInterval(90)
        )
    }
}
