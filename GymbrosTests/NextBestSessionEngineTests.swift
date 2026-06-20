import Foundation
import Testing
@testable import Gymbros

@Suite("NextBestSessionEngine")
struct NextBestSessionEngineTests {
    private let engine = NextBestSessionEngine()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Mode selection by day gap

    @Test func fourteenDayGapYieldsComebackBand() throws {
        let fixture = Fixture()
        fixture.addSession(daysAgo: 14.2, entries: [.bench(weight: 80, reps: 8, rpe: 7.0)])

        let result = recommend(fixture)

        let stage = try #require(result.stage)
        #expect(result.mode.isComeback)
        #expect(stage.weightMultiplier == 0.9)
        #expect(stage.setDelta == -1)
        #expect(result.reasonKey == "comeback.reason.14_20")
        #expect(result.gapDays == 14)
        let adjustment = try #require(result.adjustments[Fixture.benchPEId])
        #expect(adjustment.adjustedTargetWeight == 80 * 0.9)
        #expect(adjustment.adjustedSets == 2)
        #expect(adjustment.originalSets == 3)
        #expect(adjustment.baselineWeight == 80)
        #expect(adjustment.baselineReps == [8])
    }

    @Test func sevenDayGapYieldsNormal() {
        let fixture = Fixture()
        fixture.addSession(daysAgo: 7.5, entries: [.bench(weight: 80, reps: 8, rpe: 7.0)])

        let result = recommend(fixture)

        #expect(result.mode == .normal)
    }

    @Test func twoDayGapYieldsNormal() {
        let fixture = Fixture()
        fixture.addSession(daysAgo: 2, entries: [.bench(weight: 80, reps: 8, rpe: 7.0)])

        let result = recommend(fixture)

        #expect(result.mode == .normal)
    }

    @Test func emptyHistoryYieldsNormalWithFirstDay() {
        let fixture = Fixture()

        let result = recommend(fixture)

        #expect(result.mode == .normal)
        #expect(result.programDay?.id == Fixture.dayId)
    }

    @Test func noActiveProgramYieldsNormalWithNilDay() {
        let fixture = Fixture()
        fixture.addSession(daysAgo: 20, entries: [.bench(weight: 80, reps: 8, rpe: 7.0)])

        let result = engine.recommend(program: nil, history: fixture.sessions, sets: fixture.sets, now: now)

        #expect(result.mode == .normal)
        #expect(result.programDay == nil)
    }

    // MARK: - Adjustment shaping

    @Test func adjustedSetsClampToOnePreservingOriginal() throws {
        let fixture = Fixture(benchTargetSets: 1)
        fixture.addSession(daysAgo: 16, entries: [.bench(weight: 80, reps: 8, rpe: 7.0)])

        let result = recommend(fixture)

        let adjustment = try #require(result.adjustments[Fixture.benchPEId])
        #expect(adjustment.adjustedSets == 1)
        #expect(adjustment.originalSets == 1)
    }

    // MARK: - Persistent state machine

    @Test func comebackPersistsAfterFirstPostGapSession() throws {
        let fixture = Fixture()
        // 20-day gap between the pre-gap baseline session and the return session.
        fixture.addSession(daysAgo: 22.0, entries: [.bench(weight: 80, reps: 8, rpe: nil)])
        fixture.addSession(daysAgo: 1.0, entries: [.bench(weight: 72, reps: 8, rpe: 7.0)])

        let result = recommend(fixture)

        let stage = try #require(result.stage)
        #expect(result.mode.isComeback)
        #expect(stage.bandKey == "comeback.band.14_20")
        // Ramp from the post-gap weight, not a fresh baseline cut.
        let adjustment = try #require(result.adjustments[Fixture.benchPEId])
        #expect(adjustment.adjustedTargetWeight == 72 * 1.10)
        #expect(result.rampPreview[Fixture.benchPEId] == .increase(percent: 10))
    }

