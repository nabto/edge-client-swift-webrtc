//
//  EdgeVideoTrack.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import WebRTC

public class EdgeVideoTrackImpl: EdgeVideoTrack {
    public private(set) var type: EdgeMediaTrackType = .video
    internal var track: RTCVideoTrack
    
    internal init(track: RTCVideoTrack) {
        self.track = track
    }
    
    public func add(_ renderer: EdgeVideoRenderer) {
        self.track.add(renderer)
    }
    
    public func remove(_ renderer: EdgeVideoRenderer) {
        self.track.remove(renderer)
    }
}
