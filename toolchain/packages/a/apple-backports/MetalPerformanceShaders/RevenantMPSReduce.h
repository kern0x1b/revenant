#pragma once
#import "RevenantMPS.h"
#import "RevenantMPSImage.h"

typedef NS_ENUM(NSInteger, RevenantMPSReduceOperation) {
    RevenantMPSReduceMin = 0,
    RevenantMPSReduceMax,
    RevenantMPSReduceMean,
    RevenantMPSReduceSum,
};

@interface MPSImageReduceUnary ()
- (instancetype)revenant_initWithDevice:(id<MTLDevice>)device
                            byColumn:(BOOL)byColumn
                            operation:(RevenantMPSReduceOperation)operation;
@end

@interface MPSNNReduceUnary (RevenantMPSNNReduce)
- (instancetype)revenant_nnReduceWithDevice:(id<MTLDevice>)device
                                   byColumn:(BOOL)byColumn
                           byFeatureChannel:(BOOL)byFeatureChannel
                                 operation:(RevenantMPSReduceOperation)operation;
- (float)revenant_nnReduceWeight;
- (void)revenant_setNnReduceWeight:(float)weight;
@end
