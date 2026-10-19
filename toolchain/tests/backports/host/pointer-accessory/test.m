#import <UIKit/UIKit.h>
#include <stdio.h>

static void report(const char *check, NSString *value)
{
    printf("%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *class_name(id object)
{
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"RevenantPort"] ? [name substringFromIndex:12] : name;
}

static NSString *position_text(UIPointerAccessoryPosition position)
{
    return [NSString stringWithFormat:@"%g,%g", position.offset, position.angle];
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);

        UIPointerShape *shape = [UIPointerShape shapeWithRoundedRect:CGRectMake(0, 0, 8, 8) cornerRadius:2];
        UIPointerAccessory *accessory = [UIPointerAccessory accessoryWithShape:shape position:UIPointerAccessoryPositionMake(14, 3.0 * M_PI / 2.0 + M_PI / 4.0)];
        report("accessory-class", class_name(accessory));
        report("accessory-shape-class", class_name(accessory.shape));
        report("accessory-shape-same", yes_no(accessory.shape == shape));
        report("accessory-position-top-left", position_text(accessory.position));
        UIPointerAccessory *placed = [UIPointerAccessory accessoryWithShape:shape position:UIPointerAccessoryPositionMake(3, 1.5)];
        report("accessory-position-made", position_text(placed.position));

        report("accessory-orientation-default", yes_no(accessory.orientationMatchesAngle));
        accessory.orientationMatchesAngle = YES;
        report("accessory-orientation-set", yes_no(accessory.orientationMatchesAngle));

        UIPointerAccessory *copied = [accessory copy];
        report("accessory-copy-same-object", yes_no(copied == accessory));
        report("accessory-copy-orientation", yes_no(copied.orientationMatchesAngle));
        report("accessory-copy-position", position_text(copied.position));

        UIPointerStyle *style = [UIPointerStyle styleWithShape:shape constrainedAxes:(UIAxis)0];
        report("style-accessories-default", style.accessories ? [NSString stringWithFormat:@"%lu", (unsigned long)style.accessories.count] : @"nil");
        NSMutableArray *given = [NSMutableArray arrayWithObjects:accessory, placed, nil];
        style.accessories = given;
        report("style-accessories-count", [NSString stringWithFormat:@"%lu", (unsigned long)style.accessories.count]);
        report("style-accessories-same-array", yes_no(style.accessories == given));
        report("style-accessories-same-element", yes_no(style.accessories[0] == accessory));
        [given removeAllObjects];
        report("style-accessories-after-change", [NSString stringWithFormat:@"%lu", (unsigned long)style.accessories.count]);
        report("style-accessories-class", class_name(style.accessories));

        style.accessories = @[accessory];
        UIPointerStyle *styleCopy = [style copy];
        report("style-copy-count", [NSString stringWithFormat:@"%lu", (unsigned long)styleCopy.accessories.count]);
        report("style-copy-same-element", yes_no(styleCopy.accessories[0] == accessory));

        style.accessories = nil;
        report("style-accessories-cleared", style.accessories ? [NSString stringWithFormat:@"%lu", (unsigned long)style.accessories.count] : @"nil");

        UIPointerAccessory *arrow = [UIPointerAccessory arrowAccessoryWithPosition:UIPointerAccessoryPositionMake(14, 3.0 * M_PI / 2.0 + M_PI / 4.0)];
        report("arrow-class", class_name(arrow));
        report("arrow-shape-class", class_name(arrow.shape));
        report("arrow-position", position_text(arrow.position));
        report("arrow-orientation-default", yes_no(arrow.orientationMatchesAngle));
        UIPointerAccessory *arrowAtZero = [UIPointerAccessory arrowAccessoryWithPosition:UIPointerAccessoryPositionMake(0, 0)];
        report("arrow-position-zero", position_text(arrowAtZero.position));
        report("arrow-shapes-equal", yes_no([arrow.shape isEqual:arrowAtZero.shape]));
        report("arrow-shapes-same-object", yes_no(arrow.shape == arrowAtZero.shape));
        report("arrow-shape-not-rounded", yes_no([arrow.shape isEqual:[UIPointerShape shapeWithRoundedRect:CGRectMake(0, 0, 8, 8) cornerRadius:2]]));
        UIPointerAccessory *arrowCopy = [arrow copy];
        report("arrow-copy-orientation", yes_no(arrowCopy.orientationMatchesAngle));
        arrow.orientationMatchesAngle = NO;
        report("arrow-orientation-set-no", yes_no(arrow.orientationMatchesAngle));

        UIBezierPath *arrowPath = [arrow.shape valueForKey:@"path"];
        report("arrow-path-class", class_name(arrowPath));
        report("arrow-path-bounds", NSStringFromCGRect(CGPathGetBoundingBox(arrowPath.CGPath)));
        __block int index = 0;
        CGPathApplyWithBlock(arrowPath.CGPath, ^(const CGPathElement *element) {
            int count = element->type == kCGPathElementCloseSubpath ? 0 : element->type == kCGPathElementAddCurveToPoint ? 3 : 1;
            NSMutableString *line = [NSMutableString stringWithFormat:@"%d %d", index++, (int)element->type];
            for (int i = 0; i < count; i++)
                [line appendFormat:@" %.17g,%.17g", element->points[i].x, element->points[i].y];
            report("arrow-element", line);
        });
    }
    return 0;
}
