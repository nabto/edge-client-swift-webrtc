//
//  Signaling.swift
//  
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import NabtoEdgeClient
import CBORCoding
import AsyncAlgorithms

fileprivate struct RTCInfo: Codable {
    let signalingStreamPort: UInt32
    
    enum CodingKeys: String, CodingKey {
        case signalingStreamPort = "SignalingStreamPort"
    }
}

public struct TurnServer: Codable {
    let hostname: String
    let port: Int
    let username: String
    let password: String
}

public struct IceCandidate: Codable {
    let candidate: String
    let sdpMid: String
    let sdpMLineIndex: Int?
}

public struct SignalMessageMetadataTrack: Codable {
    let mid: String
    let trackId: String
}

public struct SignalMessageMetadata: Codable {
    let tracks: [SignalMessageMetadataTrack]?
    let noTrickle: Bool?
}

public enum SignalMessageType: Int, Codable {
    case offer = 0
    case answer = 1
    case iceCandidate = 2
    case turnRequest = 3
    case turnResponse = 4
}

public struct SignalMessage: Codable {
    let type: SignalMessageType
    var data: String? = nil
    var servers: [TurnServer]? = nil
    var metadata: SignalMessageMetadata? = nil
}

public struct SDP: Codable {
    let sdp: String
    let type: String
}

public protocol EdgeSignaling {
    func send(_ msg: SignalMessage) async
    func recv() async throws -> SignalMessage
    func close()
}

// @TODO: Catch and convert errors to our own type of errors?
public class EdgeStreamSignaling: EdgeSignaling {
    private let stream: NabtoEdgeClient.Stream!
    private let messageChannel = AsyncChannel<SignalMessage>()
    
    private let cborDecoder = CBORDecoder()
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    public init(_ conn: Connection) async throws {
        let coap = try conn.createCoapRequest(method: "GET", path: "/webrtc/info")
        let coapResult = await try coap.executeAsync()
        
        if coapResult.status != 205 {
            EdgeLogger.error("Unexpected /webrtc/info return code \(coapResult.status). Failed to initialize signaling service.")
            throw EdgeWebRTCError.signalingFailedToInitialize
        }
        
        var rtcInfo: RTCInfo
        self.stream = try conn.createStream()
        
        if coapResult.contentFormat == 50 {
            rtcInfo = try jsonDecoder.decode(RTCInfo.self, from: coapResult.payload)
        } else if coapResult.contentFormat == 60 {
            rtcInfo = try cborDecoder.decode(RTCInfo.self, from: coapResult.payload)
        } else {
            EdgeLogger.error("/webrtc/info returned invalid content format \(String(describing: coapResult.contentFormat))")
            try self.stream.close()
            throw EdgeWebRTCError.signalingFailedToInitialize
        }
        
        await try self.stream.openAsync(streamPort: rtcInfo.signalingStreamPort)
        
        Task {
            for await msg in messageChannel {
                do {
                    try await writeSignalMessage(msg: msg)
                } catch NabtoEdgeClientError.EOF {
                    EdgeLogger.error("Signaling stream is EOF! Closing signaling service.")
                    break
                } catch NabtoEdgeClientError.STOPPED {
                    EdgeLogger.error("Signaling stream is STOPPED! Closing signaling service.")
                    break
                } catch {
                    EdgeLogger.error("Failed to send signaling message: \(error)")
                }
            }
            
            close()
        }
    }
    
    deinit {
        close()
    }
    
    public func send(_ msg: SignalMessage) async {
        await messageChannel.send(msg)
    }
    
    public func recv() async throws -> SignalMessage {
        return try await readSignalMessage()
    }
    
    public func close() {
        stream.closeAsync { err in
            if err != .OK {
                EdgeLogger.info("Attempting to shut down signaling stream yielded error: \(err)")
            }
        }
    }
    
    private func readSignalMessage() async throws -> SignalMessage {
        let lenData = try await stream.readAllAsync(length: 4)
        let len: Int32 = lenData.withUnsafeBytes { $0.load(as: Int32.self)}
        let data = try await stream.readAllAsync(length: Int(len))
        return try jsonDecoder.decode(SignalMessage.self, from: data)
    }
    
    private func writeSignalMessage(msg: SignalMessage) async throws {
        let encoded = try jsonEncoder.encode(msg)
        let len = UInt32(encoded.count)
        
        var data = Data()
        data.append(contentsOf: withUnsafeBytes(of: len.littleEndian, Array.init))
        data.append(encoded)
        
        try await stream.writeAsync(data: data)
    }
}
