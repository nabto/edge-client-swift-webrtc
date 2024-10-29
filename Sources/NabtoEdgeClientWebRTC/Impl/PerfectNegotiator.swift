//
//  File.swift
//  
//
//  Created by Ahmad Saleh on 02/09/2024.
//

import Foundation
import WebRTC

internal class PerfectNegotiator {
    private let signaling: EdgeSignaling
    private let peerConnection: RTCPeerConnection
    private let polite: Bool
    private var makingOffer = false
    private var ignoreOffer = false
    private let jsonDecoder = JSONDecoder()
    
    public private(set) var receivedMetadata: [String: SignalMessageMetadataTrack] = [:]
    
    init(signaling: EdgeSignaling, peerConnection: RTCPeerConnection, polite: Bool) {
        self.signaling = signaling
        self.peerConnection = peerConnection
        self.polite = polite
        
        Task {
            while true {
                var signalingMessage: SignalMessage? = nil
                do {
                    signalingMessage = try await self.signaling.recv()
                } catch {
                    EdgeLogger.error("Failed to receive signaling message: \(error)")
                }
                
                if let msg = signalingMessage {
                    await handleSignalingMessage(message: msg)
                }
            }
        }
    }
    
    func onRenegotiationNeeded() {
        Task {
            defer {
                makingOffer = false
            }
            
            do {
                makingOffer = true
                try await peerConnection.setLocalDescription()
                await signaling.send(sdpToMessage(peerConnection.localDescription!))
            } catch {
                EdgeLogger.error("\(error)")
            }
        }
    }
    
    func onIceConnectionChange(state: RTCIceConnectionState) {
        if state == .failed {
            peerConnection.restartIce()
        }
    }
    
    func onIceCandidate(candidate: RTCIceCandidate) {
        Task {
            await signaling.send(SignalMessage(
                type: .iceCandidate,
                data: candidate.toJSON()
            ))
        }
    }
    
    private func createMetadata() -> SignalMessageMetadata {
        var tracks: [SignalMessageMetadataTrack] = []
        
        peerConnection.transceivers.forEach { transceiver in
            let metaTrack = receivedMetadata[transceiver.mid]
            if let metaTrack = metaTrack {
                tracks.append(metaTrack)
            }
        }
        
        var status = "OK"
        tracks.forEach { track in
            if track.error != nil && track.error != "OK" {
                status = "FAILED"
            }
        }
        
        return SignalMessageMetadata(
            tracks: tracks,
            noTrickle: false,
            status: status
        )
    }
    
    private func sdpToMessage(_ description: RTCSessionDescription) -> SignalMessage {
        let type = description.type == .answer ? SignalMessageType.answer : SignalMessageType.offer
        let msg = SignalMessage(type: type, data: description.toJSON(), metadata: createMetadata())
        return msg
    }
    
    private func handleMetadata(data: SignalMessageMetadata) {
        if data.status == "FAILED" {
            if let tracks = data.tracks {
                for track in tracks {
                    if let error = track.error {
                        EdgeLogger.error("Device reported \(track.mid):\(track.trackId) failed with error: \(error)")
                    }
                }
            }
        }
        
        data.tracks?.forEach { track in
            receivedMetadata[track.mid] = track
        }
    }
    
    private func handleDescription(description: RTCSessionDescription, metadata: SignalMessageMetadata?) async throws {
        let offerCollision = (description.type == .offer) && (makingOffer || peerConnection.signalingState != .stable)
        ignoreOffer = !polite && offerCollision
        if ignoreOffer { return }
        
        if let metadata = metadata {
            handleMetadata(data: metadata)
        }
        
        try await peerConnection.setRemoteDescription(description)
        if (description.type == .offer) {
            try await peerConnection.setLocalDescription()
            await signaling.send(sdpToMessage(peerConnection.localDescription!))
        }
    }
    
    private func handleSignalingMessage(message: SignalMessage) async {
        switch message.type {
        case .answer, .offer:
            do {
                let decoded = try jsonDecoder.decode(SDP.self, from: message.data!.data(using: .utf8)!)
                let type: RTCSdpType = message.type == .answer ? .answer : .offer
                let sdp = RTCSessionDescription(type: type, sdp: decoded.sdp)
                try await handleDescription(description: sdp, metadata: message.metadata)
            } catch {
                EdgeLogger.error("PerfectNegotiator error while handling incoming SDP: \(error)")
            }
            break
            
        case .iceCandidate:
            let cand = try? jsonDecoder.decode(IceCandidate.self, from: message.data!.data(using: .utf8)!)
            
            if let cand = cand {
                do {
                    try await self.peerConnection.add(RTCIceCandidate(
                        sdp: cand.candidate,
                        sdpMLineIndex: 0,
                        sdpMid: cand.sdpMid
                    ))
                } catch {
                    if !ignoreOffer {
                        EdgeLogger.error("\(error)")
                    }
                }
            }
            break
            
        default:
            EdgeLogger.error("PerfectNegotiator received message of unexpected type: \(message.type)")
            break
        }
    }
}
