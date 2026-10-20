#import "RevenantMetal.h"

#ifdef __OBJC__

@protocol MTLFunctionLogDebugLocation <NSObject>
@property (readonly, nullable, nonatomic) NSString *functionName;
@property (readonly, nullable, nonatomic) NSURL *URL;
@property (readonly, nonatomic) NSUInteger line;
@property (readonly, nonatomic) NSUInteger column;
@end

@protocol MTLFunctionLog <NSObject>
@property (readonly, nonatomic) MTLFunctionLogType type;
@property (readonly, nullable, nonatomic) NSString *encoderLabel;
@property (readonly, nullable, nonatomic) id<MTLFunction> function;
@property (readonly, nullable, nonatomic) id<MTLFunctionLogDebugLocation> debugLocation;
@end

@protocol MTLLogContainer <NSObject, NSFastEnumeration>
@end

#endif
