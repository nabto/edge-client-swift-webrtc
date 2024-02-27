import Foundation
import WebRTC

public protocol EdgeMediaTrack {
}

public protocol EdgeVideoTrack: EdgeMediaTrack {
    func add(_ renderer: EdgeVideoRenderer)
    func remove(_ renderer: EdgeVideoRenderer)
}

public protocol EdgeAudioTrack: EdgeMediaTrack {
    // @TODO: Implement audio tracks
}

public typealias EdgeOnTrackCallback = (EdgeMediaTrack) -> ()
public typealias EdgeOnConnectedCallback = () -> ()
public typealias EdgeOnClosedCallback = () -> ()

public protocol EdgePeerConnection {
    var onTrack: EdgeOnTrackCallback? { get set }
    var onConnected: EdgeOnConnectedCallback? { get set }
    var onClosed: EdgeOnClosedCallback? { get set }
    
    func close()
}
