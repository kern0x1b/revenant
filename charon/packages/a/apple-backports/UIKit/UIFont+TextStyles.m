#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

UIFontTextStyle const UIFontTextStyleHeadline = @"UICTFontTextStyleHeadline";
UIFontTextStyle const UIFontTextStyleSubheadline = @"UICTFontTextStyleSubhead";
UIFontTextStyle const UIFontTextStyleBody = @"UICTFontTextStyleBody";
UIFontTextStyle const UIFontTextStyleFootnote = @"UICTFontTextStyleFootnote";
UIFontTextStyle const UIFontTextStyleCaption1 = @"UICTFontTextStyleCaption1";
UIFontTextStyle const UIFontTextStyleCaption2 = @"UICTFontTextStyleCaption2";

@implementation UIFont (CharonTextStyles)

+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style
{
    if (!style)
        return nil;
    if ([style isEqualToString:UIFontTextStyleHeadline])
        return [UIFont boldSystemFontOfSize:17];
    if ([style isEqualToString:UIFontTextStyleBody])
        return [UIFont systemFontOfSize:17];
    if ([style isEqualToString:UIFontTextStyleSubheadline])
        return [UIFont systemFontOfSize:15];
    if ([style isEqualToString:UIFontTextStyleFootnote])
        return [UIFont systemFontOfSize:13];
    if ([style isEqualToString:UIFontTextStyleCaption1])
        return [UIFont systemFontOfSize:12];
    if ([style isEqualToString:UIFontTextStyleCaption2])
        return [UIFont systemFontOfSize:11];
    if ([style isEqualToString:@"UICTFontTextStyleTitle0"])
        return [UIFont systemFontOfSize:34];
    if ([style isEqualToString:@"UICTFontTextStyleTitle1"])
        return [UIFont systemFontOfSize:28];
    if ([style isEqualToString:@"UICTFontTextStyleTitle2"])
        return [UIFont systemFontOfSize:22];
    if ([style isEqualToString:@"UICTFontTextStyleTitle3"])
        return [UIFont systemFontOfSize:20];
    if ([style isEqualToString:@"UICTFontTextStyleCallout"])
        return [UIFont systemFontOfSize:16];
    return [UIFont systemFontOfSize:12];
}

@end
