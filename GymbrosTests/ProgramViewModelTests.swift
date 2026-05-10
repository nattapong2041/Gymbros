import Foundation
import Testing
@testable import Gymbros

@MainActor
@Suite("Program ViewModels")
struct ProgramViewModelTests {
    @Test func listLoadSortsActiveProgramFirstThenUpdatedDescending() async throws {
        let inactiveNewest = makeProgram(
            id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            name: "Newest",
            isActive: false,
            updatedAt: ProgramSamples.createdAt.addingTimeInterval(300)
        )
        let activeOldest = makeProgram(
            id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
            name: "Active",
            isActive: true,
            updatedAt: ProgramSamples.createdAt
        )
        let inactiveMiddle = makeProgram(
            id: "cccccccc-cccc-cccc-cccc-cccccccccccc",
            name: "Middle",
            isActive: false,
            updatedAt: ProgramSamples.createdAt.addingTimeInterval(200)
        )
        let repository = FakeProgramRepository(programs: [inactiveNewest, inactiveMiddle, activeOldest])
        let viewModel = ProgramListViewModel(repository: repository)

        await viewModel.loadPrograms()

        let programs = try successValue(viewModel.state)
        #expect(programs.map(\.name) == ["Active", "Newest", "Middle"])
    }

    @Test func builderRejectsBlankProgramNameWithoutRepositoryCall() async {
        let repository = FakeProgramRepository()
        let viewModel = ProgramBuilderViewModel(mode: .create, repository: repository)
        viewModel.name = " \n\t "
        viewModel.description = "Ignored"

        await viewModel.save()

        #expect(viewModel.transientError == .validation(.missingRequiredField))
        #expect(repository.createdPrograms.isEmpty)
    }

    @Test func builderTrimsNameAndSavesNilDescription() async throws {
        let repository = FakeProgramRepository()
        let viewModel = ProgramBuilderViewModel(mode: .create, repository: repository)
        viewModel.name = "  Upper Lower  "
        viewModel.description = " \n "

        await viewModel.save()

        let saved = try successValue(viewModel.state)
        #expect(saved.name == "Upper Lower")
        #expect(saved.description == nil)
        #expect(repository.createdPrograms.count == 1)
        #expect(repository.createdPrograms.first?.name == "Upper Lower")
        #expect(repository.createdPrograms.first?.description == nil)
    }

    @Test func detailRejectsBlankDayNameWithoutRepositoryCall() async {
        let repository = FakeProgramRepository()
        let viewModel = ProgramDetailViewModel(
            programId: ProgramSamples.programId,
            programRepository: repository,
            exerciseRepository: FakeExerciseRepository()
        )

        await viewModel.loadProgram()
        await viewModel.addDay(name: "  ")

        #expect(viewModel.transientError == .validation(.missingRequiredField))
        #expect(repository.createdDays.isEmpty)
    }

    @Test func detailMoveDaysPersistsDenseZeroBasedOrder() async throws {
        let repository = FakeProgramRepository()
        let viewModel = ProgramDetailViewModel(
            programId: ProgramSamples.programId,
            programRepository: repository,
            exerciseRepository: FakeExerciseRepository()
        )

        await viewModel.loadProgram()
        await viewModel.moveDays(from: IndexSet(integer: 0), to: 2)

        let reorderedDays = try #require(repository.reorderedDays.last)
        #expect(reorderedDays.map(\.id) == [ProgramSamples.lowerDayId, ProgramSamples.upperDayId])
        #expect(reorderedDays.map(\.dayOrder) == [0, 1])
    }

    @Test func dayBuilderRejectsInvalidExercisePrescriptionWithoutRepositoryCall() async {
        let repository = FakeProgramRepository()
        let viewModel = DayBuilderViewModel(
            dayId: ProgramSamples.upperDayId,
            programRepository: repository,
            exerciseRepository: FakeExerciseRepository()
        )

        await viewModel.loadDay()
        await viewModel.addExercise(ProgramSamples.benchPress, form: ProgramExerciseForm(targetSets: 0))

        #expect(viewModel.transientError == .validation(.invalidInput))
        #expect(repository.createdProgramExercises.isEmpty)
    }

    @Test func dayBuilderUpdateTrimsBlankNotesToNil() async throws {
        let repository = FakeProgramRepository()
        let viewModel = DayBuilderViewModel(
            dayId: ProgramSamples.upperDayId,
            programRepository: repository,
            exerciseRepository: FakeExerciseRepository()
        )

        await viewModel.loadDay()
        await viewModel.updateProgramExercise(
            ProgramSamples.benchProgramExercise,
            form: ProgramExerciseForm(targetSets: 4, targetRepsMin: 5, targetRepsMax: 6, targetRestSeconds: 180, notes: " \n ")
        )

        let updated = try #require(repository.updatedProgramExercises.last)
        #expect(updated.targetSets == 4)
        #expect(updated.targetRepsMin == 5)
        #expect(updated.targetRepsMax == 6)
        #expect(updated.targetRestSeconds == 180)
        #expect(updated.notes == nil)
    }

