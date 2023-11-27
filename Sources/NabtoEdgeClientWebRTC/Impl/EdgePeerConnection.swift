//
//  EdgePeerConnection.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import WebRTC
import NabtoEdgeClient
import os

internal class EdgePeerConnectionImpl: NSObject, EdgePeerConnection {
    private var peerConnection: RTCPeerConnection?
    private let signaling: EdgeSignaling
    private let jsonDecoder = JSONDecoder()
    private var tracks: [EdgeVideoTrackImpl] = []
    
    // @TODO: Figure out what stream Ids are used for in WebRTC.
    private let streamId = "stream"
    private let mandatoryConstraints = [
        kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
        //kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue
    ]
    
    init(_ conn: Connection) {
        do {
            self.signaling = try EdgeStreamSignaling(conn)
        } catch {
            // @TODO: throw an error instead of crashing with fatalError
            fatalError("Failed to create signaling stream \(error)")
        }
        super.init()
        
        Task {
            await messageLoop()
        }
    }
    
    func addVideoTrack(track: EdgeVideoTrack) {
        // @TODO: Add the track immediately if peerConnection is online?
        tracks.append(track as! EdgeVideoTrackImpl)
    }
    
    func addAudioTrack(track: EdgeAudioTrack) {
        // @TODO: Implement audio tracks
    }
    
    private func createOffer(_ pc: RTCPeerConnection) async -> RTCSessionDescription {
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)
        return await withCheckedContinuation { continuation in
            pc.offer(for: constraints) { (sdp, error) in
                guard let sdp = sdp else { return }
                continuation.resume(returning: sdp)
            }
        }
    }
    
    private func startPeerConnection(_ config: RTCConfiguration) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let peerConnection = EdgeWebRTC.factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            fatalError("Failed to create RTCPeerConnection")
        }
        
        self.peerConnection = peerConnection
        
        for track in tracks {
            // @TODO
            let rtpSender = self.peerConnection!.add(track.track, streamIds: [streamId])
            let pcTrack = self.peerConnection!.transceivers.first {
                $0.mediaType == .video
            }?.receiver.track as? RTCVideoTrack
            
            if let pcTrack = pcTrack {
                track.setPeerConnectionTrack(pcTrack)
            } else {
                // @TODO: Error handling
                NSLog("Failed to add track")
            }
        }
    }
    
    private func messageLoop() async {
        await signaling.send(SignalMessage(type: .turnRequest))
        
        while true {
            let msg = try? await signaling.recv()
            guard let msg = msg else {
                break
            }
            
            switch msg.type {
            case .answer:
                do {
                    let answer = try jsonDecoder.decode(SDP.self, from: msg.data!.data(using: .utf8)!)
                    let sdp = RTCSessionDescription(type: RTCSdpType.answer, sdp: answer.sdp)
                    try await self.peerConnection!.setRemoteDescription(sdp)
                } catch {
                    NSLog("NabtoRTC: Failed handling ANSWER message \(error)")
                }
                break
                
            case .iceCandidate:
                do {
                    let cand = try jsonDecoder.decode(IceCandidate.self, from: msg.data!.data(using: .utf8)!)
                    try await self.peerConnection!.add(RTCIceCandidate(
                        sdp: cand.candidate,
                        sdpMLineIndex: 0,
                        sdpMid: cand.sdpMid
                    ))
                } catch {
                    NSLog("NabtoRTC: Failed handling ICE candidate message \(error)")
                }
                break
                
            case .turnResponse:
                guard let turnServers = msg.servers else {
                    // @TODO: Show an error to the user
                    break
                }
                
                let config = RTCConfiguration()
                config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.nabto.net"])]
                config.sdpSemantics = .unifiedPlan
                config.continualGatheringPolicy = .gatherContinually
                
                for server in turnServers {
                    let turn = RTCIceServer(
                        urlStrings: [server.hostname],
                        username: server.username,
                        credential: server.password
                    )
                    
                    config.iceServers.append(turn)
                }
                
                self.startPeerConnection(config)
                
                let offer = await self.createOffer(peerConnection!)
                let msg = SignalMessage(
                    type: .offer,
                    data: offer.toJSON(),
                    metadata: SignalMessageMetadata(
                        // @TODO: We should build a proper structure of all the tracks. Right now we are just faking it with the first track.
                        tracks: [SignalMessageMetadataTrack(mid: "0", trackId: "frontdoor-video")],
                        noTrickle: false
                    )
                )
                
                await signaling.send(msg)
                do { try await peerConnection!.setLocalDescription(offer) } catch {
                    NSLog("NabtoRTC: Failed setting peer connection local description \(error)")
                }
                break
                
            default:
                NSLog("Unexpected signaling message of type: \(msg.type)")
                break
            }
        }
    }
}

// MARK: RTCPeerConnectionDelegate implementation
extension EdgePeerConnectionImpl: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        NSLog("NabtoRTC: Signaling state changed to \((try? stateChanged.description()) ?? "invalid RTCSignalingState")")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        NSLog("NabtoRTC: New RTCMediaStream \(stream.streamId) added")
        print(stream.videoTracks.first?.description)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        NSLog("NabtoRTC: RTCMediaStream \(stream.streamId) removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        NSLog("NabtoRTC: Peer connection should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        NSLog("NabtoRTC: ICE connection state changed to: \((try? newState.description()) ?? "invalid RTCIceConnectionState")")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        NSLog("NabtoRTC: ICE gathering state changed to: \((try? newState.description()) ?? "invalid RTCIceGatheringState")")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        NSLog("NabtoRTC: New ICE candidate generated: \(candidate.sdp)")
        Task {
            await signaling.send(SignalMessage(
                type: .iceCandidate,
                data: candidate.toJSON()
            ))
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        NSLog("NabtoRTC: ICE candidate removed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen candidate: RTCDataChannel) {
        NSLog("NabtoRTC: Data channel opened")
    }
}