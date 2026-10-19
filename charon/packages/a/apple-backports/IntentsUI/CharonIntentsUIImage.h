#import <Intents/Intents.h>

// What IntentsUI's two INImage files (INImage+IntentsUI100.m, INImage+IntentsUI110.m) need from INImage
// beyond the SDK: the constructor that keeps the bytes it is given, nil included, and the reader of those
// bytes. Both are defined on INImage in Intents/CharonIntents100.m, and neither is an SDK name.
@interface INImage (CharonIntentsUIImage)
+ (instancetype)charon_imageWithName:(NSString *)name data:(NSData *)data width:(double)width height:(double)height;
- (NSData *)charon_imageData;
@end
