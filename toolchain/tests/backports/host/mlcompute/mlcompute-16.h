#import <Foundation/Foundation.h>
#import <MLCompute/MLCompute.h>

static id CharonNew(Class cls)
{
    return [[cls alloc] init];
}

static id CharonNewOf(NSString *name)
{
    return CharonNew(NSClassFromString(name));
}

@interface MLCMultiheadAttentionLayer (CharonSixteen)
+ (instancetype)layerWithDescriptor:(MLCMultiheadAttentionDescriptor *)descriptor
                             weights:(NSArray<MLCTensor *> *)weights
                              biases:(NSArray<MLCTensor *> *)biases
                      attentionBiases:(NSArray<MLCTensor *> *)attentionBiases;
@end
