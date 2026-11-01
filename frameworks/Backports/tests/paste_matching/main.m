#import <Foundation/Foundation.h>
#import "RevenantPasteMatching.h"

static NSItemProvider *providerConforming(NSString *typeIdentifier)
{
    NSItemProvider *provider = [[NSItemProvider alloc] init];
    [provider registerDataRepresentationForTypeIdentifier:typeIdentifier visibility:NSItemProviderRepresentationVisibilityAll loadHandler:^NSProgress *(void (^completion)(NSData *, NSError *)) {
        completion([NSData data], nil);
        return nil;
    }];
    return provider;
}

static void report(const char *name, BOOL accepted)
{
    printf("%s %s\n", name, accepted ? "yes" : "no");
}

int main(void)
{
    @autoreleasepool {
        NSArray<NSString *> *image = @[@"public.image"];
        report("png-for-image", revenant_paste_accepts(@[providerConforming(@"public.png")], image));
        report("jpeg-for-image", revenant_paste_accepts(@[providerConforming(@"public.jpeg")], image));
        report("text-for-image", revenant_paste_accepts(@[providerConforming(@"public.utf8-plain-text")], image));
        report("data-for-image", revenant_paste_accepts(@[providerConforming(@"public.data")], image));
        report("text-for-text", revenant_paste_accepts(@[providerConforming(@"public.utf8-plain-text")], @[@"public.text"]));
        report("html-for-text", revenant_paste_accepts(@[providerConforming(@"public.html")], @[@"public.text"]));
        report("url-for-url", revenant_paste_accepts(@[providerConforming(@"public.url")], @[@"public.url"]));
        report("file-url-for-url", revenant_paste_accepts(@[providerConforming(@"public.file-url")], @[@"public.url"]));
        report("data-then-png-for-image", revenant_paste_accepts(@[providerConforming(@"public.data"), providerConforming(@"public.png")], image));
        report("no-providers", revenant_paste_accepts(@[], image));
        report("no-types", revenant_paste_accepts(@[providerConforming(@"public.png")], @[]));
    }
    return 0;
}
