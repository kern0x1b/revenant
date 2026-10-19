// probe.m - what UTTypeCopyAllTagsWithClass answers on the host, beside the type's declaration. The function is
// deprecated in CoreServices/UTType.h (ios 8.0 to 15.0), and the release's iOS 6 has no such symbol; the port
// reads the same tags from the declaration (UTTypeCopyDeclaration), so the host's answers are the oracle.
//
// Each line starts with TAGS so a run can be filtered to it.
#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

static NSString *describe(id value)
{
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (id item in value) {
            [parts addObject:[item description]];
        }
        return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@", "]];
    }
    return [value description];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSArray *utis = @[@"public.jpeg", @"public.png", @"public.plain-text", @"public.mpeg-4", @"com.adobe.pdf",
                          @"public.data", @"public.folder", @"public.item", @"public.url", @"public.image",
                          @"public.movie", @"public.html", @"public.json", @"public.zip-archive", @"public.mp3",
                          @"public.swift-source", @"public.text", @"public.tiff", @"dyn.ah62d4rv4ge80c6dp",
                          @"com.example.nonexistent"];
        NSArray *classes = @[@"public.filename-extension", @"public.mime-type", @"com.apple.ostype",
                             @"com.apple.nspboard-type", @"public.pathname"];
        for (NSString *uti in utis) {
            NSDictionary *declaration = (__bridge_transfer NSDictionary *)UTTypeCopyDeclaration((__bridge CFStringRef)uti);
            printf("TAGS declaration %s = %s\n", [uti UTF8String],
                   declaration != nil ? [[describe(declaration[@"UTTypeTagSpecification"]) description] UTF8String] : "(none)");
            for (NSString *tagClass in classes) {
                CFArrayRef tags = UTTypeCopyAllTagsWithClass((__bridge CFStringRef)uti, (__bridge CFStringRef)tagClass);
                NSArray *answer = (__bridge_transfer NSArray *)tags;
                printf("TAGS %s %s = %s\n", [uti UTF8String], [tagClass UTF8String],
                       answer != nil ? [describe(answer) UTF8String] : "NULL");
            }
        }
        printf("TAGS done\n");
    }
    return 0;
}
