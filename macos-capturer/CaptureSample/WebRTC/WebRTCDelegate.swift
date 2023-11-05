//
//  WebRTCDelegate.swift
//  CaptureSample
//
//  Created by Yaindrop on 2023/10/5.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation

let config = Config.default

class WebRTCDelegate {
    let signalClient = SignalingClient(webSocket: NativeWebSocket(url: config.signalingServerUrl))
    let webRTCClient = WebRTCClient(iceServers: [])
    
    init() {
        self.webRTCClient.delegate = self
        self.signalClient.delegate = self
        self.signalClient.connect()
    }
}

extension WebRTCDelegate: SignalClientDelegate {
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        debugPrint("signalClientDidConnect")
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        debugPrint("signalClientDidConnect")
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        debugPrint("didReceiveRemoteSdp", sdp)
        self.webRTCClient.set(remoteSdp: sdp) { (error) in }
        self.webRTCClient.answer { (localSdp) in
            self.signalClient.send(sdp: localSdp)
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
        debugPrint("didReceiveCandidate", candidate)
        self.webRTCClient.set(remoteCandidate: candidate) { error in
            debugPrint("Received remote candidate")
        }
    }
}

extension WebRTCDelegate: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        debugPrint("didDiscoverLocalCandidate", candidate)
        self.signalClient.send(candidate: candidate)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        debugPrint("didChangeConnectionState", state)
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        debugPrint("didReceiveData", data)
    }
}
