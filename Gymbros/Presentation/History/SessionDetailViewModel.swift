import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.nattapongsawa.gymbros", category: "SessionDetailViewModel")

struct SessionDetailData {
    var session: WorkoutSession
    var sets: [WorkoutSet]
    var exerciseLookup: [UUID: Exercise]
}

@MainActor
@Observable
final class SessionDetailViewModel {
    let session: WorkoutSession
    var state: ViewState<SessionDetailData> = .idle
    var transientError: AppError?
    var editingSet: WorkoutSet?

    private let workoutRepository: WorkoutRepositoryProviding
    private let exerciseRepository: ExerciseRepositoryProviding

    init(
        session: WorkoutSession,
        workoutRepository: WorkoutRepositoryProviding? = nil,
        exerciseRepository: ExerciseRepositoryProviding? = nil
    ) {
        self.session = session
        self.workoutRepository = workoutRepository ?? WorkoutRepository()
        self.exerciseRepository = exerciseRepository ?? ExerciseRepository()
    }

    func updateSet(_ set: WorkoutSet, weight: Double, reps: Int, rpe: Double?) async {
        guard case var .success(data) = state else { return }
        var updated = set
        updated.weight = weight
        updated.reps = reps
        updated.rpe = rpe
        do {
            _ = try await workoutRepository.updateSet(updated)
            if let idx = data.sets.firstIndex(where: { $0.id == set.id }) {
                data.sets[idx] = updated
            }
            state = .success(data)
            editingSet = nil
        } catch {
            let appError = ProgramViewModelSupport.appError(error, operation: "updateSessionSet")
            logger.error("updateSet failed: \(String(describing: appError))")
            transientError = appError
        }
    }

    func load() async {
        logger.debug("Starting load for session \(self.session.id)")
        transientError = nil
        state = .loading

        do {
            async let setsTask = workoutRepository.fetchSets(sessionId: session.id)
            async let exercisesTask = exerciseRepository.fetchAll()

            let sets = try await setsTask
            let exercises = (try? await exercisesTask) ?? []
            let lookup = ProgramViewModelSupport.exerciseLookup(from: exercises)

            logger.debug("Load success: \(sets.count) sets")
            state = .success(SessionDetailData(session: session, sets: sets, exerciseLookup: lookup))
        } catch {
            let appError = ProgramViewModelSupport.appError(error, operation: "loadSessionDetail")
            logger.error("Load failed: \(String(describing: appError))")
            if appError == .cancelled {
                state = .idle
            } else {
                state = .error(appError)
            }
        }
    }
}

#if DEBUG
extension SessionDetailViewModel {
    static var loading: SessionDetailViewModel {
        preview(.loading)
    }

    static var error: SessionDetailViewModel {
        preview(.error(.network(.offline)))
    }

    static var success: SessionDetailViewModel {
        preview(.success(.preview))
    }

    private static func preview(_ state: ViewState<SessionDetailData>) -> SessionDetailViewModel {
        let vm = SessionDetailViewModel(session: SessionDetailPreviewData.session)
        vm.state = state
        return vm
    }
}

extension SessionDetailData {
    static var preview: SessionDetailData {
        SessionDetailData(
            session: SessionDetailPreviewData.session,
            sets: SessionDetailPreviewData.sets,
            exerciseLookup: SessionDetailPreviewData.exerciseLookup
        )
    }
}

private enum SessionDetailPreviewData {
    static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    static let userId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    static let sessionId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let benchId = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
    static let rowId = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!

    static var session: WorkoutSession {
        WorkoutSession(id: sessionId, userId: userId, programDayId: UUID(), startedAt: now.addingTimeInterval(-3600), endedAt: now, notes: nil, createdAt: now)
    }

    static var sets: [WorkoutSet] {
        [
            WorkoutSet(id: UUID(), sessionId: sessionId, exerciseId: benchId, programExerciseId: nil, setNumber: 1, weight: 60, reps: 10, rpe: 7, targetRestSeconds: nil, actualRestSeconds: nil, restStartedAt: nil, restEndedAt: nil, completedAt: now.addingTimeInterval(-3000), notes: nil),
            WorkoutSet(id: UUID(), sessionId: sessionId, exerciseId: benchId, programExerciseId: nil, setNumber: 2, weight: 60, reps: 10, rpe: 8, targetRestSeconds: nil, actualRestSeconds: nil, restStartedAt: nil, restEndedAt: nil, completedAt: now.addingTimeInterval(-2500), notes: nil),
            WorkoutSet(id: UUID(), sessionId: sessionId, exerciseId: rowId, programExerciseId: nil, setNumber: 1, weight: 40, reps: 12, rpe: nil, targetRestSeconds: nil, actualRestSeconds: nil, restStartedAt: nil, restEndedAt: nil, completedAt: now.addingTimeInterval(-2000), notes: nil)
        ]
    }

    static var exercises: [Exercise] {
        [
            Exercise(id: benchId, ownerUserId: userId, slug: "bench", name: "Bench Press", movementPattern: .push, primaryMuscle: .chest, secondaryMuscles: [], equipment: .barbell, isCompound: true, createdAt: now),
            Exercise(id: rowId, ownerUserId: userId, slug: "row", name: "Seated Row", movementPattern: .pull, primaryMuscle: .back, secondaryMuscles: [], equipment: .cable, isCompound: true, createdAt: now)
        ]
    }

    static var exerciseLookup: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }
}
#endif
