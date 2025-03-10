//
//  EdgeLogger.swift
//
//
//  Created by Ahmad Saleh on 23/11/2023.
//

import Foundation
import OSLog
import WebRTC

internal class EdgeLogger {
    fileprivate static var nsLogLoggingEnabled = false

    fileprivate static var logger: InternalLogger = {
        let logLevel = EdgeWebrtcLogLevel.error
        if #available(iOS 14.0, OSX 11.0, *) {
            return SwiftLogger(logLevel)
        } else {
            return CompatLogger(logLevel)
        }
    }()
    
    static func enableNsLogLogging() {
        self.nsLogLoggingEnabled = true
    }

    static func setLogLevel(_ level: EdgeWebrtcLogLevel) {
        if level == .verbose {
            // activate internal webrtc logging for verbose
            RTCSetMinDebugLogLevel(.info)
            RTCEnableMetrics()
        }
        logger.logLevel = level
    }
    
    static func error(_ msg: String) {
        logger.log(.error, msg)
    }
    
    static func warning(_ msg: String) {
        logger.log(.warning, msg)
    }
    
    static func info(_ msg: String) {
        logger.log(.info, msg)
    }
    
    static func verbose(_ msg: String) {
        logger.log(.verbose, msg)
    }
}

fileprivate protocol InternalLogger {
    func log(_ msgLevel: EdgeWebrtcLogLevel, _ msg: String)
    var logLevel: EdgeWebrtcLogLevel { get set }
}

@available(iOS 14.0, *)
fileprivate class SwiftLogger: InternalLogger {
    var logLevel: EdgeWebrtcLogLevel
    let logger = Logger()
    
    init(_ logLevel: EdgeWebrtcLogLevel) {
        self.logLevel = logLevel
    }
    
    func log(_ msgLevel: EdgeWebrtcLogLevel, _ msg: String) {
        if EdgeLogger.nsLogLoggingEnabled {
            NSLog("EdgeWebRTC: %@", msg)
            return
        }
        if msgLevel.rawValue <= logLevel.rawValue {
            switch msgLevel {
            case .verbose:
                logger.debug("EdgeWebRTC: \(msg)")
            case .error:
                logger.error("EdgeWebRTC: \(msg)")
            case .warning:
                logger.warning("EdgeWebRTC: \(msg)")
            case .info:
                logger.info("EdgeWebRTC: \(msg)")
            }
        }
    }
}

fileprivate class CompatLogger: InternalLogger {
    var logLevel: EdgeWebrtcLogLevel
    
    init(_ logLevel: EdgeWebrtcLogLevel) {
        self.logLevel = logLevel
    }
    
    func log(_ msgLevel: EdgeWebrtcLogLevel, _ msg: String) {
        if msgLevel.rawValue <= logLevel.rawValue {
            if EdgeLogger.nsLogLoggingEnabled {
                NSLog("EdgeWebRTC: %@", msg)
                return
            }
            switch msgLevel {
            case .verbose:
                os_log("EdgeWebRTC: %@", log: .default, type: .debug, msg)
            case .error:
                os_log("EdgeWebRTC: %@", log: .default, type: .error, msg)
            case .warning:
                os_log("EdgeWebRTC: %@", log: .default, type: .error, msg)
            case .info:
                os_log("EdgeWebRTC: %@", log: .default, type: .info, msg)
            }
        }
    }
}
