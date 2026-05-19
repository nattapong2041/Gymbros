import Foundation

#if DEBUG
extension HistoryDisplayData {
    static var mock: HistoryDisplayData {
        HistoryDisplayData(
            sessions: [
                SessionDetailDisplayData.pushSession.session,
                SessionDetailDisplayData.legsSession.session,
                SessionDetailDisplayData.customSession.session
            ],
            dayNames: [
                HistoryMockData.pushDayId: "Push Day A",
                HistoryMockData.legsDayId: "Legs Day"
            ],
            detailStates: [
                SessionDetailDisplayData.pushSession.session.id: .success(.pushSession),
                SessionDetailDisplayData.legsSession.session.id: .success(.legsSession),
                SessionDetailDisplayData.customSession.session.id: .success(.customSession)
            ]
        )
    }
}

extension SessionDetailDisplayData {
    static var mock: SessionDetailDisplayData {
        pushSession
    }

    static var pushSession: SessionDetailDisplayData {
        let sessionId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let session = WorkoutSession(
            id: sessionId,
            userId: HistoryMockData.userId,
            programDayId: HistoryMockData.pushDayId,
            startedAt: HistoryMockData.now.addingTimeInterval(-2 * 24 * 60 * 60 - 48 * 60),
            endedAt: HistoryMockData.now.addingTimeInterval(-2 * 24 * 60 * 60),
            notes: nil,
            createdAt: HistoryMockData.now.addingTimeInterval(-2 * 24 * 60 * 60 - 48 * 60)
        )

        return SessionDetailDisplayData(
            session: session,
            sets: [
                HistoryMockData.set(sessionId: sessionId, exerciseId: HistoryMockData.benchId, setNumber: 1, weight: 60, reps: 10, rpe: 7.5, minutesAgo: 47),
                HistoryMockData.set(sessionId: sessionId, exerciseId: HistoryMockData.benchId, setNumber: 2, weight: 62.5, reps: 8, rpe: 8, minutesAgo: 43),
                HistoryMockData.set(sessionId: sessionId, exerciseId: HistoryMockData.rowId, setNumber: 1, weight: 42.5, reps: 12, rpe: 7, minutesAgo: 36),
                HistoryMockData.set(sessionId: sessionId, exerciseId: HistoryMockData.rowId, setNumber: 2, weight: 42.5, reps: 11, rpe: nil, minutesAgo: 32),
                HistoryMockData.set(sessionId: sessionId, exerciseId: HistoryMockData.unknownExerciseId, setNumber: 1, weight: 12, reps: 15, rpe: 6.5, minutesAgo: 26)
            ],
            exerciseLookup: [
                HistoryMockData.benchId: HistoryMockData.bench,
                HistoryMockData.rowId: HistoryMockData.row
            ]
        )
    }

    static var legsSession: SessionDetailDisplayData {
        let sessionId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let session = WorkoutSession(
            id: sessionId,
            userId: HistoryMockData.userId,
            programDayId: HistoryMockData.legsDayId,
            startedAt: HistoryMockData.now.addingTimeInterval(-5 * 24 * 60 * 60 - 54 * 60),
            endedAt: HistoryMockData.now.addingTimeInterval(-5 * 24 * 60 * 60),
            notes: nil,
            createdAt: HistoryMockData.now.addingTimeInterval(-5 * 24 * 60 * 60 - 54 * 60)
        )

        return SessionDetailDisplayData(
            session: session,
            sets: [
                HistoryMockData.set(sessionId: sessionId, exerciseId: HistoryMockData.squatId, setNumber: 1, weight: 95, reps: 5, rpe: 7, minutesAgo: 53),
                HistoryMockData.set(sessionId: sessionId, exerciseId: HistoryMockData.squatId, setNumber: 2, weight: 95, reps: 5, rpe: 7.5, minutesAgo: 49),
                HistoryMockData.set(sessionId: sessionId, exerciseId: HistoryMockData.squatId, setNumber: 3, weight: 95, reps: 5, rpe: 8, minutesAgo: 45)
            ],
            exerciseLookup: [
                HistoryMockData.squatId: HistoryMockData.squat
            ]
        )
    }

    static var customSession: SessionDetailDisplayData {
        let sessionId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let session = WorkoutSession(
            id: sessionId,
            userId: HistoryMockData.userId,
            programDayId: nil,
            startedAt: HistoryMockData.now.addingTimeInterval(-9 * 24 * 60 * 60 - 35 * 60),
            endedAt: HistoryMockData.now.addingTimeInterval(-9 * 24 * 60 * 60),
            notes: nil,
            createdAt: HistoryMockData.now.addingTimeInterval(-9 * 24 * 60 * 60 - 35 * 60)
        )

        return SessionDetailDisplayData(
            session: session,
            sets: [
                HistoryMockData.set(sessionId: sessionId, exerciseId: HistoryMockData.rowId, setNumber: 1, weight: 40, reps: 12, rpe: nil, minutesAgo: 34)
            ],
            exerciseLookup: [
                HistoryMockData.rowId: HistoryMockData.row
            ]
        )
    }
}

enum HistoryMockData {
    static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    static let userId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    static let pushDayId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    static let legsDayId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    static let benchId = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
    static let rowId = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
    static let squatId = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    static let unknownExerciseId = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!

    static let bench = Exercise(
        id: benchId,
        ownerUserId: userId,
        slug: "bench-press",
        name: "Bench Press",
        movementPattern: .push,
        primaryMuscle: .chest,
        secondaryMuscles: [.shoulders, .triceps],
        equipment: .barbell,
        isCompound: true,
        createdAt: now
    )

    static let row = Exercise(
        id: rowId,
        ownerUserId: userId,
        slug: "seated-cable-row",
        name: "Seated Cable Row",
        movementPattern: .pull,
        primaryMuscle: .back,
        secondaryMuscles: [.biceps],
        equipment: .cable,
        isCompound: true,
        createdAt: now
    )

    static let squat = Exercise(
        id: squatId,
        ownerUserId: userId,
        slug: "back-squat",
        name: "Back Squat",
        movementPattern: .squat,
        primaryMuscle: .quads,
        secondaryMuscles: [.glutes, .back],
        equipment: .barbell,
        isCompound: true,
        createdAt: now
    )

    static func set(
        sessionId: UUID,
        exerciseId: UUID,
        setNumber: Int,
        weight: Double,
        reps: Int,
        rpe: Double?,
        minutesAgo: TimeInterval
    ) -> WorkoutSet {
        WorkoutSet(
            id: UUID(),
            sessionId: sessionId,
            exerciseId: exerciseId,
            programExerciseId: nil,
            setNumber: setNumber,
            weight: weight,
            reps: reps,
            rpe: rpe,
            targetRestSeconds: nil,
            actualRestSeconds: nil,
            restStartedAt: nil,
            restEndedAt: nil,
            completedAt: now.addingTimeInterval(-minutesAgo * 60),
            notes: nil
        )
    }
}
#endif
