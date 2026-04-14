import SharedDomain
import Testing
@testable import StreamingFeature

@Test
func streamingStateMachineMapsWaitingStateToQueued() {
    let session = StreamingSession(
        id: "stream-1",
        targetID: "console-1",
        sessionPath: "/sessions/stream-1",
        kind: .cloud,
        state: .queued,
        waitingTimeMinutes: 4
    )

    let state = StreamingStateMachine.reduce(
        .pending(session),
        event: .remoteStateChanged("WaitingForResources", session: session)
    )

    #expect(state == .queued(session))
}

@Test
func streamingStateMachineTransitionsToStreamingAfterEngineStart() {
    let session = StreamingSession(
        id: "stream-1",
        targetID: "console-1",
        sessionPath: "/sessions/stream-1",
        kind: .home,
        state: .readyToConnect
    )

    let ready = StreamingStateMachine.reduce(.idle, event: .sessionCreated(session))
    let connecting = StreamingStateMachine.reduce(ready, event: .enginePrepared)
    let streaming = StreamingStateMachine.reduce(connecting, event: .engineStarted)

    #expect(ready == .readyToConnect(session))
    #expect(connecting == .connecting(session))
    #expect(streaming == .streaming(session))
}

@Test
func streamingStateMachineCapturesFailureDetails() {
    let details = StreamingErrorDetails(code: "stream_failed", message: "ICE exchange failed")
    let state = StreamingStateMachine.reduce(.idle, event: .failed(details))
    #expect(state == .failed(details))
}
