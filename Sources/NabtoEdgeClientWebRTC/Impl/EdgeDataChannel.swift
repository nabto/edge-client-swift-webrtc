//
//  File.swift
//  
//
//  Created by Ahmad Saleh on 24/06/2024.
//

import Foundation
import WebRTC
 
public class EdgeDataChannelImpl: NSObject, EdgeDataChannel, RTCDataChannelDelegate {
    internal var dc: RTCDataChannel!
    public var onMessage: EdgeOnMessageCallback? = nil
    public var onOpened: EdgeOnOpenedCallback? = nil
    public var onClosed: EdgeOnClosedCallback? = nil
    
    public init(_ dataChannel: RTCDataChannel) {
        self.dc = dataChannel
        super.init()
        
        self.dc.delegate = self
    }
    
    public func send(_ data: Data) async {
        let buffer = RTCDataBuffer(data: data, isBinary: true)
        self.dc.sendData(buffer)
    }
    
    public func close() async {
        self.dc.close()
    }
    
    public func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        EdgeLogger.info("Data channel \(dataChannel.channelId) state changed to \(dataChannel.readyState)")
        switch dataChannel.readyState {
        case .connecting:
            break
            
        case .open:
            self.onOpened?()
            break
            
        case .closing:
            break
            
        case .closed:
            self.onClosed?()
            break
            
        @unknown default:
            break
        }
    }
    
    public func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        self.onMessage?(buffer.data)
    }
}
