// assets-extract: writes the images, colours and data of a compiled asset catalogue (Assets.car) as loose files, for an
// application that runs on a release whose UIKit has no asset catalogue reader.
//
//     assets-extract [--scales 1,2,3] [--keep-appearance] CATALOGUE OUTPUT-FOLDER
//
// Every image a catalogue names comes out as name.png (1x), name@2x.png, name@3x.png and, where the catalogue has a variant
// of its own for the iPad, name~ipad.png, name@2x~ipad.png; the stock +[UIImage imageNamed:] of iOS 6 finds those by itself.
// The rest goes to AssetCatalogImages.plist (sizes, cap insets, template mode), AssetCatalogColors.plist and data/NAME.
//
// The catalogue is read by the CoreUI of the machine that runs the tool, which decodes every format Xcode writes.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <dlfcn.h>

typedef struct { double top, left, bottom, right; } Insets;

@interface CUICatalog : NSObject
- (instancetype)initWithURL:(NSURL *)URL error:(NSError **)error;
- (NSArray *)allImageNames;
- (NSArray *)imagesWithName:(NSString *)name;
- (void)enumerateNamedLookupsUsingBlock:(void (^)(id lookup))block;
@end

@interface CUINamedLookup : NSObject
- (NSString *)name;
- (NSInteger)idiom;
- (NSInteger)subtype;
- (NSInteger)sizeClassHorizontal;
- (NSInteger)sizeClassVertical;
- (NSInteger)layoutDirection;
- (NSInteger)displayGamut;
- (NSInteger)localization;
- (NSString *)appearance;
@end

@interface CUINamedImage : CUINamedLookup
- (CGImageRef)image;
- (CGImageRef)createImageFromPDFRenditionWithScale:(double)scale;
- (BOOL)isVectorBased;
- (BOOL)hasSliceInformation;
- (BOOL)isTemplate;
- (NSInteger)templateRenderingMode;
- (NSInteger)resizingMode;
- (double)scale;
- (Insets)edgeInsets;
@end

@interface CUINamedColor : CUINamedLookup
- (CGColorRef)cgColor;
@end

@interface CUINamedData : CUINamedLookup
- (NSData *)data;
@end

static NSString *idiom_suffix(NSInteger idiom)
{
    return idiom == 2 ? @"~ipad" : @"";
}

static NSString *idiom_name(NSInteger idiom)
{
    switch (idiom) {
    case 0: return @"universal";
    case 1: return @"phone";
    case 2: return @"pad";
    case 3: return @"tv";
    case 4: return @"car";
    case 5: return @"watch";
    default: return [NSString stringWithFormat:@"idiom%ld", (long)idiom];
    }
}

static NSString *scale_suffix(NSInteger scale)
{
    return scale > 1 ? [NSString stringWithFormat:@"@%ldx", (long)scale] : @"";
}

static CGImageRef srgb_copy(CGImageRef image)
{
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context)
        return NULL;
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGImageRef copy = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return copy;
}

static BOOL write_png(CGImageRef image, NSString *path)
{
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
    CGImageRef converted = srgb_copy(image);
    CGImageDestinationRef destination = converted ? CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], (__bridge CFStringRef)UTTypePNG.identifier, 1, NULL) : NULL;
    BOOL wrote = NO;
    if (destination) {
        CGImageDestinationAddImage(destination, converted, NULL);
        wrote = CGImageDestinationFinalize(destination);
        CFRelease(destination);
    }
    if (converted)
        CGImageRelease(converted);
    return wrote;
}

