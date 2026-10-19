#import <Foundation/Foundation.h>

@implementation NSURL (CharonItemProvider)

+ (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider
{
    return @[@"public.url"];
}

- (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider
{
    return [[self class] writableTypeIdentifiersForItemProvider];
}

- (NSProgress *)loadDataWithTypeIdentifier:(NSString *)typeIdentifier forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    completionHandler([self.absoluteString dataUsingEncoding:NSUTF8StringEncoding], nil);
    return nil;
}

+ (NSArray<NSString *> *)readableTypeIdentifiersForItemProvider
{
    return @[@"public.url"];
}

+ (instancetype)objectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)typeIdentifier error:(NSError **)outError
{
    NSURL *URL = [NSURL URLWithDataRepresentation:data relativeToURL:nil];
    if (!URL && outError)
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
    return URL;
}

@end
