#import <Foundation/Foundation.h>
#import "check.h"

@interface NSString (CharonHostItemProvider)
+ (NSArray *)charonHostWritableTypeIdentifiersForItemProvider;
- (NSArray *)charonHostWritableTypeIdentifiersForItemProvider;
- (NSProgress *)charonHostLoadDataWithTypeIdentifier:(NSString *)type forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))handler;
+ (NSArray *)charonHostReadableTypeIdentifiersForItemProvider;
+ (instancetype)charonHostObjectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)type error:(NSError **)error;
@end

@interface NSURL (CharonHostItemProvider)
+ (NSArray *)charonHostWritableTypeIdentifiersForItemProvider;
- (NSArray *)charonHostWritableTypeIdentifiersForItemProvider;
- (NSProgress *)charonHostLoadDataWithTypeIdentifier:(NSString *)type forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))handler;
+ (NSArray *)charonHostReadableTypeIdentifiersForItemProvider;
+ (instancetype)charonHostObjectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)type error:(NSError **)error;
@end

static NSData *written(id object, BOOL ours, NSString *type)
{
    __block NSData *result = nil;
    void (^done)(NSData *, NSError *) = ^(NSData *data, NSError *error) { result = data; };
    if (ours)
        [object charonHostLoadDataWithTypeIdentifier:type forItemProviderCompletionHandler:done];
    else
        [object loadDataWithTypeIdentifier:type forItemProviderCompletionHandler:done];
    return result;
}

int main(void)
{
    @autoreleasepool {
        charon_check([[NSString charonHostWritableTypeIdentifiersForItemProvider] isEqual:[NSString writableTypeIdentifiersForItemProvider]] && [@"x" charonHostWritableTypeIdentifiersForItemProvider].count == [@"x" writableTypeIdentifiersForItemProvider].count, "the types a string writes", @"they differ");
        charon_check([[NSString charonHostReadableTypeIdentifiersForItemProvider] isEqual:[NSString readableTypeIdentifiersForItemProvider]], "the types a string reads", ([NSString stringWithFormat:@"%@ != %@", [NSString charonHostReadableTypeIdentifiersForItemProvider], [NSString readableTypeIdentifiersForItemProvider]]));
        charon_check([written(@"héllo", YES, @"public.utf8-plain-text") isEqual:written(@"héllo", NO, @"public.utf8-plain-text")], "the data a string writes", @"it differs");
        NSData *utf8 = [@"héllo" dataUsingEncoding:NSUTF8StringEncoding], *utf16 = [@"héllo" dataUsingEncoding:NSUTF16StringEncoding];
        for (NSString *type in [NSString readableTypeIdentifiersForItemProvider]) {
            for (NSData *data in @[utf8, utf16, [NSData data]]) {
                NSError *one = nil, *two = nil;
                NSString *first = [NSString charonHostObjectWithItemProviderData:data typeIdentifier:type error:&one];
                NSString *second = [NSString objectWithItemProviderData:data typeIdentifier:type error:&two];
                charon_check((first == nil) == (second == nil) && (first == nil || [first isEqualToString:second]), [[NSString stringWithFormat:@"a string read as %@ from %lu bytes", type, (unsigned long)data.length] UTF8String], ([NSString stringWithFormat:@"%@ != %@", first, second]));
            }
        }
        NSURL *URL = [NSURL URLWithString:@"https://a.b/c?d=1"];
        charon_check([[NSURL charonHostWritableTypeIdentifiersForItemProvider] isEqual:[NSURL writableTypeIdentifiersForItemProvider]] && [[NSURL charonHostReadableTypeIdentifiersForItemProvider] isEqual:[NSURL readableTypeIdentifiersForItemProvider]], "the types a URL writes and reads", @"they differ");
        charon_check([written(URL, YES, @"public.url") isEqual:written(URL, NO, @"public.url")], "the data a URL writes", ([NSString stringWithFormat:@"%@ != %@", written(URL, YES, @"public.url"), written(URL, NO, @"public.url")]));
        NSData *urlData = [@"https://a.b/c?d=1" dataUsingEncoding:NSUTF8StringEncoding];
        charon_check([[NSURL charonHostObjectWithItemProviderData:urlData typeIdentifier:@"public.url" error:NULL] isEqual:[NSURL objectWithItemProviderData:urlData typeIdentifier:@"public.url" error:NULL]], "a URL read from its data", @"it differs");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
