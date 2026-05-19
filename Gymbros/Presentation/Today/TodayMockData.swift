#if DEBUG
import Foundation

enum TodayMockData {
    static let morning = Date(timeIntervalSince1970: 1_778_367_600)
    static let afternoon = Date(timeIntervalSince1970: 1_778_396_400)
    static let evening = Date(timeIntervalSince1970: 1_778_414_400)

    static var activeProgram: Program {
        ProgramSamples.program
    }

    static var upperDay: ProgramDay {
        var day = ProgramSamples.days[0]
        day.exercises = [
            ProgramSamples.benchProgramExercise,
            accessoryExercise(programDayId: day.id, order: 1, sets: 3, repsMin: 10, repsMax: 12, restSeconds: 75),
            accessoryExercise(programDayId: day.id, order: 2, sets: 2, repsMin: 12, repsMax: 15, restSeconds: 60)
        ]
        return day
    }

    static var lowerDay: ProgramDay {
        var day = ProgramSamples.days[1]
        day.exercises = [
            ProgramSamples.squatProgramExercise,
            accessoryExercise(programDayId: day.id, order: 1, sets: 3, repsMin: 8, repsMax: 10, restSeconds: 90),
            accessoryExercise(programDayId: day.id, order: 2, sets: 3, repsMin: 10, repsMax: 12, restSeconds: 75)
        ]
        return day
    }

    static var lastSession: WorkoutSession {
        WorkoutSession(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            userId: ProgramSamples.userId,
            programDayId: ProgramSamples.upperDayId,
            startedAt: Date.now.addingTimeInterval(-2 * 24 * 3600),
            endedAt: Date.now.addingTimeInterval(-2 * 24 * 3600 + 3_000),
            notes: nil,
            createdAt: Date.now.addingTimeInterval(-2 * 24 * 3600)
        )
    }

    static var olderSession: WorkoutSession {
        WorkoutSession(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            userId: ProgramSamples.userId,
            programDayId: ProgramSamples.lowerDayId,
            startedAt: Date.now.addingTimeInterval(-9 * 24 * 3600),
            endedAt: Date.now.addingTimeInterval(-9 * 24 * 3600 + 2_700),
            notes: nil,
            createdAt: Date.now.addingTimeInterval(-9 * 24 * 3600)
        )
    }

    private static func accessoryExercise(
        programDayId: UUID,
        order: Int,
        sets: Int,
        repsMin: Int,
        repsMax: Int,
        restSeconds: Int
    ) -> ProgramExercise {
        ProgramExercise(
            id: UUID(),
            programDayId: programDayId,
            exerciseId: UUID(),
            targetSets: sets,
            targetRepsMin: repsMin,
            targetRepsMax: repsMax,
            targetRestSeconds: restSeconds,
            targetWeight: nil,
            exerciseOrder: order,
            notes: nil,
            createdAt: ProgramSamples.createdAt
        )
    }
}

extension TodayViewData {
    static var noProgram: TodayViewData {
        TodayViewData(
            activeProgram: nil,
            nextDay: nil,
            recentSessions: [],
            streakWeeks: 0,
            lastSessionDate: nil,
            isWelcomeBack: false
        )
    }

    static var hasProgramNoHistory: TodayViewData {
        TodayViewData(
            activeProgram: TodayMockData.activeProgram,
            nextDay: TodayMockData.upperDay,
            recentSessions: [],
            streakWeeks: 0,
            lastSessionDate: nil,
            isWelcomeBack: true
        )
    }

    static var hasProgramWithStreak: TodayViewData {
        TodayViewData(
            activeProgram: TodayMockData.activeProgram,
            nextDay: TodayMockData.lowerDay,
            recentSessions: [TodayMockData.lastSession],
            streakWeeks: 3,
            lastSessionDate: TodayMockData.lastSession.startedAt,
            isWelcomeBack: false
        )
    }

    static var welcomeBack: TodayViewData {
        TodayViewData(
            activeProgram: TodayMockData.activeProgram,
            nextDay: TodayMockData.upperDay,
            recentSessions: [TodayMockData.olderSession],
            streakWeeks: 0,
            lastSessionDate: TodayMockData.olderSession.startedAt,
            isWelcomeBack: true
        )
    }
}
#endif
