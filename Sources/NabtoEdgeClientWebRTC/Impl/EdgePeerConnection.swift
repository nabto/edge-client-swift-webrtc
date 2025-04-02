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

fileprivate struct RTCInfo: Codable {
    let signalingStreamPort: UInt32

    enum CodingKeys: String, CodingKey {
        case signalingStreamPort = "SignalingStreamPort"
    }
}

internal class EdgePeerConnectionImpl: NSObject, EdgePeerConnection {
    var onClosed: EdgeOnClosedCallback? = nil
    var onTrack: EdgeOnTrackCallback? = nil
    var onError: EdgeOnErrorCallback? = nil

    private var loopTask: Task<(), Error>? = nil
    private var signaling: EdgeSignaling? = nil
    private var receivedMetadata: [String: SignalMessageMetadataTrack] = [:]

    private var peerConnection: RTCPeerConnection?
    private let jsonDecoder = JSONDecoder()
    private var conn: Connection?

    private var isPolite = true
    private var isMakingOffer = false
    private var ignoreOffer = false


    init(_ conn: Connection) {
        super.init()
        self.conn = conn
    }

    deinit {
        loopTask?.cancel()
        peerConnection?.close()

        self.peerConnection = nil
        self.loopTask = nil
        self.conn = nil
    }

    func getPeerConnection() -> RTCPeerConnection? {
        return self.peerConnection
    }

    func connect() async throws {
        try await withUnsafeThrowingContinuation { continuation in
            loopTask = Task {
                guard let conn = conn else {
                    EdgeLogger.error("Nabto connection is nil. Failed to establish WebRTC connection.")
                    throw EdgeWebrtcError.signalingFailedToInitialize
                }

                let coap = try conn.createCoapRequest(method: "GET", path: "/p2p/webrtc-info")
                let coapResult = try await coap.executeAsync()

                if coapResult.status != 205 {
                    EdgeLogger.error("Unexpected /p2p/webrtc-info return code \(coapResult.status). Failed to initialize signaling service.")
                    throw EdgeWebrtcError.signalingFailedToInitialize
                }

                var rtcInfo: RTCInfo
                let stream = try conn.createStream()

                let cborDecoder = CBORDecoder()
                let jsonDecoder = JSONDecoder()
                if coapResult.contentFormat == 50 {
                    rtcInfo = try jsonDecoder.decode(RTCInfo.self, from: coapResult.payload)
                } else if coapResult.contentFormat == 60 {
                    rtcInfo = try cborDecoder.decode(RTCInfo.self, from: coapResult.payload)
                } else {
                    EdgeLogger.error("/p2p/webrtc-info returned invalid content format \(String(describing: coapResult.contentFormat))")
                    try stream.close()
                    throw EdgeWebrtcError.signalingFailedToInitialize
                }

                try await stream.openAsync(streamPort: rtcInfo.signalingStreamPort)

                self.signaling = try await EdgeStreamSignaling(stream)
                await messageLoop(continuation)
            }
        }
    }

