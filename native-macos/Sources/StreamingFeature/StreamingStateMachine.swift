import SharedDomain

public enum StreamingStateMachine {
    public enum State: Equatable, Sendable {
        case idle
        case pending(StreamingSession)
        case queued(StreamingSession)
        case readyToConnect(StreamingSession)
        case connecting(StreamingSession)
        case streaming(StreamingSession)
        case stopped
        case failed(StreamingErrorDetails?)

        public var session: StreamingSession? {
            switch self {
            case .pending(let session),
                 .queued(let session),
                 .readyToConnect(let session),
                 .connecting(let session),
                 .streaming(let session):
                return session
            case .idle, .stopped, .failed:
                return nil
            }
        }
    }

    public enum Event: Sendable {
        case sessionCreated(StreamingSession)
        case remoteStateChanged(String, session: StreamingSession)
        case enginePrepared
        case engineStarted
        case stopRequested
        case stopped
        case failed(StreamingErrorDetails?)
    }

    public static func reduce(_ state: State, event: Event) -> State {
        switch event {
        case .sessionCreated(let session):
            return makeState(for: session)

        case .remoteStateChanged(_, let session):
            return makeState(for: session)

        case .enginePrepared:
            guard let session = state.session else {
                return state
            }
            return .connecting(session)

        case .engineStarted:
            guard let session = state.session else {
                return state
            }
            return .streaming(session)

        case .stopRequested, .stopped:
            return .stopped

        case .failed(let details):
            return .failed(details)
        }
    }

    private static func makeState(for session: StreamingSession) -> State {
        switch session.state {
        case .pending:
            return .pending(session)
        case .queued:
            return .queued(session)
        case .readyToConnect:
            return .readyToConnect(session)
        case .started:
            return .streaming(session)
        case .failed:
            return .failed(session.errorDetails)
        case .stopped:
            return .stopped
        }
    }
}
