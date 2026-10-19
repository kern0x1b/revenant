#import <UIKit/UIKit.h>

static NSString *const CharonScaleSuffixes[] = {@"", @"@2x", @"@3x"};

static NSArray<NSNumber *> *charon_scale_order(CGFloat wanted)
{
    NSInteger want = wanted >= 2.5 ? 3 : (wanted >= 1.5 ? 2 : 1);
    NSMutableArray *order = [NSMutableArray arrayWithObject:@(want)];
    for (NSInteger scale = want + 1; scale <= 3; scale++)
        [order addObject:@(scale)];
    for (NSInteger scale = want - 1; scale >= 1; scale--)
        [order addObject:@(scale)];
    return order;
}

@implementation UIImage (CharonNamedInBundle)

+ (UIImage *)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
    if (!name.length)
        return nil;
    if (!bundle)
        bundle = [NSBundle mainBundle];
    UIUserInterfaceIdiom idiom = UI_USER_INTERFACE_IDIOM();
    CGFloat scale = [UIScreen mainScreen].scale;
    if (traitCollection) {
        if (traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad || traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPhone)
            idiom = traitCollection.userInterfaceIdiom;
        if (traitCollection.displayScale > 0)
            scale = traitCollection.displayScale;
    }
    NSString *extension = name.pathExtension;
    NSString *stem = name;
    if (extension.length)
        stem = [name stringByDeletingPathExtension];
    else
        extension = @"png";
    NSArray *idioms = idiom == UIUserInterfaceIdiomPad ? @[@"~ipad", @""] : @[@"~iphone", @""];
    for (NSString *idiomSuffix in idioms) {
        for (NSNumber *candidate in charon_scale_order(scale)) {
            NSInteger factor = candidate.integerValue;
            NSString *resource = [NSString stringWithFormat:@"%@%@%@", stem, CharonScaleSuffixes[factor - 1], idiomSuffix];
            NSString *path = nil;
            NSString *file = [resource stringByAppendingPathExtension:extension];
            if (bundle.resourcePath) {
                NSString *direct = [bundle.resourcePath stringByAppendingPathComponent:file];
                if ([[NSFileManager defaultManager] fileExistsAtPath:direct])
                    path = direct;
            }
            if (!path) {
                NSString *found = [bundle pathForResource:resource ofType:extension];
                if (found && [found.lastPathComponent caseInsensitiveCompare:file.lastPathComponent] == NSOrderedSame)
                    path = found;
            }
            if (!path)
                continue;
            NSData *data = [NSData dataWithContentsOfFile:path];
            UIImage *image = data ? [[UIImage alloc] initWithData:data scale:factor] : nil;
            if (image)
                return image;
        }
    }
    if (bundle == [NSBundle mainBundle])
        return [UIImage imageNamed:name];
    return nil;
}

@end
