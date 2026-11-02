#import <Foundation/Foundation.h>
#import "RevenantDocumentPickerRules.h"

static void report(const char *name, BOOL accepted)
{
    printf("%s %s\n", name, accepted ? "yes" : "no");
}

static void report_string(const char *name, NSString *value)
{
    printf("%s %s\n", name, value.UTF8String);
}

static void report_chain(const char *name, NSArray<NSString *> *chain)
{
    printf("%s %s\n", name, [[chain componentsJoinedByString:@" > "] UTF8String]);
}

int main(void)
{
    @autoreleasepool {
        report("png-for-image", revenant_picker_accepts_path(@"photo.png", @[@"public.image"]));
        report("txt-for-image", revenant_picker_accepts_path(@"notes.txt", @[@"public.image"]));
        report("mov-for-movie", revenant_picker_accepts_path(@"clip.mov", @[@"public.movie"]));
        report("png-for-item", revenant_picker_accepts_path(@"photo.png", @[@"public.item"]));
        report("png-for-data", revenant_picker_accepts_path(@"photo.png", @[@"public.data"]));
        report("zip-for-image", revenant_picker_accepts_path(@"archive.zip", @[@"public.image"]));
        report("no-extension-for-data", revenant_picker_accepts_path(@"README", @[@"public.data"]));
        report("no-extension-for-image", revenant_picker_accepts_path(@"README", @[@"public.image"]));
        report("any-for-no-types", revenant_picker_accepts_path(@"archive.zip", @[]));

        report_string("unique-pdf-2", revenant_picker_unique_name(@"report.pdf", 2));
        report_string("unique-no-extension-3", revenant_picker_unique_name(@"README", 3));
        report_string("unique-double-extension-2", revenant_picker_unique_name(@"a.tar.gz", 2));

        NSArray<NSDictionary *> *locations = @[
            @{@"title": @"Root", @"path": @"/"},
            @{@"title": @"mobile", @"path": @"/var/mobile"},
            @{@"title": @"Documents", @"path": @"/var/mobile/Documents"},
        ];
        report_string("base-nested", revenant_picker_base_location(@"/var/mobile/Documents/sub", locations)[@"title"]);
        report_string("base-equal", revenant_picker_base_location(@"/var/mobile", locations)[@"title"]);
        report_string("base-sibling-prefix", revenant_picker_base_location(@"/var/mobile2", locations)[@"title"]);
        report_string("base-none", revenant_picker_base_location(@"relative", @[])[@"title"] ?: @"none");

        report_chain("chain-under-floor", revenant_picker_folder_chain(@"/var/mobile/Documents/sub", @"/var/mobile/Documents"));
        report_chain("chain-floor-only", revenant_picker_folder_chain(@"/var/mobile/Documents", @"/var/mobile/Documents"));
        report_chain("chain-no-floor", revenant_picker_folder_chain(@"/a/b", nil));
    }
    return 0;
}
