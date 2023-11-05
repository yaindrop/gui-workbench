/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 The app's main view.
 */

import SwiftUI
import ScreenCaptureKit
import OSLog
import Combine

let sharedMemory = SharedMemory()

func getRawData(from pixelBuffer: CVPixelBuffer) -> Data? {
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0)) }
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        return nil
    }
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    return Data(bytes: baseAddress, count: height * bytesPerRow)
}

struct ContentView: View {
    
    @State var userStopped = false
    @State var disableInput = false
    @State var isUnauthorized = false
    
    @StateObject var screenRecorder = ScreenRecorder()
    
    @State var capturePreview: CapturePreview = CapturePreview()
    @State var cancellables: Set<AnyCancellable> = []
    
//    @State var webRTCDelegate = WebRTCDelegate()
    
    var body: some View {
        HSplitView {
            ConfigurationView(screenRecorder: screenRecorder, userStopped: $userStopped)
                .frame(minWidth: 280, maxWidth: 280)
                .disabled(disableInput)
            capturePreview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(screenRecorder.contentSize, contentMode: .fit)
                .padding(8)
                .overlay {
                    if userStopped {
                        Image(systemName: "nosign")
                            .font(.system(size: 250, weight: .bold))
                            .foregroundColor(Color(white: 0.3, opacity: 1.0))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(white: 0.0, opacity: 0.5))
                    }
                }
        }
        .overlay {
            if isUnauthorized {
                VStack() {
                    Spacer()
                    VStack {
                        Text("No screen recording permission.")
                            .font(.largeTitle)
                            .padding(.top)
                        Text("Open System Settings and go to Privacy & Security > Screen Recording to grant permission.")
                            .font(.title2)
                            .padding(.bottom)
                    }
                    .frame(maxWidth: .infinity)
                    .background(.red)
                    
                }
            }
        }
        .navigationTitle("Screen Capture Sample")
        .onAppear {
            Task {
                if await screenRecorder.canRecord {
                    await screenRecorder.start()
                } else {
                    isUnauthorized = true
                    disableInput = true
                }
            }
            screenRecorder.$latestFrame.sink{ frame in
                guard let frame = frame else { return }
                capturePreview.updateFrame(frame)
                guard let pixelBuffer = frame.sampleBuffer.imageBuffer else { return }
                guard let data = getRawData(from: pixelBuffer) else { return }
                print(data.count)
                sharedMemory.sendData(data)
            }.store(in: &cancellables)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
