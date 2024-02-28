import Foundation
import WebRTC

public enum EdgeWebRTCError : Error {
    case signalingFailedToInitialize
    case signalingFailedRecv
    case signalingInvalidMessage
    case setRemoteDescriptionError
    case sendAnswerError
    case iceCandidateError
    case connectionInitError
}

public protocol EdgeMediaTrack {
}

public protocol EdgeVideoTrack: EdgeMediaTrack {
    func add(_ renderer: EdgeVideoRenderer)
    func remove(_ renderer: EdgeVideoRenderer)
}

public protocol EdgeAudioTrack: EdgeMediaTrack {
    func setVolume(_ volume: Double)
    func setEnabled(_ enabled: Bool)
}

public typealias EdgeOnTrackCallback = (EdgeMediaTrack) -> ()
public typealias EdgeOnConnectedCallback = () -> ()
public typealias EdgeOnClosedCallback = () -> ()
public typealias EdgeOnErrorCallback = (EdgeWebRTCError) -> ()

public protocol EdgePeerConnection {
    var onTrack: EdgeOnTrackCallback? { get set }
    var onConnected: EdgeOnConnectedCallback? { get set }
    var onClosed: EdgeOnClosedCallback? { get set }
    var onError: EdgeOnErrorCallback? { get set }
    
    func connect() async throws
    func close()
}
