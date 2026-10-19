#import "textattr-cases.h"

typedef struct {
    int red, blue, black, left, right, top, bottom;
    double lean, centroid;
    int total;
} Ink;

static Ink measure(NSAttributedString *string, CGSize size, int mode)
{
    UIGraphicsBeginImageContextWithOptions(size, YES, 1);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIColor whiteColor] setFill];
    CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    if (mode == 0) {
        [string drawAtPoint:CGPointMake(20, 10)];
    } else if (mode == 1) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, size.width - 40, size.height - 20)];
        label.backgroundColor = [UIColor whiteColor];
        label.attributedText = string;
        [label.layer renderInContext:context];
    } else {
        NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:string];
        NSLayoutManager *manager = [[NSLayoutManager alloc] init];
        NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(size.width - 40, size.height - 20)];
        [manager addTextContainer:container];
        [storage addLayoutManager:manager];
        NSRange glyphs = [manager glyphRangeForTextContainer:container];
        [manager drawBackgroundForGlyphRange:glyphs atPoint:CGPointMake(20, 10)];
        [manager drawGlyphsForGlyphRange:glyphs atPoint:CGPointMake(20, 10)];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGImageRef cg = image.CGImage;
    size_t width = CGImageGetWidth(cg), height = CGImageGetHeight(cg);
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(data.mutableBytes, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), cg);
    CGContextRelease(bitmap);
    CGColorSpaceRelease(space);
    const unsigned char *pixels = data.bytes;
    Ink ink = {0, 0, 0, (int)width, -1, (int)height, -1, 0, 0, 0};
    double allX = 0;
    double topSum = 0, bottomSum = 0;
    int topCount = 0, bottomCount = 0;
    for (size_t y = 0; y < height; y++)
        for (size_t x = 0; x < width; x++) {
            const unsigned char *p = pixels + (y * width + x) * 4;
            int r = p[0], g = p[1], b = p[2];
            if (r > 235 && g > 235 && b > 235)
                continue;
            if (r > 150 && g < 100 && b < 100)
                ink.red++;
            else if (b > 150 && r < 100 && g < 100)
                ink.blue++;
            else if (r < 90 && g < 90 && b < 90)
                ink.black++;
            ink.total++;
            allX += x;
            if (r < 90 && g < 90 && b < 90) {
                if (y < height / 2) {
                    topSum += x;
                    topCount++;
                } else {
                    bottomSum += x;
                    bottomCount++;
                }
            }
            ink.left = MIN(ink.left, (int)x);
            ink.right = MAX(ink.right, (int)x);
            ink.top = MIN(ink.top, (int)y);
            ink.bottom = MAX(ink.bottom, (int)y);
        }
    ink.centroid = ink.total ? allX / ink.total : 0;
    ink.lean = topCount && bottomCount ? topSum / topCount - bottomSum / bottomCount : 0;
    return ink;
}

static NSString *describe(Ink ink, Ink plain)
{
    return [NSString stringWithFormat:@"red %d blue %d black %d width %d height %d top %d bottom %d lean %.0f total %d centroid %.0f", ink.red, ink.blue, ink.black, (ink.right - ink.left) - (plain.right - plain.left), (ink.bottom - ink.top) - (plain.bottom - plain.top), ink.top - plain.top, ink.bottom - plain.bottom, ink.lean - plain.lean, ink.total - plain.total, ink.centroid - plain.centroid];
}

void textattr_run(TextAttrRecorder record)
{
    UIFont *font = [UIFont fontWithName:@"Courier" size:20];
    CGSize size = CGSizeMake(260, 60);
    NSString *text = @"Hello, World";
    NSArray *modes = @[@"draw", @"label", @"layout"];
    for (int mode = 0; mode < 3; mode++) {
        NSAttributedString *plainString = [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: [UIColor blackColor]}];
        Ink plain = measure(plainString, size, mode);
        NSString *tag = modes[mode];
        record([tag stringByAppendingString:@" plain"], describe(plain, plain));
        NSDictionary *cases = @{
            @"underline": @{NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)},
            @"underline red": @{NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle), NSUnderlineColorAttributeName: [UIColor redColor]},
            @"strike": @{NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle)},
            @"strike blue": @{NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle), NSStrikethroughColorAttributeName: [UIColor blueColor]},
            @"oblique": @{NSObliquenessAttributeName: @0.4},
            @"oblique large": @{NSObliquenessAttributeName: @1.0},
            @"oblique back": @{NSObliquenessAttributeName: @-0.5},
            @"expansion": @{NSExpansionAttributeName: @0.5},
            @"kern": @{NSKernAttributeName: @6},
            @"baseline up": @{NSBaselineOffsetAttributeName: @12},
            @"letterpress": @{NSTextEffectAttributeName: NSTextEffectLetterpressStyle},
            @"stroke": @{NSStrokeWidthAttributeName: @-5, NSStrokeColorAttributeName: [UIColor redColor]},
        };
        for (NSString *name in [cases.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, [UIColor blackColor], NSForegroundColorAttributeName, nil];
            [attributes addEntriesFromDictionary:cases[name]];
            NSAttributedString *string = [[NSAttributedString alloc] initWithString:text attributes:attributes];
            record([NSString stringWithFormat:@"%@ %@", tag, name], describe(measure(string, size, mode), plain));
        }
        NSDictionary *base = @{NSFontAttributeName: font, NSForegroundColorAttributeName: [UIColor blackColor]};
        NSString *lopsided = @"iiiiiiiiWWWW";
        Ink lopsidedPlain = measure([[NSAttributedString alloc] initWithString:lopsided attributes:base], size, mode);
        NSMutableDictionary *overridden = [NSMutableDictionary dictionaryWithDictionary:base];
        overridden[NSWritingDirectionAttributeName] = @[@(NSWritingDirectionRightToLeft | NSTextWritingDirectionOverride)];
        record([tag stringByAppendingString:@" override"], describe(measure([[NSAttributedString alloc] initWithString:lopsided attributes:overridden], size, mode), lopsidedPlain));
    }
}
