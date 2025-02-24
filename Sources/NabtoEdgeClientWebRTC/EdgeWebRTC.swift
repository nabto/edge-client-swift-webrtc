//
//  EdgeWebRTC.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import NabtoEdgeClient
import WebRTC

/**
 * Log levels to use in the underlying SDK
 */
public enum EdgeWebrtcLogLevel: Int {
    case error = 0
    case warning = 1
    case info = 2
    case verbose = 3
}

/**
 * Manager interface to keep track of global WebRTC state
 */
public class EdgeWebrtc {
    private init() {}

    internal static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()

    /**
     * Set the log level to use by the underlying SDK
     *
     * @param logLevel [in] The log level to set
     */
    public static func setLogLevel(_ logLevel: EdgeWebrtcLogLevel) {
        EdgeLogger.setLogLevel(logLevel)
    }

    /**
     * Log using NSLog. Less performant but useful in some scenarios.
     */
    public static func enableNsLogLogging() {
        EdgeLogger.enableNsLogLogging()
    }

    /**
     * Create a new WebRTC connection instance using a pre-existing Nabto Edge Connection for signaling.
     *
     * Only one WebRTC connection can exist on a Nabto Edge Connection at a time.
     *
     * This function does not throw any exceptions.
     *
     * @param conn [in] The Nabto Edge Connection to use for signaling
     * @return The created EdgePeerConnection object
     */
    public static func createPeerConnection(_ connection: Connection) -> EdgePeerConnection {
        return EdgePeerConnectionImpl(connection)
    }

    /**
     * Create an RTCAudioSource object that can be used to create an EdgeAudioTrack with createAudioTrack
     *
     * @param constraints a RTCMediaConstraints object. Refer to https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints#instance_properties_of_audio_tracks
     */
    public static func createAudioSource(constraints: RTCMediaConstraints) -> RTCAudioSource {
        return factory.audioSource(with: constraints)
    }

    /**
     * Create an RTCVideoSource object that can be used to create an EdgeVideoTrack with createVideoTrack
     *
     * @param isScreenCast Sets whether the video source is a screencast or not.
     */
    public static func createVideoSource(isScreenCast: Bool) -> RTCVideoSource {
        return factory.videoSource(forScreenCast: isScreenCast)
    }

    /**
     * Create an EdgeAudioTrack that can be added to a peer connection.
     *
     * @param trackId The id of the track
     * @param source RTCAudioSource object created with createAudioSource
     */
    public static func createAudioTrack(trackId: String, source: RTCAudioSource) -> EdgeAudioTrack {
        return EdgeAudioTrackImpl(track: factory.audioTrack(with: source, trackId: trackId))
    }

    /**
     * Create an EdgeVideoTrack that can be added to a peer connection.
     *
     * @param trackId The id of the track
     * @param source RTCAudioSource object created with createVideoSource
     */
    public static func createVideoTrack(trackId: String, source: RTCVideoSource) -> EdgeVideoTrack {
        return EdgeVideoTrackImpl(track: factory.videoTrack(with: source, trackId: trackId))
    }
}
