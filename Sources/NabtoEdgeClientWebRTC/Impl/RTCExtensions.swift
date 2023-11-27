//
//  RTCExtensions.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import NabtoEdgeClient
import WebRTC

internal extension RTCSessionDescription {
    func toJSON() -> String {
        let strType: String // Define the type of the variable
        switch self.type {
        case .answer: strType = "answer"
        case .offer: strType = "offer"
        case .prAnswer: strType = "prAnswer"
        case .rollback: strType = "rollback"
        }

        let obj: [String: Any] = [
            "type": strType,
            "sdp": self.sdp
        ]
        
        let maybeJsonData = try? JSONSerialization.data(withJSONObject: obj)
        guard let jsonData = maybeJsonData else {
            fatalError("Invalid SDP, could not convert to JSON.")
        }
        
        let maybeResult = String(data: jsonData, encoding: .utf8)
        guard let result = maybeResult else {
            fatalError("Invalid SDP, could not convert to JSON.")
        }
        
        return result
    }
}


internal extension RTCIceCandidate {
    func toJSON() -> String {
        let obj: [String: Any] = [
            "candidate": self.sdp,
            "sdpMLineIndex": self.sdpMLineIndex,
            "sdpMid": self.sdpMid ?? ""
        ]
        
        let maybeJsonData = try? JSONSerialization.data(withJSONObject: obj)
        guard let jsonData = maybeJsonData else {
            fatalError("Invalid SDP, could not convert to JSON.")
        }
        
        let maybeResult = String(data: jsonData, encoding: .utf8)
        guard let result = maybeResult else {
            fatalError("Invalid SDP, could not convert to JSON.")
        }
        
        return result
    }
}

internal extension RTCSignalingState {
    func description() throws -> String {
        switch self {
        case .closed:
            return "closed"
        case .stable:
            return "stable"
        case .haveLocalOffer:
            return "haveLocalOffer"
        case .haveLocalPrAnswer:
            return "haveLocalPrAnswer"
        case .haveRemoteOffer:
            return "haveRemoteOffer"
        case .haveRemotePrAnswer:
            return "haveRemotePrAnswer"
        @unknown default:
           throw NabtoEdgeClientError.INVALID_ARGUMENT
        }
    }
}

internal extension RTCIceGatheringState {
    func description() throws -> String {
        switch self {
        case .complete:
            return "complete"
        case .new:
            return "new"
        case .gathering:
            return "gathering"
        @unknown default:
           throw NabtoEdgeClientError.INVALID_ARGUMENT
        }
    }
}

internal extension RTCIceConnectionState {
    func description() throws -> String {
        switch self {
        case .new:
             return "new"
         case .checking:
             return "checking"
         case .connected:
             return "connected"
         case .completed:
             return "completed"
         case .failed:
             return "failed"
         case .disconnected:
             return "disconnected"
         case .closed:
             return "closed"
         @unknown default:
            throw NabtoEdgeClientError.INVALID_ARGUMENT
        }
    }
}

