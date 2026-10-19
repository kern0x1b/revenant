#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const PREFIX = @"revenantHost_";
#define WINDOW_W 32
#define WINDOW_H 32

typedef id (*RevenantMsgSend0)(id, SEL);

static NSString *unprefixed(const char *keyword)
{
    if (strncmp(keyword, "revenantHost_", 13) == 0) return [NSString stringWithUTF8String:keyword + 13];
    for (NSString *family in @[@"mutableCopy", @"copy", @"init", @"new", @"alloc"]) {
        if (!strncmp(keyword, family.UTF8String, family.length)) {
            const char *rest = keyword + family.length;
            if (strncmp(rest, "RevenantHost", 12) == 0 && rest[12] >= 'A' && rest[12] <= 'Z')
                return [NSString stringWithFormat:@"%@%s", family, rest + 12];
        }
    }
    return nil;
}

static NSString *prefixed(NSString *keyword)
{
    for (NSString *family in @[@"mutableCopy", @"copy", @"init", @"new", @"alloc"]) {
        if ([keyword hasPrefix:family]) {
            NSString *rest = [keyword substringFromIndex:family.length];
            if (!rest.length || (rest.length && [rest characterAtIndex:0] >= 'A' && [rest characterAtIndex:0] <= 'Z'))
                return [NSString stringWithFormat:@"%@RevenantHost%@", family, rest];
        }
    }
    return [PREFIX stringByAppendingString:keyword];
}

static CIContext *context;
static long compared, rendered, different, missing;

static NSData *bytes_of(CIImage *image)
{
    if (!image) return nil;
    size_t width = WINDOW_W, height = WINDOW_H;
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    [context render:image toBitmap:data.mutableBytes rowBytes:width * 4 bounds:CGRectMake(0, 0, width, height)
             format:kCIFormatRGBA8 colorSpace:space];
    CGColorSpaceRelease(space);
    return data;
}

static void tell(NSString *what)
{
    if (different++ < 40) printf("different: %s\n", what.UTF8String);
}

static CIVector *rect_vector(void);
static CIQRCodeDescriptor *any_qr_descriptor(void);

static NSArray *supplied_values(NSDictionary *attribute, NSString *key, CIImage *input, CIImage *cube)
{
    if (![attribute isKindOfClass:[NSDictionary class]]) return nil;
    NSString *type = attribute[@"CIAttributeType"];
    NSString *klass = attribute[@"CIAttributeClass"];
    if ([type isEqualToString:@"CIAttributeTypeImage"] || [klass isEqualToString:@"CIImage"]) {
        if ([key rangeOfString:@"Cube" options:NSCaseInsensitiveSearch].location != NSNotFound) return @[cube];
        return @[input];
    }
    if ([klass isEqualToString:@"NSAttributedString"]) return @[[[NSAttributedString alloc] initWithString:@"revenant"]];
    if ([klass isEqualToString:@"NSString"]) return @[@"revenant"];
    if ([klass isEqualToString:@"NSData"]) return @[[@"revenant" dataUsingEncoding:NSUTF8StringEncoding]];
    if ([klass isEqualToString:@"NSNumber"] || [type isEqualToString:@"CIAttributeTypeScalar"] ||
        [type isEqualToString:@"CIAttributeTypeFloat"] || [type isEqualToString:@"CIAttributeTypeInteger"]) {
        NSMutableArray *numbers = [NSMutableArray array];
        NSNumber *low = attribute[@"CIAttributeMin"] ?: attribute[@"CIAttributeSliderMin"];
        NSNumber *high = attribute[@"CIAttributeMax"] ?: attribute[@"CIAttributeSliderMax"];
        if (high) [numbers addObject:high];
        if (low) [numbers addObject:low];
        if (low && high) [numbers addObject:@(([low doubleValue] + [high doubleValue]) / 2.0)];
        [numbers addObject:@1];
        return numbers;
    }
    if ([type isEqualToString:@"CIAttributeTypeRectangle"]) return @[rect_vector()];
    if ([klass isEqualToString:@"CIBarcodeDescriptor"]) {
        CIQRCodeDescriptor *descriptor = any_qr_descriptor();
        return descriptor ? @[descriptor] : nil;
    }
    return nil;
}

