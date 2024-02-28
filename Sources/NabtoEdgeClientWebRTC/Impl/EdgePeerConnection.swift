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
    var onConnected: EdgeOnConnectedCallback? = nil
    var onClosed: EdgeOnClosedCallback? = nil
    var onTrack: EdgeOnTrackCallback? = nil
    var onError: EdgeOnErrorCallback? = nil
    
    private var peerConnection: RTCPeerConnection?
    private var signaling: EdgeSignaling!
    private let jsonDecoder = JSONDecoder()
    private var conn: Connection?
    
    deinit {
        close()
    }
    
    init(_ conn: Connection) {
        super.init()
        self.conn = conn
    }
    
    func connect() async throws {
        self.signaling = await try EdgeStreamSignaling(conn!)
        Task {
            await messageLoop()
        }
    }
    
    func close() {
        signaling.close()
        peerConnection?.close()
        self.conn = nil
    }
    
    private func error(_ err: EdgeWebRTCError, _ msg: String?) {
        if let msg = msg {
            EdgeLogger.error(msg)
        }
        self.onError?(err)
    }
    
    private func createOffer(_ pc: RTCPeerConnection) async -> RTCSessionDescription {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        return await withCheckedContinuation { continuation in
            pc.offer(for: constraints) { (sdp, error) in
                guard let sdp = sdp else { return }
                continuation.resume(returning: sdp)
            }
        }
    }
    
    private func createAnswer(_ pc: RTCPeerConnection) async -> RTCSessionDescription {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        return await withCheckedContinuation { continuation in
            pc.answer(for: constraints) { (sdp, error) in
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
        self.onConnected?()
    }
    
    private func messageLoop() async {
        await signaling.send(SignalMessage(type: .turnRequest))
        
        while true {
            var msg: SignalMessage? = nil
            do {
                msg = try await signaling.recv()
            } catch NabtoEdgeClientError.EOF {
                EdgeLogger.info("Signaling stream is EOF! Closing message loop.")
                break
            } catch NabtoEdgeClientError.STOPPED {
                EdgeLogger.info("Signaling stream is STOPPED! Closing message loop.")
                break
            } catch {
                self.error(.signalingFailedRecv, "Failed to receive signaling message: \(error)")
                msg = nil
            }
            
            guard let msg = msg else {
                continue
            }
            
            EdgeLogger.info("Received signaling message of type \(msg.type)")
            
            switch msg.type {
            case .answer:
                do {
                    let answer = try jsonDecoder.decode(SDP.self, from: msg.data!.data(using: .utf8)!)
                    let sdp = RTCSessionDescription(type: RTCSdpType.answer, sdp: answer.sdp)
                    try await self.peerConnection!.setRemoteDescription(sdp)
                } catch {
                    self.error(.setRemoteDescriptionError, "Failed handling ANSWER message: \(error)")
                }
                break
                
            case .offer:
                do {
                    let offer = try jsonDecoder.decode(SDP.self, from: msg.data!.data(using: .utf8)!)
                    let sdp = RTCSessionDescription(type: RTCSdpType.offer, sdp: offer.sdp)
                    try await self.peerConnection!.setRemoteDescription(sdp)
                } catch {
                    self.error(.setRemoteDescriptionError, "Failed handling OFFER message: \(error)")
                }
                
                do {
                    let answer = await createAnswer(self.peerConnection!)
                    try await self.peerConnection!.setLocalDescription(answer)
                    let msg = SignalMessage(type: .answer, data: answer.toJSON())
                    await signaling.send(msg)
                } catch {
                    self.error(.sendAnswerError, "Failed sending an answer to offer message: \(error)")
                }
                
            case .iceCandidate:
                do {
                    let cand = try jsonDecoder.decode(IceCandidate.self, from: msg.data!.data(using: .utf8)!)
                    try await self.peerConnection!.add(RTCIceCandidate(
                        sdp: cand.candidate,
                        sdpMLineIndex: 0,
                        sdpMid: cand.sdpMid
                    ))
                } catch {
                    self.error(.iceCandidateError, "Failed handling ICE candidate message: \(error)")
                }
                break
                
            case .turnResponse:
                guard let turnServers = msg.servers else {
                    self.error(.connectionInitError, "Received a TURN response message without any servers listed.")
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
                break
                
            default:
                self.error(.signalingInvalidMessage, "Signaling message had unexpected type: \(msg.type)")
                break
            }
        }
    }
}

// MARK: RTCPeerConnectionDelegate implementation
extension EdgePeerConnectionImpl: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        EdgeLogger.info("Signaling state changed to \((try? stateChanged.description()) ?? "invalid RTCSignalingState")")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        EdgeLogger.info("New RTCMediaStream \(stream.streamId) added")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        EdgeLogger.info("New RtpReceiver \(rtpReceiver.receiverId) added")
        let track = rtpReceiver.track
        if let track = track {
            switch (track) {
            case is RTCVideoTrack:
                let videoTrack = track as! RTCVideoTrack
                self.onTrack?(EdgeVideoTrackImpl(track: videoTrack))
            case is RTCAudioTrack:
                let audioTrack = track as! RTCAudioTrack
                self.onTrack?(EdgeAudioTrackImpl(track: audioTrack))
                break
            default:
                // This code path is unreachable
                EdgeLogger.error("Track \(track.trackId) was not a video or audio track.")
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        EdgeLogger.info("RTCMediaStream \(stream.streamId) removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        EdgeLogger.info("Peer connection should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        EdgeLogger.info("ICE connection state changed to: \((try? newState.description()) ?? "invalid RTCIceConnectionState")")
        if newState == .closed {
            self.onClosed?()
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        EdgeLogger.info("ICE gathering state changed to: \((try? newState.description()) ?? "invalid RTCIceGatheringState")")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        EdgeLogger.info("New ICE candidate generated: \(candidate.sdp)")
        Task {
            await signaling.send(SignalMessage(
                type: .iceCandidate,
                data: candidate.toJSON()
            ))
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        EdgeLogger.info("ICE candidate removed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen candidate: RTCDataChannel) {
        EdgeLogger.info("Data channel \(candidate.channelId) opened")
    }
}
