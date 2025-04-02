import Foundation
import WebRTC

/**
 * Callback invoked when the remote peer has added a Track to the WebRTC connection
 *
 * @param track [in] The newly added Track
 * @param trackId [in] The device repoted ID for this Track
 */
public typealias EdgeOnTrackCallback = (_ track: EdgeMediaTrack, _ trackId: String?) -> ()

/**
 * Callback invoked when the object (e.g. a data channel) has opened.
 */
public typealias EdgeOnOpenedCallback = () -> ()

/**
 * Callback invoked when a WebRTC connection has been closed
 */
 public typealias EdgeOnClosedCallback = () -> ()

/**
 * Callback invoked when an error occurs in the WebRTC connection
 *
 * @param error [in] The Error that occured
 */
public typealias EdgeOnErrorCallback = (_ error: EdgeWebrtcError) -> ()

/**
 * Callback invoked when a data channel has received a message.
 */
public typealias EdgeOnMessageCallback = (_ data: Data) -> ()

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
 * Error thrown by addTrack if the argument
 */
struct InvalidTrackError: LocalizedError {

}

/**
 * Track types used to identify if a track is Video or Audio
 */
public enum EdgeMediaTrackType {
    case audio
    case video
}

/**
 * Interface used to represent all Media Tracks
 */
public protocol EdgeMediaTrack {
    var type: EdgeMediaTrackType { get }
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
 * Data channel for sending and receiving bytes on a webrtc connection
 */
public protocol EdgeDataChannel {
    /**
     * Set the callback to be invoked when the data channel receives a message.
     *
     * @param cb The callback to set
     */
    var onMessage: EdgeOnMessageCallback? { get set }

    /**
     * Set the callback to be invoked when the data channel is open and ready to send/receive messages.
     *
     * @param cb The callback to set
     */
    var onOpened: EdgeOnOpenedCallback? { get set }

    /**
     * Set the callback to be invoked when the data channel is closed.
     *
     * @param cb The callback to set
     */
    var onClosed: EdgeOnClosedCallback? { get set }

    /**
     * Send a Data byte buffer over the data channel.
     *
     * @param data The binary data to be sent.
     */
    func send(_ data: Data) async

    /**
     * Closes the data channel.
     */
    func close() async
}

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
     * Create a new data channel
     * WARNING: Data channels are experimental and may not work as expected..
     *
     * @param label A string that describes the data channel.
     */
    func createDataChannel(_ label: String) throws -> EdgeDataChannel

    /**
     * Add a track to this  connection.
     *
     *@param track The track to be added.
     *@param streamIds List of stream ids that this track will be added to.
     */
    func addTrack(_ track: EdgeMediaTrack, streamIds: [String]) throws

    /**
     * Access the underlying RTCPeerConnection object.
     */
    func getPeerConnection() -> RTCPeerConnection?

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
    func close() async
}
