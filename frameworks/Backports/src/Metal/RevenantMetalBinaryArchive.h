#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface RevenantMetalBinaryArchive : NSObject <MTLBinaryArchive>

- (instancetype)initWithDevice:(id<MTLDevice>)device descriptor:(MTLBinaryArchiveDescriptor *)descriptor error:(NSError **)error;

@end