static CIVector *rect_vector(void)
{
    CGRect extent = CGRectMake(0, 0, WINDOW_W, WINDOW_H);
    return [CIVector vectorWithX:extent.origin.x Y:extent.origin.y Z:extent.size.width W:extent.size.height];
}

static CIQRCodeDescriptor *any_qr_descriptor(void)
{
    static CIQRCodeDescriptor *descriptor;
    if (descriptor) return descriptor;
    NSData *payload = [@"revenant" dataUsingEncoding:NSUTF8StringEncoding];
    for (NSInteger version = 1; version <= 40 && !descriptor; version++)
        for (NSUInteger mask = 0; mask <= 7 && !descriptor; mask++)
            for (NSUInteger level = 0; level <= 3 && !descriptor; level++)
                descriptor = [CIQRCodeDescriptor descriptorWithPayload:payload symbolVersion:version
                                                           maskPattern:mask errorCorrectionLevel:level];
    return descriptor;
}

static void same_dictionary(NSDictionary *a, NSDictionary *b, NSString *what)
{
    compared++;
    if (a.count != b.count) {
        tell([NSString stringWithFormat:@"%@ count %lu vs %lu", what, (unsigned long)a.count, (unsigned long)b.count]);
        return;
    }
    for (id key in a) {
        id x = a[key], y = b[key];
        BOOL equal;
        if ([x isKindOfClass:[NSArray class]] && [y isKindOfClass:[NSArray class]]) {
            equal = [(NSArray *)x isEqualToArray:y];
        } else if ([x isKindOfClass:[NSData class]] && [y isKindOfClass:[NSData class]]) {
            equal = [(NSData *)x isEqualToData:y];
        } else {
            equal = [x isEqual:y];
        }
        if (!equal) {
            tell([NSString stringWithFormat:@"%@[%@] %@ vs %@", what, [key description],
                  [x description], [y description]]);
            return;
        }
    }
}

