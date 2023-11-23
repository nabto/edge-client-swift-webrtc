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
    let fileStreamPort: UInt32
    let signalingStreamPort: UInt32
    
    enum CodingKeys: String, CodingKey {
        case fileStreamPort = "FileStreamPort"
        case signalingStreamPort = "SignalingStreamPort"
    }
}

struct TurnServer: Codable {
    let hostname: String
    let port: Int
    let username: String
    let password: String
}

struct IceCandidate: Codable {
    let candidate: String
    let sdpMid: String
    let sdpMLineIndex: Int?
}

struct SignalMessageMetadataTrack: Codable {
    let mid: String
    let trackId: String
}

struct SignalMessageMetadata: Codable {
    let tracks: [SignalMessageMetadataTrack]
    let noTrickle: Bool
}

enum SignalMessageType: Int, Codable {
    case offer = 0
    case answer = 1
    case iceCandidate = 2
    case turnRequest = 3
    case turnResponse = 4
}

struct SignalMessage: Codable {
    let type: SignalMessageType
    var data: String? = nil
    var servers: [TurnServer]? = nil
    var metadata: SignalMessageMetadata? = nil
}

struct SDP: Codable {
    let sdp: String
    let type: String
}

protocol EdgeSignaling {
    func send(_ msg: SignalMessage) async
    func recv() async throws -> SignalMessage
}

// @TODO: Catch and convert errors to our own type of errors?
class EdgeStreamSignaling: EdgeSignaling {
    private let stream: NabtoEdgeClient.Stream
    private let messageChannel = AsyncChannel<SignalMessage>()
    
    private let cborDecoder = CBORDecoder()
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    init(_ conn: Connection) throws {
        let coap = try conn.createCoapRequest(method: "GET", path: "/webrtc/info")
        let coapResult = try coap.execute()
        
        if coapResult.status != 205 {
            print("Unexpected /webrtc/info return code \(coapResult.status)")
        }
        
        let rtcInfo = try cborDecoder.decode(RTCInfo.self, from: coapResult.payload)
        self.stream = try conn.createStream()
        try self.stream.open(streamPort: rtcInfo.signalingStreamPort)
        
        Task {
            for await msg in messageChannel {
                do {
                    try await writeSignalMessage(msg: msg)
                } catch {
                    // @TODO: Check if the error pertains to the stream
                    //        e.g. if the stream is closed, we should invalidate this EdgeSignaling object.
                    debugPrint("Failed to send signaling message: \(error)")
                }
            }
        }
    }
    
    func send(_ msg: SignalMessage) async {
        await messageChannel.send(msg)
    }
    
    func recv() async throws -> SignalMessage {
        return try await readSignalMessage()
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
