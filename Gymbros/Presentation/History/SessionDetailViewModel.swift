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

    func load() async {
        logger.debug("Starting load for session \(self.session.id)")
        transientError = nil
        state = .loading
        do {
            async let setsTask = workoutRepository.fetchSets(sessionId: session.id)
            async let exercisesTask = exerciseRepository.fetchAll()

            let sets = try await setsTask
            let exercises = (try? await exercisesTask) ?? []

            logger.debug("Load success — \(sets.count) sets")
            let lookup = ProgramViewModelSupport.exerciseLookup(from: exercises)
            state = .success(SessionDetailData(session: session, sets: sets, exerciseLookup: lookup))
        } catch {
            logger.error("Load failed: \(error.localizedDescription)")
            let appError = ProgramViewModelSupport.appError(error, operation: "loadSessionDetail")
            if appError == .cancelled {
                logger.debug("Load cancelled.")
                state = .idle
            } else {
                state = .error(appError)
            }
        }
    }
}
