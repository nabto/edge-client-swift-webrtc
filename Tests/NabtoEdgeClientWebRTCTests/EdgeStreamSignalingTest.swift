import XCTest
import NabtoEdgeClient
@testable import NabtoEdgeClientWebRTC

// XCTest Documentation
// https://developer.apple.com/documentation/xctest

// Defining Test Cases and Test Methods
// https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods

enum MockStreamError: Error {
    case notEnoughBytes
}

class MockStream : SignalingStream {
    var bytes = Data()
    var writtenBytes = Data()
    
    func prepareString(_ str: String) {
        var len = Int32(str.count)
        let lenBytes = withUnsafeBytes(of: len) { Data($0) }
        let strBytes = str.data(using: .utf8)
        bytes.append(lenBytes)
        bytes.append(strBytes!)
    }
    
    func closeAsync() async throws {}
    
    func readAllAsync(length: Int) async throws -> Data {
        if bytes.count < length {
            throw MockStreamError.notEnoughBytes
        }
        
        var result = Data()
        result.append(bytes.prefix(length))
        bytes.removeFirst(length)
        
        return result
    }
    
    func writeAsync(data: Data) async throws {
        writtenBytes.append(data)
    }
}

final class EdgeStreamSignalingTest: XCTestCase {
    var mockStream: MockStream! = nil
    var signaling: EdgeStreamSignaling! = nil
    var jsonDecoder: JSONDecoder! = nil
    
    override func setUp() async throws {
        mockStream = MockStream()
        signaling = try await EdgeStreamSignaling(mockStream)
        jsonDecoder = JSONDecoder()
    }
    
    func testOfferShouldSucceed() async throws {
        mockStream.prepareString("""
            {
                "type": 0,
                "data": "{\\"type\\": \\"offer\\", \\"sdp\\": \\"v=0...\\"}"
            }
        """)
        
        let msg = try await signaling.recv()
        XCTAssertEqual(msg.type, SignalMessageType.offer)
        let sdp = try jsonDecoder.decode(SDP.self, from: (msg.data?.data(using: .utf8)!)!)
        XCTAssertEqual(sdp.type, "offer")
        XCTAssertEqual(sdp.sdp, "v=0...")
    }
    
    func testAnswerShouldSucceed() async throws {
        mockStream.prepareString("""
            {
                "type": 1,
                "data": "{\\"type\\": \\"answer\\", \\"sdp\\": \\"v=0...\\"}"
            }
        """)
        
        let msg = try await signaling.recv()
        XCTAssertEqual(msg.type, SignalMessageType.answer)
        let sdp = try jsonDecoder.decode(SDP.self, from: (msg.data?.data(using: .utf8)!)!)
        XCTAssertEqual(sdp.type, "answer")
        XCTAssertEqual(sdp.sdp, "v=0...")
    }
    
    func testIceCandidateShouldSucceed() async throws {
        mockStream.prepareString("""
            {
                "type": 2,
                "data": "{\\"sdpMid\\": \\"foo\\", \\"candidate\\": \\"bar\\"}"
            }
        """)

        let msg = try await signaling.recv()
        XCTAssertEqual(msg.type, SignalMessageType.iceCandidate)
        let data = msg.data?.data(using: .utf8)
        let candidate = try jsonDecoder.decode(IceCandidate.self, from: data!)
        XCTAssertEqual("foo", candidate.sdpMid)
        XCTAssertEqual("bar", candidate.candidate)
    }
}
