// Declarations for the ModelIO classes the SDK's own headers do not declare.
//
// The 16.4/26.2 SDK's ModelIO.framework declares 66 classes across 21 headers, and the seven names
// this file used to carry here are not among them, because none of them is a class. All seven are
// @protocols the SDK declares with a body, and every one of them is reachable through the umbrella
// a band object imports anyway:
//
//   MDLAssetResolver                    MDLAssetResolver.h:14
//   MDLLightProbeIrradianceDataSource   MDLAsset.h:298
//   MDLMeshBuffer                       MDLMeshBuffer.h:61
//   MDLMeshBufferAllocator              MDLMeshBuffer.h:181
//   MDLObjectContainerComponent         MDLTypes.h:82
//   MDLTransformComponent               MDLTransform.h:27
//   MDLTransformOp                      MDLTransformStack.h:26
//
// Declaring a protocol's name as an @interface here is what a band object's category then attaches
// itself to, and the linker is what says no:
//
//   "_OBJC_CLASS_$_MDLAssetResolver", referenced from:
//       __OBJC_$_CATEGORY_MDLAssetResolver_$_CharonPerClass110 in MDIO110.o
//   "_OBJC_CLASS_$_MDLLightProbeIrradianceDataSource", referenced from:
//       __OBJC_$_CATEGORY_MDLLightProbeIrradianceDataSource_$_CharonMissing90 in MDIO90.o
//   ld: symbol(s) not found for architecture armv7
//
// Seven categories on seven such names emitted seven references no object defined; nm -gU over the
// objects of this directory named exactly those seven undefined, and the two above are the ones
// the band link printed. A category adds methods to a class and never creates one, so no class to
// carry exists to add them to: the requirements belong to the concrete classes that conform to each
// protocol, and MDLRelativeAssetResolver, MDLPathAssetResolver, MDLBundleAssetResolver,
// MDLMeshBufferData, MDLMeshBufferDataAllocator, MDLObjectContainer, MDLTransform, MDLTransformStack
// and the eight MDLTransform*Op classes implement them.
//
// What does belong here is a class the port carries and the SDK does not declare at all: MDLColorSpec,
// which the 16.4 headers forward-declare at MDLLight.h:30 and never declare, and MDLUtility, which
// the 16.4 headers do not mention. The protocols go in CharonModelIOProtocols.h and are carried by
// a row of their own kind, which is what makes the build emit each protocol's metadata.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// MDLUtility is declared by NO header in the SDK the port builds with: the 16.4 ModelIO headers declare 65
// classes and MDLUtility is not among them, while the 26.2 headers declare 66 and DO have an MDLUtility.h.
// The map was built against 26.2 and so emitted an import for a header the gate cannot resolve -
// "fatal error: 'ModelIO/MDLUtility.h' file not found" - and the class then had no declaration at all,
// which is "cannot find interface declaration". The map is now built against the SDK the build uses.
@interface MDLUtility : NSObject
@end


// The per-class categories reach classes the header map does not place, because the map records only
// @interface declarations and these are declared elsewhere or reached through the umbrella indirectly.
@interface MDLColorSpec : NSObject
@end

NS_ASSUME_NONNULL_END
