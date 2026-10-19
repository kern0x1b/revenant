#import <UIKit/UIKit.h>

@implementation UIImage (CharonItemProvider)

+ (NSArray<NSString *> *)readableTypeIdentifiersForItemProvider
{
    return @[@"com.apple.uikit.image", @"public.png", @"public.tiff", @"com.compuserve.gif", @"public.jpeg"];
}

+ (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider
{
    return @[@"com.apple.uikit.image", @"public.png", @"public.jpeg"];
}

- (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider
{
    return [[self class] writableTypeIdentifiersForItemProvider];
}

+ (instancetype)objectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)typeIdentifier error:(NSError **)outError
{
    if ([typeIdentifier isEqualToString:@"com.apple.uikit.image"]) {
        @try {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
            id image = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
            [unarchiver finishDecoding];
            if ([image isKindOfClass:[UIImage class]])
                return image;
        } @catch (NSException *exception) {
            if (outError)
                *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderReadCorruptError userInfo:@{NSLocalizedFailureReasonErrorKey: exception.reason ?: @""}];
        }
        return nil;
    }
    if ([typeIdentifier isEqualToString:@"public.png"] || [typeIdentifier isEqualToString:@"public.tiff"] || [typeIdentifier isEqualToString:@"com.compuserve.gif"] || [typeIdentifier isEqualToString:@"public.jpeg"])
        return [[self alloc] initWithData:data];
    return nil;
}

- (NSProgress *)loadDataWithTypeIdentifier:(NSString *)typeIdentifier forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    NSData *data = nil;
    if ([typeIdentifier isEqualToString:@"public.png"])
        data = UIImagePNGRepresentation(self);
    else if ([typeIdentifier isEqualToString:@"public.jpeg"])
        data = UIImageJPEGRepresentation(self, 1.0);
    else if ([typeIdentifier isEqualToString:@"com.apple.uikit.image"])
        data = [NSKeyedArchiver archivedDataWithRootObject:self];
    completionHandler(data, data ? nil : [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil]);
    return nil;
}

@end
