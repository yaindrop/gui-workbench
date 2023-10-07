import React, { useState, useEffect, useRef, useCallback } from 'react'

import { SignalingClient, WebRTCClient } from './WebRTC'

import './App.scss'

export function App(): JSX.Element {
  const [webRTCClient] = useState(() => new WebRTCClient())
  const [signallingClient] = useState(() => new SignalingClient())
  const videoRef = useRef<HTMLVideoElement>(null)

  const onStart = useCallback(() => {
    webRTCClient.offer()
  }, [webRTCClient])

  useEffect(() => {
    signallingClient.onIceCandidate = (candidate) => {
      webRTCClient.addIceCandidate(candidate)
    }
    signallingClient.onRemoteDescription = (sdp) => {
      webRTCClient.setRemoteDescription(sdp)
    }
    webRTCClient.onIceCandidate = (candidate) => {
      signallingClient.sendIceCandidate(candidate)
    }
    webRTCClient.onLocalDescription = (sdp) => {
      signallingClient.sendLocalDescription(sdp)
    }
    webRTCClient.onTrack = (e) => {
      console.warn('onTrack', e)
      const { current: video } = videoRef
      video && (video.srcObject = e.streams[0])
    }
  }, [signallingClient, webRTCClient])

  return (
    <div className="App">
      <h1>react-boilerplate</h1>
      <button onClick={onStart}>Start</button>
      <video ref={videoRef} autoPlay playsInline></video>
    </div>
  )
}
