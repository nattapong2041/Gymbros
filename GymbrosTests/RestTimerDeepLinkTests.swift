import Foundation
import Testing
@testable import Gymbros

@Suite("RestTimerDeepLink")
struct RestTimerDeepLinkTests {
    @Test func roundTripsURLToRoute() throws {
        let sessionId = UUID()
        let programDayId = UUID()
        let programExerciseId = UUID()

        let url = try #require(RestTimerDeepLink.url(
            sessionId: sessionId,
            programDayId: programDayId,
            programExerciseId: programExerciseId
        ))
        let route = try #require(RestTimerDeepLink.route(from: url))

        #expect(route.sessionId == sessionId)
        #expect(route.programDayId == programDayId)
        #expect(route.programExerciseId == programExerciseId)
    }

    @Test func notificationUserInfoParsesRoute() throws {
        let sessionId = UUID()
        let programDayId = UUID()

        let userInfo = RestTimerDeepLink.userInfo(
            sessionId: sessionId,
            programDayId: programDayId,
            programExerciseId: nil
        )
        let route = try #require(RestTimerDeepLink.route(from: userInfo))

        #expect(route.sessionId == sessionId)
        #expect(route.programDayId == programDayId)
        #expect(route.programExerciseId == nil)
    }
}
