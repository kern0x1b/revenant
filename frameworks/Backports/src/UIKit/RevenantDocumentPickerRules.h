#import <Foundation/Foundation.h>
#if __has_include(<MobileCoreServices/MobileCoreServices.h>)
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <CoreServices/CoreServices.h>
#endif

static inline BOOL revenant_picker_accepts_path(NSString *path, NSArray<NSString *> *allowedUTIs)
{
    if (!allowedUTIs.count)
        return YES;
    NSString *extension = path.pathExtension;
    NSString *type = extension.length ? CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL)) : nil;
    for (NSString *allowed in allowedUTIs) {
        if ([allowed isEqualToString:@"public.item"] || ([allowed isEqualToString:@"public.data"] && type == nil))
            return YES;
        if (type && UTTypeConformsTo((__bridge CFStringRef)type, (__bridge CFStringRef)allowed))
            return YES;
    }
    return NO;
}

static inline NSString *revenant_picker_unique_name(NSString *name, NSUInteger n)
{
    NSString *extension = name.pathExtension;
    return [NSString stringWithFormat:@"%@ %lu%@%@", name.stringByDeletingPathExtension, (unsigned long)n, extension.length ? @"." : @"", extension];
}

static inline NSDictionary *revenant_picker_base_location(NSString *start, NSArray<NSDictionary *> *locations)
{
    NSDictionary *base = nil;
    for (NSDictionary *location in locations) {
        NSString *path = location[@"path"];
        BOOL inside = [start isEqualToString:path] || [start hasPrefix:[path hasSuffix:@"/"] ? path : [path stringByAppendingString:@"/"]];
        if (inside && [path length] > [base[@"path"] length])
            base = location;
    }
    return base;
}

static inline NSArray<NSString *> *revenant_picker_folder_chain(NSString *start, NSString *floor)
{
    NSMutableArray *chain = [NSMutableArray array];
    NSString *walk = start;
    while (walk.length > 1 && ![walk isEqualToString:floor]) {
        [chain insertObject:walk atIndex:0];
        walk = [walk stringByDeletingLastPathComponent];
    }
    if (floor)
        [chain insertObject:floor atIndex:0];
    return chain;
}
