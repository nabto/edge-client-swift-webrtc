//
//  EdgeVideoRenderer.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import WebRTC

public protocol EdgeVideoRenderer: RTCVideoRenderer {

}

public class EdgeMetalVideoView: RTCMTLVideoView, EdgeVideoRenderer {
    public func embed(into container: UIView) {
        container.addSubview(self)
        self.translatesAutoresizingMaskIntoConstraints = false
        container.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "H:|[view]|",
            options: [],
            metrics: nil,
            views: ["view": self]
        ))
        
        container.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "V:|[view]|",
            options: [],
            metrics: nil,
            views: ["view": self]
        ))
        
        container.layoutIfNeeded()
    }
}
