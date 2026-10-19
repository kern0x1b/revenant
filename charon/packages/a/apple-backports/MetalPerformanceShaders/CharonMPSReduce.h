#pragma once
#import "CharonMPS.h"
#import "CharonMPSImage.h"

typedef NS_ENUM(NSInteger, CharonMPSReduceOperation) {
    CharonMPSReduceMin = 0,
    CharonMPSReduceMax,
    CharonMPSReduceMean,
    CharonMPSReduceSum,
};

@interface MPSImageReduceUnary ()
- (instancetype)charon_initWithDevice:(id<MTLDevice>)device
                            byColumn:(BOOL)byColumn
                            operation:(CharonMPSReduceOperation)operation;
@end

@interface MPSNNReduceUnary (CharonMPSNNReduce)
- (instancetype)charon_nnReduceWithDevice:(id<MTLDevice>)device
                                   byColumn:(BOOL)byColumn
                           byFeatureChannel:(BOOL)byFeatureChannel
                                 operation:(CharonMPSReduceOperation)operation;
- (float)charon_nnReduceWeight;
- (void)charon_setNnReduceWeight:(float)weight;
@end
