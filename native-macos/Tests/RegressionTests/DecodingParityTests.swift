import Foundation
import SharedDomain
import Testing

private struct CatalogResponse: Decodable {
    let results: [CatalogTitle]
}

private struct ConsoleListResponse: Decodable {
    let result: [ConsoleDevice]
}

private struct StreamStateResponse: Decodable {
    let sessionId: String
    let sessionPath: String
    let state: StreamingState
    let waitingTimeMinutes: Int?
    let errorDetails: StreamingErrorDetails?

    func asDomain(kind: StreamingKind = .cloud, targetID: String = "title-1") -> StreamingSession {
        StreamingSession(
            id: sessionId,
            targetID: targetID,
            sessionPath: sessionPath,
            kind: kind,
            state: state,
            waitingTimeMinutes: waitingTimeMinutes,
            errorDetails: errorDetails
        )
    }
}

@Test
func titlesFixtureDecodesIntoCatalogResponse() throws {
    let data = try Fixtures.load("catalog-titles.json")
    let response = try JSONDecoder().decode(CatalogResponse.self, from: data)

    #expect(response.results.isEmpty == false)
    #expect(response.results.first?.productTitle == "Forza Horizon")
}

@Test
func consoleListFixtureDecodesIntoConsoleDevices() throws {
    let data = try Fixtures.load("console-list.json")
    let response = try JSONDecoder().decode(ConsoleListResponse.self, from: data)

    #expect(response.result.count == 2)
    #expect(response.result.first?.consoleType == .xboxSeriesX)
}

@Test
func streamStateFixtureDecodesIntoReadyDomainSession() throws {
    let data = try Fixtures.load("stream-state-ready.json")
    let response = try JSONDecoder().decode(StreamStateResponse.self, from: data)
    let session = response.asDomain()

    #expect(session.state == .readyToConnect)
    #expect(session.sessionPath == "/v5/sessions/cloud/stream-session-1")
}
