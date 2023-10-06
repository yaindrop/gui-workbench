//
//  RTCScreenCapturer.h
//  CaptureSample
//
//  Created by Yaindrop on 2023/10/1.
//  Copyright © 2023 Apple. All rights reserved.
//

#ifndef RTCCustomVideoCapturer_h
#define RTCCustomVideoCapturer_h

#import <Foundation/Foundation.h>
#import <WebRTC/RTCVideoCapturer.h>

/**
 * RTCVideoCapturer that accepts custom frame
 */
@interface RTCCustomVideoCapturer : RTCVideoCapturer

- (void)onFrame:(RTCVideoFrame *)videoFrame;

@end

#endif /* RTCCustomVideoCapturer_h */
