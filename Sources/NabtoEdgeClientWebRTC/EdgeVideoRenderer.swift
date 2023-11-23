//
//  EdgeVideoRenderer.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import WebRTC

protocol EdgeVideoRenderer: RTCVideoRenderer {

}

class EdgeMetalVideoView: RTCMTLVideoView, EdgeVideoRenderer {
    
}
