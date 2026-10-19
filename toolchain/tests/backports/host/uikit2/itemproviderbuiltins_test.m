#import <Foundation/Foundation.h>
#import "check.h"

@interface NSString (RevenantHostItemProvider)
+ (NSArray *)revenantHostWritableTypeIdentifiersForItemProvider;
- (NSArray *)revenantHostWritableTypeIdentifiersForItemProvider;
- (NSProgress *)revenantHostLoadDataWithTypeIdentifier:(NSString *)type forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))handler;
+ (NSArray *)revenantHostReadableTypeIdentifiersForItemProvider;
+ (instancetype)revenantHostObjectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)type error:(NSError **)error;
@end

@interface NSURL (RevenantHostItemProvider)
+ (NSArray *)revenantHostWritableTypeIdentifiersForItemProvider;
- (NSArray *)revenantHostWritableTypeIdentifiersForItemProvider;
- (NSProgress *)revenantHostLoadDataWithTypeIdentifier:(NSString *)type forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))handler;
+ (NSArray *)revenantHostReadableTypeIdentifiersForItemProvider;
+ (instancetype)revenantHostObjectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)type error:(NSError **)error;
@end

static NSData *written(id object, BOOL ours, NSString *type)
{
    __block NSData *result = nil;
    void (^done)(NSData *, NSError *) = ^(NSData *data, NSError *error) { result = data; };
    if (ours)
        [object revenantHostLoadDataWithTypeIdentifier:type forItemProviderCompletionHandler:done];
    else
        [object loadDataWithTypeIdentifier:type forItemProviderCompletionHandler:done];
    return result;
}

int main(void)
{
    @autoreleasepool {
        revenant_check([[NSString revenantHostWritableTypeIdentifiersForItemProvider] isEqual:[NSString writableTypeIdentifiersForItemProvider]] && [@"x" revenantHostWritableTypeIdentifiersForItemProvider].count == [@"x" writableTypeIdentifiersForItemProvider].count, "the types a string writes", @"they differ");
        revenant_check([[NSString revenantHostReadableTypeIdentifiersForItemProvider] isEqual:[NSString readableTypeIdentifiersForItemProvider]], "the types a string reads", ([NSString stringWithFormat:@"%@ != %@", [NSString revenantHostReadableTypeIdentifiersForItemProvider], [NSString readableTypeIdentifiersForItemProvider]]));
        revenant_check([written(@"héllo", YES, @"public.utf8-plain-text") isEqual:written(@"héllo", NO, @"public.utf8-plain-text")], "the data a string writes", @"it differs");
        NSData *utf8 = [@"héllo" dataUsingEncoding:NSUTF8StringEncoding], *utf16 = [@"héllo" dataUsingEncoding:NSUTF16StringEncoding];
        for (NSString *type in [NSString readableTypeIdentifiersForItemProvider]) {
            for (NSData *data in @[utf8, utf16, [NSData data]]) {
                NSError *one = nil, *two = nil;
                NSString *first = [NSString revenantHostObjectWithItemProviderData:data typeIdentifier:type error:&one];
                NSString *second = [NSString objectWithItemProviderData:data typeIdentifier:type error:&two];
                revenant_check((first == nil) == (second == nil) && (first == nil || [first isEqualToString:second]), [[NSString stringWithFormat:@"a string read as %@ from %lu bytes", type, (unsigned long)data.length] UTF8String], ([NSString stringWithFormat:@"%@ != %@", first, second]));
            }
        }
        NSURL *URL = [NSURL URLWithString:@"https://a.b/c?d=1"];
        revenant_check([[NSURL revenantHostWritableTypeIdentifiersForItemProvider] isEqual:[NSURL writableTypeIdentifiersForItemProvider]] && [[NSURL revenantHostReadableTypeIdentifiersForItemProvider] isEqual:[NSURL readableTypeIdentifiersForItemProvider]], "the types a URL writes and reads", @"they differ");
        revenant_check([written(URL, YES, @"public.url") isEqual:written(URL, NO, @"public.url")], "the data a URL writes", ([NSString stringWithFormat:@"%@ != %@", written(URL, YES, @"public.url"), written(URL, NO, @"public.url")]));
        NSData *urlData = [@"https://a.b/c?d=1" dataUsingEncoding:NSUTF8StringEncoding];
        revenant_check([[NSURL revenantHostObjectWithItemProviderData:urlData typeIdentifier:@"public.url" error:NULL] isEqual:[NSURL objectWithItemProviderData:urlData typeIdentifier:@"public.url" error:NULL]], "a URL read from its data", @"it differs");
    }
    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures;
}
