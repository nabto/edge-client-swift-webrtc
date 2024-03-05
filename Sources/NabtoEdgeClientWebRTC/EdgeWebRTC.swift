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
public enum EdgeWebRTCLogLevel: Int {
    case error = 0
    case warning = 1
    case info = 2
    case verbose = 3
}

/**
 * Manager interface to keep track of global WebRTC state
 */
public class EdgeWebRTC {
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
    public static func setLogLevel(_ logLevel: EdgeWebRTCLogLevel) {
        EdgeLogger.setLogLevel(logLevel)
    }

    // TODO: add @throws docs
    /**
     * Create a new WebRTC connection instance using a preexisting Nabto Edge Connection for signaling.
     *
     * Only one WebRTC connection can exist on a Nabto Edge Connection at a time.
     *
     * @param conn [in] The Nabto Edge Connection to use for signaling
     * @return The created EdgePeerConnection object
     */
    public static func createPeerConnection(_ connection: Connection) -> EdgePeerConnection {
        return EdgePeerConnectionImpl(connection)
    }
}
