#import <Foundation/Foundation.h>

@implementation NSString (CharonItemProvider)

+ (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider
{
    return @[@"public.utf8-plain-text"];
}

- (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider
{
    return [[self class] writableTypeIdentifiersForItemProvider];
}

- (NSProgress *)loadDataWithTypeIdentifier:(NSString *)typeIdentifier forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    completionHandler([self dataUsingEncoding:NSUTF8StringEncoding], nil);
    return nil;
}

+ (NSArray<NSString *> *)readableTypeIdentifiersForItemProvider
{
    return @[@"public.utf8-plain-text", @"public.utf16-external-plain-text", @"public.utf16-plain-text", @"public.plain-text", @"public.url"];
}

+ (instancetype)objectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)typeIdentifier error:(NSError **)outError
{
    NSStringEncoding encoding = NSUTF8StringEncoding;
    if ([typeIdentifier isEqualToString:@"public.utf16-external-plain-text"])
        encoding = NSUTF16StringEncoding;
    else if ([typeIdentifier isEqualToString:@"public.utf16-plain-text"]) {
        const uint8_t *bytes = data.bytes;
        BOOL marked = data.length >= 2 && ((bytes[0] == 0xFF && bytes[1] == 0xFE) || (bytes[0] == 0xFE && bytes[1] == 0xFF));
        encoding = marked ? NSUTF16StringEncoding : NSUTF16LittleEndianStringEncoding;
    }
    NSString *string = [typeIdentifier isEqualToString:@"public.url"] ? [[NSURL URLWithDataRepresentation:data relativeToURL:nil] absoluteString] : [[NSString alloc] initWithData:data encoding:encoding];
    if (!string && outError)
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadInapplicableStringEncodingError userInfo:nil];
    return string;
}

@end
