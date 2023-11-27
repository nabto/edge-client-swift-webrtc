//
//  EdgeVideoTrack.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import WebRTC

public class EdgeVideoTrackImpl: EdgeVideoTrack {
    public var localTrackId: String
    public var remoteTrackId: String
    
    internal var track: RTCVideoTrack
    internal var pcTrack: RTCVideoTrack?
    internal var targets: [EdgeVideoRenderer]
    
    internal init(track: RTCVideoTrack, localTrackId: String, remoteTrackId: String) {
        self.track = track
        self.localTrackId = localTrackId
        self.remoteTrackId = remoteTrackId
        self.targets = []
    }
    
    internal func setPeerConnectionTrack(_ track: RTCVideoTrack) {
        pcTrack = track
        for target in targets {
            pcTrack?.add(target)
        }
    }
    
    public func addRenderTarget(_ renderer: EdgeVideoRenderer) {
        self.pcTrack?.add(renderer)
        self.targets.append(renderer)
    }
}
