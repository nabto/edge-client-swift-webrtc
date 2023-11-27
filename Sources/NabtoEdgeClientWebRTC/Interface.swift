import Foundation

public protocol EdgeMediaTrack {
    var localTrackId: String { get }
    var remoteTrackId: String { get }
}

public protocol EdgeVideoTrack: EdgeMediaTrack {
    func addRenderTarget(_ renderer: EdgeVideoRenderer)
}

public protocol EdgeAudioTrack: EdgeMediaTrack {
    // @TODO: Implement audio tracks
}

public protocol EdgePeerConnection {
    func addVideoTrack(track: EdgeVideoTrack)
    func addAudioTrack(track: EdgeAudioTrack)
}
