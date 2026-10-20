#import <Intents/Intents.h>

@interface INImage (RevenantIntentsUIImage)
+ (instancetype)revenant_imageWithName:(NSString *)name data:(NSData *)data width:(double)width height:(double)height;
- (NSData *)revenant_imageData;
@end