    @Test func oldResolvedGapDoesNotReanchorComeback() {
        let fixture = Fixture()
        fixture.addSession(daysAgo: 100, entries: [.bench(weight: 80, reps: 8, rpe: 7.0)])
        // 20-day-old gap, then continuous recent training with no further 14-day holes.
        for daysAgo in [79.0, 70.0, 60.0, 50.0, 40.0, 30.0, 20.0, 10.0, 1.0] {
            fixture.addSession(daysAgo: daysAgo, entries: [.bench(weight: 80, reps: 8, rpe: 7.0)])
        }

        let result = recommend(fixture)

        #expect(result.mode == .normal)
    }

    @Test func perExerciseRampKeepsGlobalComebackMode() throws {
        let fixture = Fixture()
        fixture.addSession(daysAgo: 20, entries: [
            .bench(weight: 80, reps: 8, rpe: 7.0),
            .squat(weight: 100, reps: 5, rpe: 7.0)
        ])
        fixture.addSession(daysAgo: 1, entries: [
            .bench(weight: 80, reps: 8, rpe: 7.0),   // back at baseline, easy → resolved
            .squat(weight: 80, reps: 5, rpe: 7.0)    // still below baseline → unresolved
        ])

        let result = recommend(fixture)

        #expect(result.mode.isComeback)
        let bench = try #require(result.adjustments[Fixture.benchPEId])
        #expect(bench.weightMultiplier == 1.0)
        #expect(bench.adjustedSets == bench.originalSets)
        let squat = try #require(result.adjustments[Fixture.squatPEId])
        #expect(squat.adjustedTargetWeight == 80 * 1.10)   // 80 + 10% ramp
        #expect(squat.adjustedSets == squat.originalSets - 1)
    }

    @Test func weightBasedExitReturnsNormal() {
        let fixture = Fixture()
        fixture.addSession(daysAgo: 20, entries: [
            .bench(weight: 80, reps: 8, rpe: 7.0),
            .squat(weight: 100, reps: 5, rpe: 7.0)
        ])
        fixture.addSession(daysAgo: 1, entries: [
            .bench(weight: 80, reps: 8, rpe: 7.0),
            .squat(weight: 100, reps: 5, rpe: 7.5)
        ])

        let result = recommend(fixture)

        #expect(result.mode == .normal)
    }

    @Test func boundedExitAfterFourPostGapSessions() {
        let fixture = Fixture()
        fixture.addSession(daysAgo: 40, entries: [.bench(weight: 80, reps: 8, rpe: 7.0)])
        for daysAgo in [10.0, 7.0, 4.0, 1.0] {
            fixture.addSession(daysAgo: daysAgo, entries: [.bench(weight: 60, reps: 8, rpe: 9.0)])
        }

        let result = recommend(fixture)

        #expect(result.mode == .normal)
    }

    // MARK: - Gap candidate pre-check

    @Test func hasGapCandidateMatchesGapDetection() {
        let recent = Fixture()
        recent.addSession(daysAgo: 2, entries: [.bench(weight: 80, reps: 8, rpe: 7.0)])
        #expect(NextBestSessionEngine.hasGapCandidate(history: recent.sessions, now: now) == false)

        let gapped = Fixture()
        gapped.addSession(daysAgo: 15, entries: [.bench(weight: 80, reps: 8, rpe: 7.0)])
        #expect(NextBestSessionEngine.hasGapCandidate(history: gapped.sessions, now: now) == true)
    }

    // MARK: - Normal-mode overload hints

    @Test func normalModeDecoratesOverloadHints() {
        let fixture = Fixture()
        fixture.addSession(daysAgo: 5, entries: [.bench(weight: 80, reps: 8, rpe: 7.5)])
        fixture.addSession(daysAgo: 2, entries: [.bench(weight: 80, reps: 8, rpe: 7.0)])

        let result = recommend(fixture)

        #expect(result.mode == .normal)
        #expect(result.overloadHints[Fixture.benchPEId] == 82.5)
    }

    // MARK: - Helpers

