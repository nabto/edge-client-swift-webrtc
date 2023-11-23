//
//  EdgeVideoTrack.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import WebRTC

class EdgeVideoTrack {
    internal let track: RTCVideoTrack
    let localTrackId: String
    let remoteTrackId: String
    
    internal init(track: RTCVideoTrack, localTrackId: String, remoteTrackId: String) {
        self.track = track
        self.localTrackId = localTrackId
        self.remoteTrackId = remoteTrackId
    }
    
    func addRenderTarget(_ renderer: EdgeVideoRenderer) {
        self.track.add(renderer)
    }
}
