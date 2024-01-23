# Edge Client WebRTC Swift library

The Swift Nabto Edge Client library is used for implementing WebRTC over Nabto Edge on Apple platforms. It builds on top of the [Nabto Edge Client for Swift SDK](https://github.com/nabto/edge-client-swift.git). See below for a list of features.

## Features

* Signaling service implemented over [Nabto Edge streams](https://docs.nabto.com/developer/guides/streams/intro.html).
* Establish a WebRTC connection to a device using the signaling service.
* Receive video and audio over WebRTC connection.
* EdgeMetalVideoView, a UIView that you can push video frames to.
* Logging facility, enabled with `EdgeWebRTC.setLogLevel(level: EdgeWebRTCLogLevel)`

## Upcoming

* A minimal example program to show lowest necessary amount of code to receive a video stream from a device.
* Cocoapods support.
* Full v1.0.0 release

## Installation

Edge Client WebRTC for Swift is only available with [Swift Package Manager](https://www.swift.org/documentation/package-manager/). Support for Cocoapods is planned.

To install with Swift Package Manager add the following line to your `Package.swift` file's `dependencies` or add it through Xcode.
```swift
.package(url: "https://github.com/nabto/edge-client-swift-webrtc", .branch("main"))
```

## License
Following is a list of third party distributions that are used in this library and their license.
* [stasel/WebRTC](https://github.com/stasel/WebRTC): BSD 3-Clause License
* [WebRTC](https://webrtc.org/support/license): WebRTC Software License
* [swift-async-algorithms](https://github.com/apple/swift-async-algorithms): Apache 2.0 License
