//
//  EdgeWebRTC.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import NabtoEdgeClient
import WebRTC

class EdgeWebRTC {
    private init() {}
    
    internal static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        //RTCSetMinDebugLogLevel(.info)
        //RTCEnableMetrics()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    
    static func createVideoTrack(localTrackId: String, remoteTrackId: String) -> EdgeVideoTrack {
        let videoSource = Self.factory.videoSource()
        let videoTrack = Self.factory.videoTrack(with: videoSource, trackId: localTrackId)
        return EdgeVideoTrack(track: videoTrack, localTrackId: localTrackId, remoteTrackId: remoteTrackId)
    }
    
    static func createPeerConnection(_ connection: Connection) -> EdgePeerConnection {
        return EdgePeerConnectionImpl(connection)
    }
}
