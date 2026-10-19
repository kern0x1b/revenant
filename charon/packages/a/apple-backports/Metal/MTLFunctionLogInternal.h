#import "CharonMetal.h"

// What the SDK this package builds against does not declare, and the 26.2 header does.
//
// MTLFunctionLog, MTLFunctionLogDebugLocation and MTLLogContainer arrived in iOS 14.0: the 16.4 SDK
// FORWARD-DECLARES the first two in MTLCommandBuffer.h:22 and never defines them, and it does not
// define MTLLogContainer at all, while 26.2's MTLFunctionLog.h declares all three and
// MTLCommandBuffer.h:283 hands out an `id<MTLLogContainer>`. So the port DECLARES them itself, which
// is the standing rule for a class the release lacks: it is carried, not omitted.
//
// Their members are transcribed from 26.2 as facts and carry no Apple bodies, exactly as
// CharonMetalProtocols.h does for the protocols the SDK lacks. The 26.2 lines each came from are named
// beside them, so a reader can check a spelling without guessing which SDK it was read from.
//
// This header is NOT installed. It is a private header of the package, included by the 14.0 object and
// by nothing else.
#ifdef __OBJC__

@protocol MTLFunctionLogDebugLocation <NSObject>
// 26.2 MTLFunctionLog.h:13 - the only member of the type is the triple below; the rest are the
// three nullable strings and the URL that name where a fault happened.
@property (readonly, nullable, nonatomic) NSString *functionName;
@property (readonly, nullable, nonatomic) NSURL *URL;
@property (readonly, nonatomic) NSUInteger line;
@property (readonly, nonatomic) NSUInteger column;
@end

@protocol MTLFunctionLog <NSObject>
// 26.2 MTLFunctionLog.h:18.
@property (readonly, nonatomic) MTLFunctionLogType type;
@property (readonly, nullable, nonatomic) NSString *encoderLabel;
@property (readonly, nullable, nonatomic) id<MTLFunction> function;
@property (readonly, nullable, nonatomic) id<MTLFunctionLogDebugLocation> debugLocation;
@end

// 26.2 MTLCommandBuffer.h:22 forward-declares it and :283 hands one out. It is NSFastEnumeration, and
// it declares no member of its own - so the PORT declares the protocol and its container
// CONFORMS, and the enumeration is what the header's <NSFastEnumeration> asks for.
@protocol MTLLogContainer <NSObject, NSFastEnumeration>
@end

#endif
