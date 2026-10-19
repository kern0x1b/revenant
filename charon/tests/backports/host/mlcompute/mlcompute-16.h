// What the cases reach for that the current header does not name. There is no member of MLCompute 14 that
// MLCompute 26's headers dropped and that the corpus of SDK 26.2 still names: +[MLCTensor tensorWithShape:]
// and +[MLCTensorDescriptor descriptorWithShape:] are in both SDKs, and the one-argument forms the
// framework no longer declares - +descriptorWithShape: on its own, +tensorWithShape:data:,
// +tensorWithShape:fillWithData: - are in neither the corpus nor the framework, which answers
// unrecognised selector for them. So this file declares no member of its own.
//
// What it does carry is the second half: the initialisers MLCompute's own header marks unavailable, on
// the classes below. A program cannot name them through the class, so the cases reach them through a
// Class, which is a runtime lookup and not a link-time reference.
#import <Foundation/Foundation.h>
#import <MLCompute/MLCompute.h>

// MLCompute's own header marks +new and -init unavailable on the classes below. The framework carries them
// all and a program can reach them through a Class, so the cases ask that way rather than by a name the
// compiler refuses.
static id CharonNew(Class cls)
{
    return [[cls alloc] init];
}

static id CharonNewOf(NSString *name)
{
    return CharonNew(NSClassFromString(name));
}

// The multihead attention layer, which MLCompute 26's macOS header marks gone past macOS 14 and a Mac
// Catalyst build therefore cannot name at all - the class is removed from the interface, not merely
// marked unavailable, so no pragma brings it back. The port carries it: the iOS header declares it for
// iOS 14, where it is not deprecated, and the corpus of SDK 26.2 names it. Declared here, as a category
// with no implementation, so that the one case for its factory is asked of the port - which is all that
// can be asked of it, and the reason the case does not compare two runs.
@interface MLCMultiheadAttentionLayer (CharonSixteen)
+ (instancetype)layerWithDescriptor:(MLCMultiheadAttentionDescriptor *)descriptor
                             weights:(NSArray<MLCTensor *> *)weights
                              biases:(NSArray<MLCTensor *> *)biases
                      attentionBiases:(NSArray<MLCTensor *> *)attentionBiases;
@end
