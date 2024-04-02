import Foundation
import WebRTC

/**
 * Errors emitted by the onErrorCallback
 */
public enum EdgeWebrtcError : Error {
    /**
     * The signaling stream could not be established properly.
     */
    case signalingFailedToInitialize

    /**
     * Reading from the Signaling Stream failed
     */
    case signalingFailedRecv
    
    /**
     * Writing to the Signaling Stream failed
     */
    case signalingFailedSend

    /**
     * An invalid signaling message was received
     */
    case signalingInvalidMessage

    /**
     * The remote description received from the other peer was invalid
     */
    case setRemoteDescriptionError

    /**
     * Failed to send an Answer on the signaling stream
     */
    case sendAnswerError

    /**
     * A invalid ICE candidate was received from the other peer
     */
    case iceCandidateError

    /**
     * The RTC PeerConnection could not be created
     */
    case connectionInitError
}

/**
 * Interface used to represent all Media Tracks
 */
public protocol EdgeMediaTrack {
}

/**
 * Video Track representing a Media Track of type Video
 */
public protocol EdgeVideoTrack: EdgeMediaTrack {
    /**
     * Add a Video renderer to the track
     *
     * @param renderer [in] The renderer to add
     */
    func add(_ renderer: EdgeVideoRenderer)

    /**
     * Remove a Video renderer from the track
     *
     * @param renderer [in] The renderer to remove
     */
    func remove(_ renderer: EdgeVideoRenderer)
}

/**
 * Audio Track representing a Media Track of type Audio
 */
public protocol EdgeAudioTrack: EdgeMediaTrack {

    /**
     * Set the volume of the Audio track
     *
     * @param volume [in] The volume to set
     */
    func setVolume(_ volume: Double)

    /**
     * Enable or disable the Audio track
     *
     * @param enabled [in] Boolean determining if the track is enabled
     */
    func setEnabled(_ enabled: Bool)
}


/**
 * Callback invoked when the remote peer has added a Track to the WebRTC connection
 *
 * @param EdgeMediaTrack [in] The newly added Track
 */
public typealias EdgeOnTrackCallback = (EdgeMediaTrack) -> ()

/**
 * Callback invoked when a WebRTC connection has been closed
 */
 public typealias EdgeOnClosedCallback = () -> ()

/**
 * Callback invoked when an error occurs in the WebRTC connection
 *
 * @param EdgeWebRTCError [in] The Error that occured
 */
public typealias EdgeOnErrorCallback = (EdgeWebrtcError) -> ()


/**
 * Main Connection interface used to connect to a device and interact with it.
 */
public protocol EdgePeerConnection {

    /**
     * Set callback to be invoked when a new track is available on the WebRTC connection
     *
     * @param cb The callback to set
     */
    var onTrack: EdgeOnTrackCallback? { get set }

    /**
     * Set callback to be invoked when the WebRTC connection is closed
     *
     * @param cb The callback to set
     */
    var onClosed: EdgeOnClosedCallback? { get set }

    /**
     * Set callback to be invoked when an error occurs on the WebRTC connection.
     *
     * @param cb The callback to set
     */
    var onError: EdgeOnErrorCallback? { get set }

    /**
     * Establish a WebRTC connection to the other peer
     *
     * @throws EdgeWebrtcError.signalingFailedToInitialize if the signaling stream could not be set up for some reason.
     * @throws EdgeWebrtcError.signalingFailedRecv if the signaling stream failed to receive messages necessary to setting up the connection.
     * @throws EdgeWebrtcError.signalingFailedSend if the signaling stream failed to send messages necessary to setting up the connection.
     */
    func connect() async throws

    /**
     * Close a connected WebRTC connection.
     */
    func close()
}