    @Test func exercisePickerFiltersInMemory() async throws {
        let repository = FakeExerciseRepository(exercises: [
            ProgramSamples.benchPress,
            ProgramSamples.backSquat
        ])
        let viewModel = ExercisePickerViewModel(repository: repository)

        await viewModel.loadExercises()
        viewModel.searchText = "bench"
        viewModel.selectedMuscle = .chest
        viewModel.selectedEquipment = .barbell
        viewModel.selectedPattern = .push

        #expect(viewModel.filteredExercises.map(\.id) == [ProgramSamples.benchExerciseId])

        viewModel.clearFilters()

        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedMuscle == nil)
        #expect(viewModel.filteredExercises.count == 2)
    }

    private func successValue<T>(_ state: ViewState<T>) throws -> T {
        guard case let .success(value) = state else {
            throw AppError.unknown(debugID: "expected-success")
        }
        return value
    }

    private func makeProgram(id: String, name: String, isActive: Bool, updatedAt: Date) -> Program {
        Program(
            id: UUID(uuidString: id)!,
            userId: ProgramSamples.userId,
            name: name,
            description: nil,
            isActive: isActive,
            createdAt: ProgramSamples.createdAt,
            updatedAt: updatedAt
        )
    }
}

@MainActor
private final class FakeProgramRepository: ProgramRepositoryProviding {
    var programs: [Program]
    var fullProgram: Program
    var day: ProgramDay
    var programExercises: [ProgramExercise]

    var createdPrograms: [(name: String, description: String?)] = []
    var updatedPrograms: [(id: UUID, name: String, description: String?)] = []
    var deletedProgramIds: [UUID] = []
    var activeProgramIds: [UUID] = []
    var createdDays: [(programId: UUID, name: String, order: Int)] = []
    var updatedDays: [(id: UUID, name: String, order: Int)] = []
    var deletedDayIds: [UUID] = []
    var reorderedDays: [[ProgramDay]] = []
    var createdProgramExercises: [(dayId: UUID, exerciseId: UUID, form: ProgramExerciseForm, order: Int)] = []
    var updatedProgramExercises: [ProgramExercise] = []
    var deletedProgramExerciseIds: [UUID] = []
    var reorderedProgramExercises: [[ProgramExercise]] = []

    init(
        programs: [Program] = ProgramSamples.programs,
        fullProgram: Program = ProgramSamples.program,
        day: ProgramDay = ProgramSamples.days[0],
        programExercises: [ProgramExercise] = [ProgramSamples.benchProgramExercise]
    ) {
        self.programs = programs
        self.fullProgram = fullProgram
        self.day = day
        self.programExercises = programExercises
    }

    func fetchAll() async throws -> [Program] {
        programs
    }

    func fetchFull(id: UUID) async throws -> Program {
        fullProgram
    }

    func fetchDay(id: UUID) async throws -> ProgramDay {
        day
    }

    func fetchProgramExercises(dayId: UUID) async throws -> [ProgramExercise] {
        programExercises
    }

    func fetchActive() async throws -> Program? {
        programs.first { $0.isActive }
    }

    func createProgram(name: String, description: String?) async throws -> Program {
        createdPrograms.append((name, description))
        let program = Program(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            userId: ProgramSamples.userId,
            name: name,
            description: description,
            isActive: false,
            createdAt: ProgramSamples.createdAt,
            updatedAt: ProgramSamples.createdAt
        )
        programs.append(program)
        return program
    }

    func updateProgramMetadata(id: UUID, name: String, description: String?) async throws -> Program {
        updatedPrograms.append((id, name, description))
        var program = fullProgram
        program.name = name
        program.description = description
        fullProgram = program
        return program
    }

    func delete(id: UUID) async throws {
        deletedProgramIds.append(id)
    }

    func setActive(programId: UUID) async throws {
        activeProgramIds.append(programId)
    }

    func createDay(programId: UUID, name: String, order: Int) async throws -> ProgramDay {
        createdDays.append((programId, name, order))
        return ProgramDay(
            id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
            programId: programId,
            name: name,
            dayOrder: order,
            createdAt: ProgramSamples.createdAt
        )
    }

    func updateDay(id: UUID, name: String, order: Int) async throws -> ProgramDay {
        updatedDays.append((id, name, order))
        var updated = day
        updated.name = name
        updated.dayOrder = order
        day = updated
        return updated
    }

    func deleteDay(id: UUID) async throws {
        deletedDayIds.append(id)
    }

    func reorderDays(_ days: [ProgramDay]) async throws {
        reorderedDays.append(days)
    }

    func createProgramExercise(
        dayId: UUID,
        exerciseId: UUID,
        targetSets: Int,
        targetRepsMin: Int,
        targetRepsMax: Int,
        targetRestSeconds: Int,
        order: Int,
        notes: String?
    ) async throws -> ProgramExercise {
        let form = ProgramExerciseForm(
            targetSets: targetSets,
            targetRepsMin: targetRepsMin,
            targetRepsMax: targetRepsMax,
            targetRestSeconds: targetRestSeconds,
            notes: notes ?? ""
        )
        createdProgramExercises.append((dayId, exerciseId, form, order))
        return ProgramExercise(
            id: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
            programDayId: dayId,
            exerciseId: exerciseId,
            targetSets: targetSets,
            targetRepsMin: targetRepsMin,
            targetRepsMax: targetRepsMax,
            targetRestSeconds: targetRestSeconds,
            exerciseOrder: order,
            notes: notes,
            createdAt: ProgramSamples.createdAt
        )
    }

    func updateProgramExercise(_ programExercise: ProgramExercise) async throws -> ProgramExercise {
        updatedProgramExercises.append(programExercise)
        return programExercise
    }

    func deleteProgramExercise(id: UUID) async throws {
        deletedProgramExerciseIds.append(id)
    }

    func reorderProgramExercises(_ exercises: [ProgramExercise]) async throws {
        reorderedProgramExercises.append(exercises)
    }
}

@MainActor
private final class FakeExerciseRepository: ExerciseRepositoryProviding {
    var exercises: [Exercise]

    init(exercises: [Exercise] = ProgramSamples.exercises) {
        self.exercises = exercises
    }

    func fetchAll() async throws -> [Exercise] {
        exercises
    }
}
