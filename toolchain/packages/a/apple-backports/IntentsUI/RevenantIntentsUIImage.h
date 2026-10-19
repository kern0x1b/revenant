#import <Intents/Intents.h>

@interface INImage (CharonIntentsUIImage)
+ (instancetype)charon_imageWithName:(NSString *)name data:(NSData *)data width:(double)width height:(double)height;
- (NSData *)charon_imageData;
@end