    private func recommend(_ fixture: Fixture) -> TodayRecommendation {
        engine.recommend(program: fixture.program, history: fixture.sessions, sets: fixture.sets, now: now)
    }
}

// MARK: - Fixture

private final class Fixture {
    static let userId = UUID(uuidString: "aaaa0000-0000-0000-0000-000000000001")!
    static let programId = UUID(uuidString: "aaaa0000-0000-0000-0000-000000000002")!
    static let dayId = UUID(uuidString: "aaaa0000-0000-0000-0000-000000000003")!
    static let benchPEId = UUID(uuidString: "aaaa0000-0000-0000-0000-000000000004")!
    static let benchExerciseId = UUID(uuidString: "aaaa0000-0000-0000-0000-000000000005")!
    static let squatPEId = UUID(uuidString: "aaaa0000-0000-0000-0000-000000000006")!
    static let squatExerciseId = UUID(uuidString: "aaaa0000-0000-0000-0000-000000000007")!

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    let program: Program
    private(set) var sessions: [WorkoutSession] = []
    private(set) var sets: [UUID: [WorkoutSet]] = [:]

    enum Entry {
        case bench(weight: Double, reps: Int, rpe: Double?)
        case squat(weight: Double, reps: Int, rpe: Double?)
    }

    init(benchTargetSets: Int = 3) {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        var day = ProgramDay(
            id: Self.dayId,
            programId: Self.programId,
            name: "Upper A",
            dayOrder: 0,
            createdAt: baseDate
        )
        day.exercises = [
            ProgramExercise(
                id: Self.benchPEId,
                programDayId: Self.dayId,
                exerciseId: Self.benchExerciseId,
                targetSets: benchTargetSets,
                targetRepsMin: 8,
                targetRepsMax: 10,
                targetRestSeconds: 90,
                targetWeight: nil,
                exerciseOrder: 0,
                notes: nil,
                createdAt: baseDate
            ),
            ProgramExercise(
                id: Self.squatPEId,
                programDayId: Self.dayId,
                exerciseId: Self.squatExerciseId,
                targetSets: 3,
                targetRepsMin: 5,
                targetRepsMax: 8,
                targetRestSeconds: 120,
                targetWeight: nil,
                exerciseOrder: 1,
                notes: nil,
                createdAt: baseDate
            )
        ]
        var program = Program(
            id: Self.programId,
            userId: Self.userId,
            name: "Test Program",
            description: nil,
            isActive: true,
            createdAt: baseDate,
            updatedAt: baseDate
        )
        program.days = [day]
        self.program = program
    }

    func addSession(daysAgo: Double, entries: [Entry]) {
        let start = now.addingTimeInterval(-daysAgo * 86_400)
        let session = WorkoutSession(
            id: UUID(),
            userId: Self.userId,
            programDayId: Self.dayId,
            startedAt: start,
            endedAt: start.addingTimeInterval(3_600),
            notes: nil,
            createdAt: start
        )
        sessions.append(session)
        sets[session.id] = entries.enumerated().map { index, entry in
            let (programExerciseId, exerciseId, weight, reps, rpe): (UUID, UUID, Double, Int, Double?)
            switch entry {
            case let .bench(w, r, rp):
                (programExerciseId, exerciseId, weight, reps, rpe) = (Self.benchPEId, Self.benchExerciseId, w, r, rp)
            case let .squat(w, r, rp):
                (programExerciseId, exerciseId, weight, reps, rpe) = (Self.squatPEId, Self.squatExerciseId, w, r, rp)
            }
            return WorkoutSet(
                id: UUID(),
                sessionId: session.id,
                exerciseId: exerciseId,
                programExerciseId: programExerciseId,
                setNumber: index + 1,
                weight: weight,
                reps: reps,
                rpe: rpe,
                targetRestSeconds: nil,
                actualRestSeconds: nil,
                restStartedAt: nil,
                restEndedAt: nil,
                completedAt: start.addingTimeInterval(600),
                notes: nil
            )
        }
    }
}
