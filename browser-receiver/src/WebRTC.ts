const Config = {
  signalingServer: 'ws://localhost:8080',
  iceServers: [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
    'stun:stun2.l.google.com:19302',
    'stun:stun3.l.google.com:19302',
    'stun:stun4.l.google.com:19302',
  ],
}

type Message =
  | {
      type: 'IceCandidate'
      payload: RTCIceCandidate
    }
  | {
      type: 'SessionDescription'
      payload: RTCSessionDescription
    }

export class SignalingClient {
  private ws: WebSocket
  onIceCandidate: (candidate: RTCIceCandidate) => void = () => undefined
  onRemoteDescription: (sdp: RTCSessionDescription) => void = () => undefined

  constructor() {
    this.ws = new WebSocket(Config.signalingServer)
    this.ws.onmessage = async (e) => {
      console.log('onmessage', e)
      const text = await e.data.text()
      console.log('text', text)
      const message: Message = JSON.parse(text)
      if (message.type === 'IceCandidate') {
        this.onIceCandidate(new RTCIceCandidate(message.payload))
      } else if (message.type === 'SessionDescription') {
        this.onRemoteDescription(new RTCSessionDescription(message.payload))
      }
    }
  }

  sendIceCandidate(candidate: RTCIceCandidate) {
    this.sendMessage({ type: 'IceCandidate', payload: candidate })
  }

  sendLocalDescription(sdp: RTCSessionDescription) {
    this.sendMessage({ type: 'SessionDescription', payload: sdp })
  }

  private sendMessage(message: Message) {
    this.ws.send(new TextEncoder().encode(JSON.stringify(message)))
  }
}

export class WebRTCClient {
  private pc: RTCPeerConnection
  onTrack: (e: RTCTrackEvent) => void = () => undefined
  onIceCandidate: (candidate: RTCIceCandidate) => void = () => undefined
  onLocalDescription: (sdp: RTCSessionDescription) => void = () => undefined

  constructor() {
    this.pc = new RTCPeerConnection()
    this.pc.setConfiguration({
      iceServers: [{ urls: Config.iceServers }],
    })
    this.pc.addEventListener('track', (e) => this.onTrack(e))
    this.pc.addEventListener(
      'icecandidate',
      (e) => e.candidate && this.onIceCandidate(e.candidate)
    )
  }

  async offer() {
    this.pc.addTransceiver('video', { direction: 'recvonly' })
    try {
      console.warn(1)
      const offer = await this.pc.createOffer({
        offerToReceiveAudio: false,
        offerToReceiveVideo: true,
      })
      await this.pc.setLocalDescription(offer)
      console.warn(2)

      await new Promise<void>((resolve) => {
        if (this.pc.iceGatheringState === 'complete') {
          return resolve()
        }
        const onGatheringStateChange = () => {
          if (this.pc.iceGatheringState === 'complete') {
            this.pc.removeEventListener(
              'icegatheringstatechange',
              onGatheringStateChange
            )
            resolve()
          }
        }
        this.pc.addEventListener(
          'icegatheringstatechange',
          onGatheringStateChange
        )
      })
      console.warn(3)

      this.onLocalDescription(this.pc.localDescription!)
    } catch (e) {
      console.error(e)
    }
  }

  addIceCandidate(candidate: RTCIceCandidate) {
    this.pc.addIceCandidate(candidate)
  }

  setRemoteDescription(sdp: RTCSessionDescription) {
    this.pc.setRemoteDescription(sdp)
  }
}
