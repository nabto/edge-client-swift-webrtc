//
//  EdgeWebRTC.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import NabtoEdgeClient
import WebRTC

public enum EdgeWebRTCLogLevel: Int {
    case error = 0
    case warning = 1
    case info = 2
    case verbose = 3
}

public class EdgeWebRTC {
    private init() {}
    
    internal static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    
    public static func setLogLevel(_ logLevel: EdgeWebRTCLogLevel) {
        EdgeLogger.setLogLevel(logLevel)
    }
    
    public static func createPeerConnection(_ connection: Connection) -> EdgePeerConnection {
        return EdgePeerConnectionImpl(connection)
    }
}
