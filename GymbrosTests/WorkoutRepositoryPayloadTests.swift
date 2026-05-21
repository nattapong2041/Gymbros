import Foundation
import Testing
@testable import Gymbros

@Suite("Workout Repository Payloads")
struct WorkoutRepositoryPayloadTests {
    @Test func completionPayloadUsesEndedAtOnly() throws {
        let endedAt = Date(timeIntervalSince1970: 1_778_346_000)
        let payload = WorkoutSessionCompletionPayload(endedAt: endedAt)

        let dictionary = try encodeDictionary(payload)

        #expect(dictionary["ended_at"] as? String == endedAt.ISO8601Format())
        #expect(dictionary["id"] == nil)
        #expect(dictionary["user_id"] == nil)
        #expect(dictionary["program_day_id"] == nil)
        #expect(dictionary["started_at"] == nil)
        #expect(dictionary["created_at"] == nil)
    }

    private func encodeDictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