    func close() async {
        await signaling?.close()
        loopTask?.cancel()
        peerConnection?.close()

        self.signaling = nil
        self.peerConnection = nil
        self.loopTask = nil
        self.conn = nil
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

    private func error(_ err: EdgeWebrtcError, _ msg: String?) {
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

    private func sendDescription(_ description: RTCSessionDescription) async throws {
        let type = description.type == .answer ? SignalMessageType.answer : SignalMessageType.offer
        let msg = SignalMessage(type: type, data: description.toJSON(), metadata: createMetadata())
        await signaling?.send(msg)
    }

    private func createMetadata() -> SignalMessageMetadata {
        var tracks: [SignalMessageMetadataTrack] = []

        peerConnection?.transceivers.forEach { transceiver in
            let metaTrack = receivedMetadata[transceiver.mid]
            if let metaTrack = metaTrack {
                tracks.append(metaTrack)
            }
            // @TODO: If we consider adding addTrack to this API then we will have to generate metadata for added tracks here.
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

    private func handleMetadata(_ data: SignalMessageMetadata) {
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

    private func handleDescription(_ description: RTCSessionDescription?, metadata: SignalMessageMetadata?) async {
        guard let description = description else {
            EdgeLogger.error("SDP is nil in handleDescription. Ensure your signaling is functional!")
            return
        }

        guard let pc = peerConnection else {
            EdgeLogger.error("handleDescription failed: peer connection is not open.")
            return
        }

        let offerCollision = description.type == .offer && (isMakingOffer || pc.signalingState == .stable)
        ignoreOffer = !isPolite && offerCollision

        if ignoreOffer {
            EdgeLogger.info("Ignoring offer...")
            return
        }

        if let metadata = metadata {
            handleMetadata(metadata)
        }

        do {
            try await pc.setRemoteDescription(description)
        } catch {
            self.error(.setRemoteDescriptionError, "Setting remote SDP failed: \(error)")
        }

        if pc.remoteDescription?.type == .offer {
            do {
                try await pc.setLocalDescription()
                try await sendDescription(pc.localDescription!)
            } catch {
                self.error(.sendAnswerError, "Failed sending an answer to offer message: \(error)")
            }
        }
    }

    private func startPeerConnection(_ config: RTCConfiguration) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let peerConnection = EdgeWebrtc.factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            fatalError("Failed to create RTCPeerConnection")
        }

        self.peerConnection = peerConnection
    }

    private func messageLoop(_ connectContinuation: UnsafeContinuation<Void, Error>) async {
        var hasResumed = false
        func reject(_ err: Error) {
            if !hasResumed {
                hasResumed = true
                connectContinuation.resume(throwing: err)
            }
        }

        func resolve() {
            if !hasResumed {
                hasResumed = true
                connectContinuation.resume()
            }
        }

        // @TODO: call reject(signalingFailedToSend) when this fails (need to change signaling API to throw errors)
        await signaling?.send(SignalMessage(type: .turnRequest))

        while !Task.isCancelled {
            var msg: SignalMessage? = nil
            do {
                msg = try await signaling?.recv()
            } catch NabtoEdgeClientError.EOF {
                EdgeLogger.info("Signaling stream is EOF! Closing message loop.")
                reject(EdgeWebrtcError.signalingFailedRecv)
                break
            } catch NabtoEdgeClientError.STOPPED {
                EdgeLogger.info("Signaling stream is STOPPED! Closing message loop.")
                reject(EdgeWebrtcError.signalingFailedRecv)
                break
            } catch {
                self.error(.signalingFailedRecv, "Failed to receive signaling message: \(error)")
                reject(EdgeWebrtcError.signalingFailedRecv)
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
                    await handleDescription(sdp, metadata: msg.metadata)
                } catch {
                    self.error(.setRemoteDescriptionError, "Failed handling ANSWER message: \(error)")
                }
                break

            case .offer:
                do {
                    let offer = try jsonDecoder.decode(SDP.self, from: msg.data!.data(using: .utf8)!)

//                  do {
//                    let lines = offer.sdp.components(separatedBy: "\r\n")
//                    print("Type:", offer.type)
//                    print("SDP Offer:")
//                    for line in lines {
//                      guard !line.isEmpty else { continue }
//                      EdgeLogger.info("    OFFER: \(line)");
//                    }
//                  } catch {
//                    print("Error decoding SDP:", error)
//                  }
//
                    let sdp = RTCSessionDescription(type: RTCSdpType.offer, sdp: offer.sdp)
                    await handleDescription(sdp, metadata: msg.metadata)
                } catch {
                    self.error(.setRemoteDescriptionError, "Failed handling OFFER message: \(error)")
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
                resolve()
                break

            default:
                self.error(.signalingInvalidMessage, "Signaling message had unexpected type: \(msg.type)")
                reject(EdgeWebrtcError.signalingInvalidMessage)
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
            let transceiver = peerConnection.transceivers.first(where: { transceiver in
                transceiver.receiver.receiverId == rtpReceiver.receiverId
            })

            let trackId: String? = if let mid = transceiver?.mid {
                receivedMetadata[mid]?.trackId
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

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        EdgeLogger.info("RTCMediaStream \(stream.streamId) removed")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        EdgeLogger.info("Peer connection should renegotiate")
        Task {
            defer {
                isMakingOffer = false
            }

            do {
                isMakingOffer = true
                try await peerConnection.setLocalDescription()
                try await sendDescription(peerConnection.localDescription!)
            } catch {
                EdgeLogger.error("Renegotiation failed to create and send a local description: \(error)")
            }

            isMakingOffer = false
        }
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
            await signaling?.send(SignalMessage(
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
