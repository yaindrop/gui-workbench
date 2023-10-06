//
//  RTCScreenCapturer.m
//  CaptureSample
//
//  Created by Yaindrop on 2023/10/1.
//  Copyright © 2023 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RTCCustomVideoCapturer.h"

@implementation RTCCustomVideoCapturer {

}

- (void)onFrame:(RTCVideoFrame *)videoFrame {
    [self.delegate capturer:self didCaptureVideoFrame:videoFrame];
}

@end