int main(void)
{
    context = [CIContext contextWithOptions:nil];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CIColor *colour = [[CIColor alloc] initWithRed:0.25 green:0.5 blue:0.75 alpha:1];
    CIImage *input = [[CIImage imageWithColor:colour] imageByCroppingToRect:CGRectMake(0, 0, 16, 12)];
    CGColorSpaceRelease(space);

    CIImage *cube = [CIFilter filterWithName:@"CIColorCube"].outputImage;

    Class metaclass = object_getClass([CIFilter class]);
    unsigned count = 0;
    Method *methods = class_copyMethodList(metaclass, &count);
    NSMutableArray *ported = [NSMutableArray array];
    for (unsigned i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        const char *types = method_getTypeEncoding(methods[i]);
        const char *keyword = sel_getName(sel);
        if (!types || types[0] != '@') continue;
        if (strchr(keyword, ':')) continue;
        NSString *own = unprefixed(keyword);
        if (!own) continue;
        [ported addObject:own];
    }
    free(methods);

    for (NSString *selector in ported) {
        SEL host = NSSelectorFromString(selector);
        SEL own = NSSelectorFromString(prefixed(selector));
        if (![CIFilter respondsToSelector:host]) {
            tell([NSString stringWithFormat:@"the host has no +%@, so there is nothing to compare against", selector]);
            continue;
        }
        CIFilter *theirs = ((RevenantMsgSend0)objc_msgSend)((id)[CIFilter class], host);
        CIFilter *ours = ((RevenantMsgSend0)objc_msgSend)((id)[CIFilter class], own);
        compared++;
        if (ours != theirs && ![ours.name isEqualToString:theirs.name]) {
            tell([NSString stringWithFormat:@"+%@ answers %@ where the host answers %@", selector,
                  ours ? ours.name : @"nil", theirs ? theirs.name : @"nil"]);
            continue;
        }
        if (object_getClass(ours) != object_getClass(theirs)) {
            tell([NSString stringWithFormat:@"+%@ class %s vs %s", selector,
                  class_getName(object_getClass(ours)), class_getName(object_getClass(theirs))]);
        }
        if (![ours.name isEqualToString:theirs.name]) {
            tell([NSString stringWithFormat:@"+%@ name %@ vs %@", selector, ours.name, theirs.name]);
        }
        if (![ours.inputKeys isEqualToArray:theirs.inputKeys]) tell([NSString stringWithFormat:@"+%@ inputKeys", selector]);
        if (![ours.outputKeys isEqualToArray:theirs.outputKeys]) tell([NSString stringWithFormat:@"+%@ outputKeys", selector]);
        same_dictionary(ours.attributes, theirs.attributes, [NSString stringWithFormat:@"+%@ attributes", selector]);

        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        NSMutableDictionary *ranges = [NSMutableDictionary dictionary];
        for (NSString *key in theirs.inputKeys) {
            NSDictionary *attribute = theirs.attributes[key];
            @try {
                id value = [theirs valueForKey:key];
                if (value && ![[attribute[@"CIAttributeType"] description] isEqualToString:@"CIAttributeTypeRectangle"])
                    values[key] = value;
            } @catch (NSException *e) {
            }
            if (values[key]) continue;
            NSArray *candidates = supplied_values(attribute, key, input, cube);
            if (candidates.count) {
                values[key] = candidates.firstObject;
                ranges[key] = candidates;
            }
        }
        NSData *bytes[2] = {nil, nil};
        NSUInteger pass = 0;
        for (pass = 0; pass < 5; pass++) {
            CIFilter *pair[2] = {((RevenantMsgSend0)objc_msgSend)((id)[CIFilter class], own),
                                 ((RevenantMsgSend0)objc_msgSend)((id)[CIFilter class], host)};
            for (int i = 0; i < 2; i++) {
                for (NSString *key in pair[i].inputKeys) {
                    NSArray *candidates = ranges[key];
                    id value = candidates ? candidates[MIN(pass, candidates.count - 1)] : values[key];
                    if (!value) continue;
                    @try {
                        [pair[i] setValue:value forKey:key];
                    } @catch (NSException *e) {
                    }
                }
                @try {
                    bytes[i] = bytes_of(pair[i].outputImage);
                } @catch (NSException *e) {
                    bytes[i] = nil;
                }
            }
            if (bytes[0] && bytes[1]) break;
        }
        if (bytes[0] && bytes[1]) {
            rendered++;
            if (![bytes[0] isEqualToData:bytes[1]]) tell([NSString stringWithFormat:@"+%@ output bytes", selector]);
        } else if (getenv("REVENANT_WHY")) {
            CIFilter *probe = ((RevenantMsgSend0)objc_msgSend)((id)[CIFilter class], host);
            for (NSString *key in ranges) {
                NSArray *candidates = ranges[key];
                [probe setValue:candidates[MIN(pass, candidates.count - 1)] forKey:key];
            }
            for (NSString *key in values) {
                if (!ranges[key]) [probe setValue:values[key] forKey:key];
            }
            NSString *why = @"nil";
            @try {
                CIImage *out = probe.outputImage;
                why = out ? [NSString stringWithFormat:@"an image %@", NSStringFromRect(out.extent)] : @"a nil output image";
            } @catch (NSException *e) {
                why = [NSString stringWithFormat:@"%@: %@", e.name, e.reason];
            }
            NSMutableArray *set = [NSMutableArray array];
            for (NSString *key in probe.inputKeys) {
                @try { [set addObject:[NSString stringWithFormat:@"%@=%@", key, [probe valueForKey:key]]]; }
                @catch (NSException *e) { [set addObject:[NSString stringWithFormat:@"%@=!", key]]; }
            }
            printf("why +%s -> %s [%s]\n", selector.UTF8String, why.UTF8String,
                   [set componentsJoinedByString:@" "].UTF8String);
        }
    }
    if (ported.count != 239) {
        tell([NSString stringWithFormat:@"the port's objects carry %lu prefixed constructors, not 239", (unsigned long)ported.count]);
    }
    printf("compared %ld of %lu port constructors against the host's own, %ld rendered and compared, %ld different\n",
           compared, (unsigned long)ported.count, rendered, different);
    return different ? 1 : 0;
}
