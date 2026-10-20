#import <Foundation/Foundation.h>
#import <MLCompute/MLCompute.h>

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define REVENANT_MLC_MAX_DIMENSIONS 4

NSUInteger RevenantMLCWidthOfDataType(MLCDataType dataType);

NSUInteger RevenantMLCElementCount(NSArray<NSNumber *> *shape);

NSArray<NSNumber *> *RevenantMLCStrideOfShape(NSArray<NSNumber *> *shape, MLCDataType dataType);

NSUInteger RevenantMLCNextTensorID(void);
NSUInteger RevenantMLCNextLayerID(void);

@interface RevenantMLCOptimizerState : NSObject
@property (readwrite, nonatomic) float learningRate;
@property (readwrite, nonatomic) float gradientRescale;
@property (readwrite, nonatomic) BOOL appliesGradientClipping;
@property (readwrite, nonatomic) MLCGradientClippingType gradientClippingType;
@property (readwrite, nonatomic) float gradientClipMax;
@property (readwrite, nonatomic) float gradientClipMin;
@property (readwrite, nonatomic) MLCRegularizationType regularizationType;
@property (readwrite, nonatomic) float regularizationScale;
@property (readwrite, nonatomic) float maximumClippingNorm;
@property (readwrite, nonatomic) float customGlobalNorm;
@property (readwrite, nonatomic) float momentumScale;
@property (readwrite, nonatomic) BOOL usesNesterovMomentum;
@property (readwrite, nonatomic) float beta1;
@property (readwrite, nonatomic) float beta2;
@property (readwrite, nonatomic) float epsilon;
@property (readwrite, nonatomic) BOOL usesAMSGrad;
@property (readwrite, nonatomic) NSUInteger timeStep;
@end

@interface MLCOptimizer (RevenantMLCOptimizerState)
- (RevenantMLCOptimizerState *)revenant_mlc_state;
- (void)revenant_mlc_takeStateFrom:(MLCOptimizerDescriptor *)descriptor;
+ (instancetype)revenant_mlc_optimizerOfClass:(Class)cls copying:(MLCOptimizer *)other;
- (void)revenant_mlc_setState:(RevenantMLCOptimizerState *)state;
@end
