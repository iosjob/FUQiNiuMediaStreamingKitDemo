//
//  PLPanelDelegateGenerator.m
//  PLCameraStreamingKitDemo
//
//  Created by TaoZeyu on 16/5/30.
//  Copyright © 2016年 Pili. All rights reserved.
//

#import "PLPanelDelegateGenerator.h"
#import "PLStreamingKitDemoUtils.h"
#import <BlocksKit/NSObject+A2DynamicDelegate.h>

#import "FUDemoManager.h"
@implementation PLPanelDelegateGenerator
{
    PLMediaStreamingSession *_streamingSession;
    int _count;
}

- (instancetype)initWithMediaStreamingSession:(PLMediaStreamingSession *)streamingSession
{
    if (self = [self init]) {
        _streamingSession = streamingSession;
        _isDynamicWatermark = NO;
        _count = 1;
    }
    return self;
}
static  NSTimeInterval oldTime = 0;
- (void)generate
{
    __weak typeof(self) wSelf = self;
    
    NSDictionary *streamStateDictionary = @{@(PLStreamStateUnknow):             @"Unknow",
                                            @(PLStreamStateConnecting):         @"Connecting",
                                            @(PLStreamStateConnected):          @"Connected",
                                            @(PLStreamStateDisconnecting):      @"Disconnecting",
                                            @(PLStreamStateDisconnected):       @"Disconnected",
                                            @(PLStreamStateAutoReconnecting):   @"AutoReconnecting",
                                            @(PLStreamStateError):              @"Error",
                                            };
    NSDictionary *authorizationDictionary = @{@(PLAuthorizationStatusNotDetermined):    @"NotDetermined",
                                              @(PLAuthorizationStatusRestricted):       @"Restricted",
                                              @(PLAuthorizationStatusDenied):           @"Denied",
                                              @(PLAuthorizationStatusAuthorized):       @"Authorized",
                                              };
    [PLDelgateHelper bindTarget:_streamingSession property:@"delegate" block:^(A2DynamicDelegate *d) {
        
        [d implementMethod:@selector(mediaStreamingSession:streamStateDidChange:) withBlock:^(PLMediaStreamingSession *session, PLStreamState state) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wSelf) strongSelf = wSelf;
                NSLog(@"%@", [NSString stringWithFormat:@"session state changed%@", streamStateDictionary[@(state)]]);
                if ([strongSelf.delegate respondsToSelector:@selector(panelDelegateGenerator:streamStateDidChange:)]) {
                    [strongSelf.delegate panelDelegateGenerator:strongSelf streamStateDidChange:state];
                }
            });
        }];
        [d implementMethod:@selector(mediaStreamingSession:didDisconnectWithError:) withBlock:^(PLMediaStreamingSession *session, NSError *error){
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wSelf) strongSelf = wSelf;
                NSLog(@"%@", [NSString stringWithFormat:@"session disconnected due to error %@", error]);
                if ([strongSelf.delegate respondsToSelector:@selector(panelDelegateGenerator:streamDidDisconnectWithError:)]) {
                    [strongSelf.delegate panelDelegateGenerator:strongSelf streamDidDisconnectWithError:error];
                }
            });
        }];
        [d implementMethod:@selector(mediaStreamingSession:streamStatusDidUpdate:) withBlock:^(PLMediaStreamingSession *session, PLStreamStatus *status){
            dispatch_async(dispatch_get_main_queue(), ^{
//                NSLog(@"%@", [NSString stringWithFormat:@"session status %@", status]);
            });
        }];
        [d implementMethod:@selector(mediaStreamingSession:didGetCameraAuthorizationStatus:) withBlock:^(PLMediaStreamingSession *session, PLAuthorizationStatus authorizationStatus){
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"%@", [NSString stringWithFormat:@"camera authorization status changed %@", authorizationDictionary[@(authorizationStatus)]]);
            });
        }];
        [d implementMethod:@selector(mediaStreamingSession:didGetMicrophoneAuthorizationStatus:) withBlock:^(PLMediaStreamingSession *session, PLAuthorizationStatus authorizationStatus){
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"%@", [NSString stringWithFormat:@"microphone  authorization status changed %@", authorizationDictionary[@(authorizationStatus)]]);
            });
        }];
        [d implementMethod:@selector(mediaStreamingSession:cameraSourceDidGetPixelBuffer:) withBlock:^CVPixelBufferRef(PLMediaStreamingSession *session, CVPixelBufferRef pixelBuffer) {
            __strong typeof(wSelf) strongSelf = wSelf;
            NSTimeInterval startTime =  [[NSDate date] timeIntervalSince1970];
            /**     -----  FaceUnity  ----     **/
            if ([FUDemoManager shared].shouldRender) {
                [FUDemoManager updateBeautyBlurEffect];
                FURenderInput *input = [[FURenderInput alloc] init];
                input.renderConfig.imageOrientation = FUImageOrientationUP;
                input.pixelBuffer = pixelBuffer;
                //开启重力感应，内部会自动计算正确方向，设置fuSetDefaultRotationMode，无须外面设置
                input.renderConfig.gravityEnable = YES;
                FURenderOutput *output = [[FURenderKit shareRenderKit] renderWithInput:input];
            }
            NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970];
            /**     -----  FaceUnity  ----     **/
            
            NSLog(@"FU耗时-----%lf,总帧间隔----%lf",(endTime - startTime) * 1000,(oldTime - startTime) * 1000);
            
            oldTime = startTime;
            
            if (strongSelf.needProcessVideo) {
                size_t w = CVPixelBufferGetWidth(pixelBuffer);
                size_t h = CVPixelBufferGetHeight(pixelBuffer);
                size_t par = CVPixelBufferGetBytesPerRow(pixelBuffer);
                CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                uint8_t *pimg = CVPixelBufferGetBaseAddress(pixelBuffer);
                for (int i = 0; i < w; i ++){
                    for (int j = 0; j < h; j++){
                        pimg[j * par + i * 4 + 1] = 255;
                    }
                }
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            }
            
            if (_isDynamicWatermark) {
                ++_count;
                if (_count == 9) {
                    _count = 1;
                }
                NSString *name = [NSString stringWithFormat:@"ear_00%d.png", _count];
                UIImage *waterMark = [UIImage imageNamed:name];
                [session clearWaterMark];
                [session setWaterMarkWithImage:waterMark position:CGPointMake(10, 100)];
            }
            
            return pixelBuffer;
        }];
    }];
}

@end