static CGImageRef draw_pdf(NSData *data, double scale)
{
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGPDFDocumentRef document = provider ? CGPDFDocumentCreateWithProvider(provider) : NULL;
    CGPDFPageRef page = document ? CGPDFDocumentGetPage(document, 1) : NULL;
    CGImageRef image = NULL;
    if (page) {
        CGRect box = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
        int rotation = CGPDFPageGetRotationAngle(page);
        CGSize size = rotation % 180 ? CGSizeMake(box.size.height, box.size.width) : box.size;
        size_t width = (size_t)ceil(size.width * scale), height = (size_t)ceil(size.height * scale);
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef context = width && height ? CGBitmapContextCreate(NULL, width, height, 8, 0, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big) : NULL;
        CGColorSpaceRelease(space);
        if (context) {
            CGContextConcatCTM(context, CGPDFPageGetDrawingTransform(page, kCGPDFMediaBox, CGRectMake(0, 0, width, height), 0, true));
            CGContextDrawPDFPage(context, page);
            image = CGBitmapContextCreateImage(context);
            CGContextRelease(context);
        }
    }
    if (document)
        CGPDFDocumentRelease(document);
    if (provider)
        CGDataProviderRelease(provider);
    return image;
}

static NSString *digest(CGImageRef image)
{
    CGImageRef converted = srgb_copy(image);
    if (!converted)
        return @"";
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(converted));
    NSUInteger hash = 5381;
    const uint8_t *bytes = CFDataGetBytePtr(data);
    for (CFIndex index = 0; index < CFDataGetLength(data); index++)
        hash = hash * 33 + bytes[index];
    NSString *text = [NSString stringWithFormat:@"%zux%zu-%lx", CGImageGetWidth(converted), CGImageGetHeight(converted), (unsigned long)hash];
    CFRelease(data);
    CGImageRelease(converted);
    return text;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSMutableArray *arguments = [NSMutableArray array];
        NSSet *scales = [NSSet setWithArray:@[@1, @2, @3]];
        BOOL keepAppearance = NO;
        for (int index = 1; index < argc; index++) {
            NSString *argument = @(argv[index]);
            if ([argument isEqualToString:@"--scales"] && index + 1 < argc) {
                NSMutableSet *chosen = [NSMutableSet set];
                for (NSString *part in [@(argv[++index]) componentsSeparatedByString:@","])
                    [chosen addObject:@(part.integerValue)];
                scales = chosen;
            } else if ([argument isEqualToString:@"--keep-appearance"])
                keepAppearance = YES;
            else
                [arguments addObject:argument];
        }
        if (arguments.count != 2) {
            fprintf(stderr, "usage: assets-extract [--scales 1,2,3] CATALOGUE OUTPUT-FOLDER\n");
            return 64;
        }
        if (!dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_NOW)) {
            fprintf(stderr, "assets-extract: this machine has no CoreUI\n");
            return 69;
        }
        NSError *error = nil;
        CUICatalog *catalogue = [[NSClassFromString(@"CUICatalog") alloc] initWithURL:[NSURL fileURLWithPath:arguments[0]] error:&error];
        if (!catalogue) {
            fprintf(stderr, "assets-extract: %s is not a compiled asset catalogue: %s\n", [arguments[0] UTF8String], [[error localizedDescription] UTF8String]);
            return 65;
        }
        NSString *output = arguments[1];
        NSMutableSet *icon_sets = [NSMutableSet set];
        [catalogue enumerateNamedLookupsUsingBlock:^(CUINamedLookup *lookup) {
            if ([NSStringFromClass([lookup class]) isEqualToString:@"CUINamedMultisizeImageSet"])
                [icon_sets addObject:[lookup name]];
        }];
        NSMutableDictionary *icons = [NSMutableDictionary dictionary];
        NSMutableDictionary *index = [NSMutableDictionary dictionary];
        NSUInteger written = 0, skipped = 0, failed = 0;
        for (NSString *name in [[catalogue allImageNames] sortedArrayUsingSelector:@selector(compare:)]) {
            if ([name hasPrefix:@"ZZZZPackedAsset"])
                continue;
            NSMutableDictionary *seen = [NSMutableDictionary dictionary];
            NSMutableArray *variants = [NSMutableArray array];
            NSArray *renditions = [[catalogue imagesWithName:name] sortedArrayUsingComparator:^NSComparisonResult(CUINamedLookup *a, CUINamedLookup *b) {
                NSInteger left = [a idiom], right = [b idiom];
                return left == right ? NSOrderedSame : (left == 1 ? NSOrderedAscending : (right == 1 ? NSOrderedDescending : (left < right ? NSOrderedAscending : NSOrderedDescending)));
            }];
            for (CUINamedImage *rendition in renditions) {
                if (![rendition isKindOfClass:NSClassFromString(@"CUINamedImage")])
                    continue;
                BOOL general = [rendition displayGamut] == 0 && [rendition sizeClassHorizontal] == 0 && [rendition sizeClassVertical] == 0 && [rendition subtype] == 0 &&
                               [rendition layoutDirection] == 0 && [rendition localization] == 0 && (keepAppearance || [[rendition appearance] isEqualToString:@"UIAppearanceAny"]);
                if (!general) {
                    skipped++;
                    continue;
                }
                NSInteger idiom = [rendition idiom];
                if (idiom > 2) {
                    skipped++;
                    continue;
                }
                NSMutableArray *scaled = [NSMutableArray array];
                NSInteger scale = (NSInteger)llround([rendition scale]);
                CGImageRef image = [rendition image];
                if (image && [scales containsObject:@(scale)])
                    [scaled addObject:@[@(scale), (__bridge id)image]];
                else if (!image && [rendition isVectorBased]) {
                    for (NSNumber *wanted in scales) {
                        CGImageRef drawn = [rendition createImageFromPDFRenditionWithScale:wanted.doubleValue];
                        if (drawn)
                            [scaled addObject:@[wanted, (__bridge_transfer id)drawn]];
                    }
                }
                for (NSArray *pair in scaled) {
                    NSInteger scale = [pair[0] integerValue];
                    CGImageRef image = (__bridge CGImageRef)pair[1];
                    if ([icon_sets containsObject:name]) {
                        NSString *icon = [NSString stringWithFormat:@"icons/%@-%zux%zu%@.png", name, CGImageGetWidth(image), CGImageGetHeight(image), idiom_suffix(idiom)];
                        NSString *icon_hash = [NSString stringWithFormat:@"%@%ld", icon, (long)idiom];
                        if (seen[icon_hash] || !write_png(image, [output stringByAppendingPathComponent:icon])) {
                            skipped++;
                            continue;
                        }
                        seen[icon_hash] = icon;
                        written++;
                        NSMutableArray *list = icons[name] ?: [NSMutableArray array];
                        [list addObject:@{@"file": icon, @"width": @(CGImageGetWidth(image)), @"height": @(CGImageGetHeight(image)), @"idiom": idiom_name(idiom)}];
                        icons[name] = list;
                        continue;
                    }
                    NSString *key = [NSString stringWithFormat:@"%ld", (long)scale];
                    NSString *pad = idiom == 2 ? [key stringByAppendingString:@"~pad"] : key;
                    NSString *hash = digest(image);
                    if (idiom == 2 && [seen[key] isEqualToString:hash]) {
                        skipped++;
                        continue;
                    }
                    if (seen[pad] && idiom != 2) {
                        skipped++;
                        continue;
                    }
                    seen[pad] = hash;
                    NSString *file = [NSString stringWithFormat:@"%@%@%@.png", name, scale_suffix(scale), idiom_suffix(idiom)];
                    if (!write_png(image, [output stringByAppendingPathComponent:file])) {
                        failed++;
                        continue;
                    }
                    written++;
                    Insets insets = [rendition hasSliceInformation] ? [rendition edgeInsets] : (Insets){0, 0, 0, 0};
                    [variants addObject:@{@"file": file, @"scale": @(scale), @"idiom": idiom_name(idiom), @"width": @(CGImageGetWidth(image)), @"height": @(CGImageGetHeight(image)),
                                          @"capInsets": @[@(insets.top), @(insets.left), @(insets.bottom), @(insets.right)], @"resizingMode": @([rendition hasSliceInformation] ? [rendition resizingMode] : -1),
                                          @"template": @([rendition templateRenderingMode] == 2 || [rendition isTemplate]), @"vector": @([rendition isVectorBased])}];
                }
            }
            if (variants.count)
                index[name] = variants;
        }
                NSMutableDictionary *colors = [NSMutableDictionary dictionary];
        NSString *data_folder = [output stringByAppendingPathComponent:@"data"];
        __block NSUInteger extracted = 0, rendered = 0;
        [catalogue enumerateNamedLookupsUsingBlock:^(CUINamedLookup *lookup) {
            NSString *class_name = NSStringFromClass([lookup class]);
            NSString *name = [lookup name];
            if ([class_name isEqualToString:@"CUINamedColor"]) {
                CGColorRef color = [(CUINamedColor *)lookup cgColor];
                CGColorRef converted = color ? CGColorCreateCopyByMatchingToColorSpace(CGColorSpaceCreateWithName(kCGColorSpaceSRGB), kCGRenderingIntentDefault, color, NULL) : NULL;
                if (converted) {
                    const CGFloat *components = CGColorGetComponents(converted);
                    NSString *appearance = [[lookup appearance] isEqualToString:@"UIAppearanceAny"] ? @"any" : [[[lookup appearance] stringByReplacingOccurrencesOfString:@"UIAppearance" withString:@""] lowercaseString];
                    NSMutableDictionary *entry = colors[name] ?: [NSMutableDictionary dictionary];
                    entry[appearance] = @[@(components[0]), @(components[1]), @(components[2]), @(CGColorGetAlpha(converted))];
                    colors[name] = entry;
                    CGColorRelease(converted);
                }
            } else if ([class_name isEqualToString:@"CUINamedData"] && [lookup idiom] <= 2 && !index[name]) {
                NSData *data = [(CUINamedData *)lookup data];
                if (data.length > 4 && !memcmp(data.bytes, "%PDF", 4)) {
                    NSMutableArray *variants = [NSMutableArray array];
                    for (NSNumber *scale in [[scales allObjects] sortedArrayUsingSelector:@selector(compare:)]) {
                        CGImageRef image = draw_pdf(data, scale.doubleValue);
                        NSString *file = [NSString stringWithFormat:@"%@%@.png", name, scale_suffix(scale.integerValue)];
                        if (image && write_png(image, [output stringByAppendingPathComponent:file])) {
                            [variants addObject:@{@"file": file, @"scale": scale, @"idiom": @"universal", @"width": @(CGImageGetWidth(image)), @"height": @(CGImageGetHeight(image)),
                                                  @"capInsets": @[@0, @0, @0, @0], @"resizingMode": @-1, @"template": @NO, @"vector": @YES}];
                            rendered++;
                        }
                        if (image)
                            CGImageRelease(image);
                    }
                    if (variants.count)
                        index[name] = variants;
                } else if (data) {
                    [[NSFileManager defaultManager] createDirectoryAtPath:[[data_folder stringByAppendingPathComponent:name] stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
                    if ([data writeToFile:[data_folder stringByAppendingPathComponent:name] atomically:YES])
                        extracted++;
                }
            }
        }];
        [index writeToFile:[output stringByAppendingPathComponent:@"AssetCatalogImages.plist"] atomically:YES];
        [colors writeToFile:[output stringByAppendingPathComponent:@"AssetCatalogColors.plist"] atomically:YES];
        [icons writeToFile:[output stringByAppendingPathComponent:@"AssetCatalogIcons.plist"] atomically:YES];
        printf("%lu images of %lu names written (%lu drawn from PDF documents), %lu variants left out, %lu failed; %lu colours, %lu data sets\n", (unsigned long)(written + rendered), (unsigned long)index.count,
               (unsigned long)rendered, (unsigned long)skipped, (unsigned long)failed, (unsigned long)colors.count, (unsigned long)extracted);
        return failed ? 1 : 0;
    }
}
