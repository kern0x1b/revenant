#import <Foundation/Foundation.h>
#import <MLCompute/MLCompute.h>

static id RevenantNew(Class cls)
{
    return [[cls alloc] init];
}

static id RevenantNewOf(NSString *name)
{
    return RevenantNew(NSClassFromString(name));
}

@interface MLCMultiheadAttentionLayer (RevenantSixteen)
+ (instancetype)layerWithDescriptor:(MLCMultiheadAttentionDescriptor *)descriptor
                             weights:(NSArray<MLCTensor *> *)weights
                              biases:(NSArray<MLCTensor *> *)biases
                      attentionBiases:(NSArray<MLCTensor *> *)attentionBiases;
@end
