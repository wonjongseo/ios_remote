
import ReplayKit
import WebRTC
import SocketIO

class SampleHandler: RPBroadcastSampleHandler {

    // MARK: - Socket.IO
    private var manager: SocketManager!
    private var socket: SocketIOClient!

    // MARK: - WebRTC (non-optional 으로 선언)
    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection!
    private var videoSource: RTCVideoSource!
    private var videoTrack: RTCVideoTrack!
    private var capturer: RTCVideoCapturer!    // 강한 참조

    // MARK: - Config
    private let roomName = "1212"
    private let signalingServerUrl = "http://192.168.3.72:3000"

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        NSLog("✅ 共有始め")

        // SSL / Factory / Source / Capturer 순서 보장
        RTCInitializeSSL()
        let enc = RTCDefaultVideoEncoderFactory()
        let dec = RTCDefaultVideoDecoderFactory()
        peerConnectionFactory = RTCPeerConnectionFactory(encoderFactory: enc, decoderFactory: dec)

        videoSource = peerConnectionFactory.videoSource()
        capturer   = RTCVideoCapturer(delegate: videoSource)
        videoSource.adaptOutputFormat(toWidth: 480, height: 852, fps: Int32(maxFPS)) // 최초 1회만 설정

        // Socket.IO
        manager = SocketManager(
            socketURL: URL(string: signalingServerUrl)!,
            config: [.log(true), .compress]
        )
        socket = manager.defaultSocket

        setupSocketHandlers()
        socket.connect()
    }

    private func setupSocketHandlers() {
        // connect
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            NSLog("📡 Socket.IO connected")
            guard let self = self else { return }
            self.socket.emit("join_room", self.roomName)
            self.createPeerConnection()
        }

        // welcome → offer 보내기
        socket.on("welcome") { [weak self] _, _ in
            guard let self = self else { return }
            self.sendOffer()
        }

        // offer 받기 → answer
        socket.on("offer") { [weak self] data, _ in
            guard let self = self else { return }
            guard let dict = data[0] as? [String:Any],
                  let sdp  = dict["sdp"] as? String else {
                NSLog("❌ offer 파싱 실패")
                return
            }
            NSLog("📨 offer 수신")
            let desc = RTCSessionDescription(type: .offer, sdp: sdp)
            self.peerConnection.setRemoteDescription(desc) { error in
                if let e = error {
                    NSLog("❌ setRemoteDesc 실패: \(e)")
                    return
                }
                self.sendAnswer()
            }
        }

        // answer 받기
        socket.on("answer") { [weak self] data, _ in
            guard let self = self else { return }
            guard let dict = data[0] as? [String:Any],
                  let sdp  = dict["sdp"] as? String else {
                NSLog("❌ answer 파싱 실패")
                return
            }
            NSLog("📨 answer 수신")
            let desc = RTCSessionDescription(type: .answer, sdp: sdp)
            self.peerConnection.setRemoteDescription(desc, completionHandler: nil)
        }

        // ice candidate
        socket.on("ice") { [weak self] data, _ in
            guard let self = self else { return }
            guard let dict = data[0] as? [String:Any],
                  let cand = dict["candidate"] as? String,
                  let mid  = dict["sdpMid"] as? String,
                  let idx  = dict["sdpMLineIndex"] as? Int32 else { return }
            let candidate = RTCIceCandidate(sdp: cand, sdpMLineIndex: idx, sdpMid: mid)
            self.peerConnection.add(candidate)
        }
    }

    private func createPeerConnection() {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

        peerConnection = peerConnectionFactory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )

        videoTrack = peerConnectionFactory.videoTrack(with: videoSource, trackId: "video0")
        let stream = peerConnectionFactory.mediaStream(withStreamId: "stream0")
        stream.addVideoTrack(videoTrack)
        peerConnection.add(stream)
    }

    private func sendOffer() {
        let cons = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveVideo": "false", "OfferToReceiveAudio": "false"],
            optionalConstraints: nil
        )
        peerConnection.offer(for: cons) { [weak self] offer, error in
            guard let self = self else { return }
            guard let o = offer else { return }
            self.peerConnection.setLocalDescription(o) { _ in
                self.socket.emit("offer", ["sdp": o.sdp, "type": "offer"])
                NSLog("✅ offer 전송")
            }
        }
    }

    private func sendAnswer() {
        let cons = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection.answer(for: cons) { [weak self] answer, error in
            guard let self = self else { return }
            
            guard let a = answer else { return }
            self.peerConnection.setLocalDescription(a) { _ in
                self.socket.emit("answer", ["sdp": a.sdp, "type": "answer"])
                NSLog("✅ answer 전송")
            }
        }
    }
    private var lastTimestamp: CFTimeInterval = 0
    private let maxFPS: Double = 15
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video,
                   let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                 return
             }
        let now = CACurrentMediaTime()
        if now - lastTimestamp < (1.0 / maxFPS) {
            return
        }
        lastTimestamp = now
       
        autoreleasepool {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let tsNs = CMTimeGetSeconds(pts) * Double(NSEC_PER_SEC)
            let rtcBuf = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
            let frame  = RTCVideoFrame(buffer: rtcBuf,
                                       rotation: ._0,
                                       timeStampNs: Int64(tsNs))

            videoSource.capturer(capturer, didCapture: frame)
        }
//        NSLog("📦 Throttled frame 전송 at \(Int(maxFPS))fps")
        
//        let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
//        let ns = CMTimeGetSeconds(ts) * Double(NSEC_PER_SEC)
//        let rtcBuf = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
//        let frame  = RTCVideoFrame(buffer: rtcBuf, rotation: ._0, timeStampNs: Int64(ns))
//
//        videoSource.capturer(capturer, didCapture: frame)
//        NSLog("📦 프레임 전송")
    }

    override func broadcastFinished() {
        NSLog("🛑 방송 종료")
        peerConnection.close()
        socket.disconnect()
    }
}

extension SampleHandler: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didGenerate candidate: RTCIceCandidate) {
        socket.emit("ice", [
            "candidate": candidate.sdp,
            "sdpMid":    candidate.sdpMid ?? "",
            "sdpMLineIndex": candidate.sdpMLineIndex
        ])
    }
    // 나머지 delegate 메서드는 빈 구현
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
