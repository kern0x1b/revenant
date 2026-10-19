#import "documentmenu-cases.h"

static NSString *raised(id (^block)(void))
{
    @try {
        block();
    } @catch (NSException *e) {
        return [NSString stringWithFormat:@"%@: %@", e.name, e.reason];
    }
    return @"none";
}

void documentmenu_run(UIWindow *window, DocumentMenuRecorder record)
{
    UIDocumentMenuViewController *menu = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    record(@"style", [NSString stringWithFormat:@"%ld", (long)menu.modalPresentationStyle]);
    record(@"delegate", [NSString stringWithFormat:@"%d", menu.delegate == nil]);
    record(@"is a controller", [NSString stringWithFormat:@"%d", [menu isKindOfClass:[UIViewController class]]]);
    record(@"popover controller", [NSString stringWithFormat:@"%d", menu.popoverPresentationController != nil]);
    record(@"popover controller is stable", [NSString stringWithFormat:@"%d", menu.popoverPresentationController == menu.popoverPresentationController]);
    record(@"open mode", raised(^id{ return [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeOpen]; }));
    record(@"export mode for types", raised(^id{ return [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeExportToService]; }));
    record(@"move mode for types", raised(^id{ return [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeMoveToService]; }));
    NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-menu.txt"];
    [@"menu" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSURL *url = [NSURL fileURLWithPath:file];
    record(@"export by a url that is not there", raised(^id{ return [[UIDocumentMenuViewController alloc] initWithURL:[NSURL fileURLWithPath:@"/tmp/charon-menu-missing"] inMode:UIDocumentPickerModeExportToService]; }));
    record(@"export by url", raised(^id{ return [[UIDocumentMenuViewController alloc] initWithURL:url inMode:UIDocumentPickerModeExportToService]; }));
    record(@"move by url", raised(^id{ return [[UIDocumentMenuViewController alloc] initWithURL:url inMode:UIDocumentPickerModeMoveToService]; }));
    record(@"import by url", raised(^id{ return [[UIDocumentMenuViewController alloc] initWithURL:url inMode:UIDocumentPickerModeImport]; }));
    record(@"plain init", raised(^id{ return [[UIDocumentMenuViewController alloc] init]; }));
    record(@"option", raised(^id{ [menu addOptionWithTitle:@"Option" image:nil order:UIDocumentMenuOrderFirst handler:^{}]; return nil; }));
    record(@"orders", [NSString stringWithFormat:@"%ld %ld", (long)UIDocumentMenuOrderFirst, (long)UIDocumentMenuOrderLast]);
}
