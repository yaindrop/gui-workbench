import cv2
from pydantic import BaseModel, Field, parse_obj_as
import json
from typing import Annotated, Literal, Union
import websockets.client
from aiortc import RTCPeerConnection, RTCIceCandidate, RTCSessionDescription, VideoStreamTrack, RTCConfiguration, RTCIceServer
from aiortc.sdp import candidate_from_sdp
from reactivex.subject import Subject
import asyncio


class IceCandidateData(BaseModel):
    candidate: str
    sdpMid: str
    sdpMLineIndex: int


class SessionDescriptionData(BaseModel):
    type: str
    sdp: str


class IceCandidateMessage(BaseModel):
    type: Literal['IceCandidate']
    payload: IceCandidateData


class SessionDescriptionMessage(BaseModel):
    type: Literal['SessionDescription']
    payload: SessionDescriptionData


Message = Annotated[Union[IceCandidateMessage,
                          SessionDescriptionMessage], Field(discriminator="type")]

local_sdp_subject = Subject[RTCSessionDescription]()
remote_sdp_subject = Subject[RTCSessionDescription]()
remote_ice_subject = Subject[RTCIceCandidate]()


class SignalingClient:
    def __init__(self):
        self.ws = None

    async def connect(self, uri: str):
        async with websockets.client.connect(uri) as ws:
            self.ws = ws
            async for message in ws:
                await self._on_message(message.decode())

    async def _on_message(self, data: str):
        m = parse_obj_as(Message, json.loads(data))
        if m.type == 'IceCandidate':
            candidate = candidate_from_sdp(
                m.payload.candidate.split(":", 1)[1])
            candidate.sdpMid = m.payload.sdpMid
            candidate.sdpMLineIndex = m.payload.sdpMLineIndex
            remote_ice_subject.on_next(candidate)
        elif m.type == 'SessionDescription':
            sdp = RTCSessionDescription(m.payload.sdp, m.payload.type)
            remote_sdp_subject.on_next(sdp)

    async def send_message(self, message: BaseModel):
        if self.ws:
            await self.ws.send(message.json().encode())


class CustomVideoStreamTrack(VideoStreamTrack):
    kind = "video"

    def __init__(self, track: VideoStreamTrack):
        print("CustomVideoStreamTrack")
        super().__init__()  # don't forget to call super()
        self.track = track

    async def recv(self):
        print("in recv")
        frame = await self.track.recv()
        print("frame", frame)
        frame_np = frame.to_ndarray(format="yuv420p")
        cv2.imshow('Received Frame', frame_np)
        cv2.waitKey(1)
        return frame


custom_track: CustomVideoStreamTrack | None = None


class WebRTCClient:
    def __init__(self):
        self.pc = RTCPeerConnection(configuration=RTCConfiguration(
            iceServers=[RTCIceServer(urls='stun:stun.l.google.com:19302')]))
        self.pc.on("track", self._on_track)

        def on_iceconnectionstatechange():
            print("ICE Connection State:", self.pc.iceConnectionState)
        self.pc.on("iceconnectionstatechange", on_iceconnectionstatechange)

    def _on_track(self, track: VideoStreamTrack):
        print("on_track", track, track.kind, track.readyState)
        if track.kind == "video":
            self.pc.addTrack(CustomVideoStreamTrack(track))

    async def offer(self):
        self.pc.addTransceiver("video", direction="sendrecv")
        offer = await self.pc.createOffer()
        await self.pc.setLocalDescription(offer)
        local_sdp_subject.on_next(offer)


async def main():
    signaling_client = SignalingClient()
    webrtc_client = WebRTCClient()

    def on_local_sdp(sdp: RTCSessionDescription):
        print("on_local_sdp", sdp)
        asyncio.create_task(signaling_client.send_message(SessionDescriptionMessage(
            type='SessionDescription', payload=SessionDescriptionData(type=sdp.type, sdp=sdp.sdp))))
    local_sdp_subject.subscribe(on_local_sdp)

    def on_remote_sdp(sdp: RTCSessionDescription):
        print("on_remote_sdp", sdp)
        asyncio.create_task(webrtc_client.pc.setRemoteDescription(sdp))
    remote_sdp_subject.subscribe(on_remote_sdp)

    def on_remote_ice(ice: RTCIceCandidate):
        print("on_remote_ice", ice)
        asyncio.create_task(webrtc_client.pc.addIceCandidate(ice))
    remote_ice_subject.subscribe(on_remote_ice)

    asyncio.create_task(signaling_client.connect("ws://localhost:8080"))
    asyncio.create_task(webrtc_client.offer())


if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.create_task(main())
    loop.run_forever()
