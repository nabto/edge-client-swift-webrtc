//
//  EdgePeerConnection.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import WebRTC
import NabtoEdgeClient
import CBORCoding
import os

internal class EdgePeerConnectionImpl: NSObject, EdgePeerConnection {
    var onClosed: EdgeOnClosedCallback? = nil
    var onTrack: EdgeOnTrackCallback? = nil
    var onError: EdgeOnErrorCallback? = nil
    
    private let peerConnectionFactory: RTCPeerConnectionFactory
    private let signaling: EdgeSignaling
    private var peerConnection: RTCPeerConnection? = nil
    private var perfectNegotiator: PerfectNegotiator? = nil
    private let peerName = "client"
    
    init(factory: RTCPeerConnectionFactory, signaling: EdgeSignaling) {
        self.peerConnectionFactory = factory
        self.signaling = signaling
    }
    
    func connect() async throws {
        do {
            try await signaling.start()
        } catch {
            EdgeLogger.error("Failed to initialize signaling service")
            throw error
        }
        
        let turnRequest = SignalMessage(type: .turnRequest)
        
        await signaling.send(turnRequest)
        await waitForTurnResponse()
    }
    
    func createDataChannel(_ label: String) throws -> EdgeDataChannel {
        let config = RTCDataChannelConfiguration()
        let dc = peerConnection?.dataChannel(forLabel: label, configuration: config)
        return EdgeDataChannelImpl(dc!)
    }
    
    func addTrack(_ track: EdgeMediaTrack, streamIds: [String]) throws {
        let t = switch track {
        case let videoTrack as EdgeVideoTrackImpl:
            videoTrack.track
        case let audioTrack as EdgeAudioTrackImpl:
            audioTrack.track
        default:
            throw InvalidTrackError()
        }
        peerConnection?.add(t, streamIds: streamIds)
    }
    
    func close() async {
        peerConnection?.close()
        await signaling.close()
    }

    private func waitForTurnResponse() async {
        var msg: SignalMessage! = nil
        do {
            msg = try await signaling.recv()
        } catch {
            EdgeLogger.error("Failed to receive signaling message: \(error)")
            self.onError?(.signalingFailedRecv)
            return
        }
        
        if msg.type == .turnResponse {
            var iceServers: [RTCIceServer] = []
            if let servers = msg.servers {
                for server in servers {
                    let turn = RTCIceServer(
                        urlStrings: [server.hostname],
                        username: server.username,
                        credential: server.password
                    )
                    
                    iceServers.append(turn)
                }
            }
            
            if let servers = msg.iceServers {
                for server in servers {
                    let turn = RTCIceServer(
                        urlStrings: server.urls,
                        username: server.username,
                        credential: server.credential
                    )
                    
                    iceServers.append(turn)
                }
            }
            
            if iceServers.isEmpty {
                EdgeLogger.error("Turn response message does not include any ice server information!")
            }
            
            setupPeerConnection(iceServers)
        } else {
            EdgeLogger.error("Expected message of type \(SignalMessageType.turnResponse) for setting up connection but received \(msg.type)")
        }
    }
    
    private func setupPeerConnection(_ iceServers: [RTCIceServer]) {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.enableImplicitRollback = true
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        
        peerConnection = peerConnectionFactory.peerConnection(with: config, constraints: constraints, delegate: self)
        perfectNegotiator = PerfectNegotiator(signaling: signaling, peerConnection: peerConnection!, polite: false)
    }
    
    private func error(_ err: EdgeWebrtcError, _ msg: String?) {
        if let msg = msg {
            EdgeLogger.error(msg)
        }
        self.onError?(err)
    }
}

extension EdgePeerConnectionImpl: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        EdgeLogger.info("\(peerName) RtpReceiver \(rtpReceiver.receiverId) added")
        let track = rtpReceiver.track
        if let track = track {
            let transceiver = peerConnection.transceivers.first(where: { transceiver in
                transceiver.receiver.receiverId == rtpReceiver.receiverId
            })
            
            let trackId: String? = if let mid = transceiver?.mid {
                perfectNegotiator?.receivedMetadata[mid]?.trackId
            } else {
                nil
            }
            
            switch (track) {
            case is RTCVideoTrack:
                let videoTrack = track as! RTCVideoTrack
                self.onTrack?(EdgeVideoTrackImpl(track: videoTrack), trackId)
            case is RTCAudioTrack:
                let audioTrack = track as! RTCAudioTrack
                self.onTrack?(EdgeAudioTrackImpl(track: audioTrack), trackId)
                break
            default:
                // This code path is unreachable
                EdgeLogger.error("Track \(track.trackId) was not a video or audio track.")
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        EdgeLogger.info("\(peerName) signaling state changed to \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        EdgeLogger.info("\(peerName) added RTCMediaStream \(stream)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        EdgeLogger.info("\(peerName) removed RTCMediaStream \(stream)")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        EdgeLogger.info("\(peerName) renegotiation needed!")
        // Forward to PerfectNegotiator
        perfectNegotiator?.onRenegotiationNeeded()
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        EdgeLogger.info("\(peerName) ice connection state changed to \(newState)")
        // Forward to PerfectNegotiator
        perfectNegotiator?.onIceConnectionChange(state: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        EdgeLogger.info("\(peerName) ice gathering state changed to \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        EdgeLogger.info("\(peerName) added ice candidate \(candidate)")
        // Forward to PerfectNegotiator
        perfectNegotiator?.onIceCandidate(candidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        EdgeLogger.info("\(peerName) removed ice candidates \(candidates)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        EdgeLogger.info("\(peerName) opened data channel \(dataChannel)")
    }
}
