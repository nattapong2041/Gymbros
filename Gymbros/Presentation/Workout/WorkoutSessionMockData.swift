import Foundation

extension WorkoutSessionData {
    static var mock: WorkoutSessionData {
        let sessionId = UUID()
        let userId = UUID()
        let programDayId = UUID()
        
        let benchId = UUID()
        let squatId = UUID()
        
        let bench = Exercise(
            id: benchId,
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
        
        let squat = Exercise(
            id: squatId,
            ownerUserId: userId,
            slug: "squat",
            name: "Squat",
            movementPattern: .squat,
            primaryMuscle: .quads,
            secondaryMuscles: [.glutes, .back],
            equipment: .barbell,
            isCompound: true,
            createdAt: Date()
        )
        
        let programBench = ProgramExercise(
            id: UUID(),
            programDayId: programDayId,
            exerciseId: benchId,
            targetSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetRestSeconds: 90,
            targetWeight: 60,
            exerciseOrder: 1,
            notes: "Focus on form",
            createdAt: Date()
        )
        
        let programSquat = ProgramExercise(
            id: UUID(),
            programDayId: programDayId,
            exerciseId: squatId,
            targetSets: 3,
            targetRepsMin: 5,
            targetRepsMax: 8,
            targetRestSeconds: 180,
            targetWeight: 100,
            exerciseOrder: 2,
            notes: "Deep breaths",
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
        
        let benchSets = [
            WorkoutSetRowState(
                id: UUID(),
                exerciseId: benchId,
                programExerciseId: programBench.id,
                setNumber: 1,
                weightText: "60",
                repsText: "10",
                rpe: 8.0,
                targetRestSeconds: 90,
                isCompleted: true
            ),
            WorkoutSetRowState(
                id: UUID(),
                exerciseId: benchId,
                programExerciseId: programBench.id,
                setNumber: 2,
                weightText: "60",
                repsText: "10",
                rpe: 8.5,
                targetRestSeconds: 90,
                isCompleted: true
            ),
            WorkoutSetRowState(
                id: UUID(),
                exerciseId: benchId,
                programExerciseId: programBench.id,
                setNumber: 3,
                weightText: "60",
                repsText: "10",
                rpe: 9.0,
                targetRestSeconds: 90,
                isCompleted: true
            )
        ]

        let squatSets = [
            WorkoutSetRowState(
                id: UUID(),
                exerciseId: squatId,
                programExerciseId: programSquat.id,
                setNumber: 1,
                weightText: "100",
                repsText: "5",
                rpe: 7.0,
                targetRestSeconds: 180,
                isCompleted: false
            )
        ]
        
        let sections = [
            WorkoutExerciseSection(
                programExercise: programBench,
                exercise: bench,
                sets: benchSets,
                isFinished: true,
                finishedAt: Date(),
                defaultWeight: 60
            ),
            WorkoutExerciseSection(
                programExercise: programSquat,
                exercise: squat,
                sets: squatSets,
                isFinished: false,
                finishedAt: nil,
                defaultWeight: 100
            )
        ]
        
        return WorkoutSessionData(
            session: session,
            day: day,
            exerciseSections: sections,
            exerciseLookup: [benchId: bench, squatId: squat],
            startedAt: Date(),
            currentExerciseIndex: 1
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
            startedAt: Date(),
            currentExerciseIndex: 0
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
