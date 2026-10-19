#pragma once
#import <Foundation/Foundation.h>
@interface AVVideoPerformanceMetrics : NSObject
@property (readonly) NSUInteger totalNumberOfVideoFrames;
@property (readonly) NSUInteger numberOfDroppedVideoFrames;
@property (readonly) NSUInteger numberOfCorruptedVideoFrames;
@property (readonly) NSUInteger numberOfDisplayCompositedVideoFrames;
@property (readonly) NSTimeInterval totalFrameDelay;
@end
