import Foundation

struct HistoryDisplayData {
    var sessions: [WorkoutSession]
    var dayNames: [UUID: String]
    var detailStates: [UUID: ViewState<SessionDetailDisplayData>]

    func dayName(for session: WorkoutSession) -> String? {
        guard let programDayId = session.programDayId else { return nil }
        return dayNames[programDayId]
    }

    func detailState(for session: WorkoutSession) -> ViewState<SessionDetailDisplayData> {
        detailStates[session.id] ?? .loading
    }
}
