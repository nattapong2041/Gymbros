import Foundation

enum ProgramSamples {
    static let userId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let programId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let upperDayId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let lowerDayId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let benchExerciseId = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let squatExerciseId = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    static let benchProgramExerciseId = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    static let squatProgramExerciseId = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
    static let machineChestPressExerciseId = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!

    static let createdAt = Date(timeIntervalSince1970: 1_778_342_400)

    static var program: Program {
        var program = Program(
            id: programId,
            userId: userId,
            name: "Upper/Lower 4 Day",
            description: "Sample program for previews",
            isActive: true,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        program.days = days
        return program
    }

    static var programs: [Program] {
        [program]
    }

    static var days: [ProgramDay] {
        var upper = ProgramDay(id: upperDayId, programId: programId, name: "Upper A", dayOrder: 0, createdAt: createdAt)
        upper.exercises = [benchProgramExercise]

        var lower = ProgramDay(id: lowerDayId, programId: programId, name: "Lower A", dayOrder: 1, createdAt: createdAt)
        lower.exercises = [squatProgramExercise]

        return [upper, lower]
    }

    static var exercises: [Exercise] {
        [benchPress, backSquat, machineChestPress]
    }

    static var exerciseLookup: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    static var detailData: ProgramDetailData {
        ProgramDetailData(program: program, days: days, exerciseLookup: exerciseLookup)
    }

    static var dayBuilderData: DayBuilderData {
        DayBuilderData(day: days[0], programExercises: [benchProgramExercise], exerciseLookup: exerciseLookup)
    }

    static var benchPress: Exercise {
        Exercise(
            id: benchExerciseId,
            ownerUserId: nil,
            slug: "bench_press",
            name: "Bench Press",
            movementPattern: .push,
            primaryMuscle: .chest,
            secondaryMuscles: [.shoulders, .triceps],
            equipment: .barbell,
            isCompound: true,
            createdAt: createdAt
        )
    }

    static var backSquat: Exercise {
        Exercise(
            id: squatExerciseId,
            ownerUserId: nil,
            slug: "back_squat",
            name: "Back Squat",
            movementPattern: .squat,
            primaryMuscle: .quads,
            secondaryMuscles: [.glutes, .hamstrings],
            equipment: .barbell,
            isCompound: true,
            createdAt: createdAt
        )
    }

    static var machineChestPress: Exercise {
        Exercise(
            id: machineChestPressExerciseId,
            ownerUserId: nil,
            slug: "machine_chest_press",
            name: "Machine Chest Press",
            movementPattern: .push,
            primaryMuscle: .chest,
            secondaryMuscles: [.shoulders, .triceps],
            equipment: .machine,
            isCompound: true,
            createdAt: createdAt
        )
    }

    static var benchProgramExercise: ProgramExercise {
        ProgramExercise(
            id: benchProgramExerciseId,
            programDayId: upperDayId,
            exerciseId: benchExerciseId,
            targetSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetRestSeconds: 90,
            targetWeight: 60,
            exerciseOrder: 0,
            notes: "Pause first rep",
            createdAt: createdAt
        )
    }

    static var squatProgramExercise: ProgramExercise {
        ProgramExercise(
            id: squatProgramExerciseId,
            programDayId: lowerDayId,
            exerciseId: squatExerciseId,
            targetSets: 3,
            targetRepsMin: 5,
            targetRepsMax: 8,
            targetRestSeconds: 120,
            targetWeight: nil,
            exerciseOrder: 0,
            notes: nil,
            createdAt: createdAt
        )
    }
}
