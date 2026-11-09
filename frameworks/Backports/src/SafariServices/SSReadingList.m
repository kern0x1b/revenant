#include "../revenant_impl.h"
#import <SafariServices/SafariServices.h>
#import <dlfcn.h>
#import <objc/message.h>
#include <unistd.h>

NSString *const BACKPORT_IMPL(SSReadingListErrorDomain) = @"SSReadingListErrorDomain";

static Class revenant_web_reading_list_class(void)
{
    static Class list;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (dlopen("/System/Library/PrivateFrameworks/WebBookmarks.framework/WebBookmarks", RTLD_LAZY))
            list = NSClassFromString(@"WebReadingList");
    });
    return list;
}

static BOOL revenant_reading_list_writable(void)
{
    Class collection = NSClassFromString(@"WebBookmarkCollection");
    SEL directory = NSSelectorFromString(@"safariDirectoryPath");
    if (![collection respondsToSelector:directory])
        return NO;
    NSString *folder = ((id (*)(Class, SEL))objc_msgSend)(collection, directory);
    return folder != nil && access([[folder stringByAppendingPathComponent:@"Bookmarks.db"] fileSystemRepresentation], R_OK | W_OK) == 0;
}

static BOOL revenant_reading_list_supported(void)
{
    Class list = revenant_web_reading_list_class();
    SEL supported = NSSelectorFromString(@"_isSupported");
    return [list respondsToSelector:supported] && ((BOOL (*)(Class, SEL))objc_msgSend)(list, supported) && revenant_reading_list_writable();
}

@interface SSReadingList ()
- (instancetype)revenant_init;
@end

@implementation SSReadingList {
    id _list;
}

+ (SSReadingList *)defaultReadingList
{
    static SSReadingList *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[SSReadingList alloc] revenant_init];
    });
    return revenant_reading_list_supported() ? shared : nil;
}

- (instancetype)init
{
    [NSException raise:NSGenericException format:@"Misuse of SSReadingList interface."];
    return nil;
}

- (instancetype)revenant_init
{
    return [super init];
}

+ (BOOL)supportsURL:(NSURL *)URL
{
    NSString *scheme = URL.scheme;
    if (!scheme || ([scheme caseInsensitiveCompare:@"http"] != NSOrderedSame && [scheme caseInsensitiveCompare:@"https"] != NSOrderedSame))
        return NO;
    Class list = revenant_web_reading_list_class();
    SEL supported = NSSelectorFromString(@"_isSupportedReadingListURL:");
    return ![list respondsToSelector:supported] || ((BOOL (*)(Class, SEL, id))objc_msgSend)(list, supported, URL);
}

- (BOOL)addReadingListItemWithURL:(NSURL *)URL title:(NSString *)title previewText:(NSString *)previewText error:(NSError **)error
{
    if (![SSReadingList supportsURL:URL]) {
        if (error)
            *error = [NSError errorWithDomain:SSReadingListErrorDomain code:SSReadingListErrorURLSchemeNotAllowed userInfo:nil];
        return NO;
    }
    NSURL *address = [URL copy];
    NSString *name = [title copy];
    NSString *preview = [previewText copy];
    void (^add)(void) = ^{
        if (!_list)
            _list = [[revenant_web_reading_list_class() alloc] init];
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(_list, NSSelectorFromString(@"addReadingListItemWithURL:title:previewText:"), address, name, preview);
    };
    if ([NSThread isMainThread])
        add();
    else
        dispatch_async(dispatch_get_main_queue(), add);
    return YES;
}

@end
