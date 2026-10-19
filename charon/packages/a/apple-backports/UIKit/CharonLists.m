#import "CharonLists.h"

// charon_semantic_color used to be defined here and is now `static inline` in CharonLists.h, with the body
// unchanged: see the comment there for why a C function a class file calls is a cross-file symbol at all.
NSString *charon_elided_text(NSString *text)
{
    if (!text.length)
        return @"''";
    NSUInteger length = text.length;
    if (length < 3)
        return [NSString stringWithFormat:@"'%@'", text];
    return [NSString stringWithFormat:@"'%@...%@' (length = %lu)", [text substringToIndex:1], [text substringFromIndex:length - 1], (unsigned long)length];
}

// charon_screen_scale, charon_pixel_ceil and charon_pixel_round used to be defined here and are now
// `static inline` in CharonLists.h, with the bodies unchanged: see the comment there for why a C function
// a class file calls is a cross-file symbol at all.

UIFont *charon_medium_font(CGFloat pointSize)
{
    return [UIFont systemFontOfSize:pointSize weight:UIFontWeightMedium];
}

UIFont *charon_medium_body_font(void)
{
    /* The sidebar header's font is the body text style at the medium weight, as the host builds it: it keeps the
       style's line spacing there, which a plain medium system font lacks. iOS 6 has no medium face and no style
       leading: this is the release's regular 17-point system font (measured on an iPad 2, 6.1.3;
       facts/UIKit/UIListContentConfiguration.md). */
    UIFontDescriptor *descriptor = [[UIFont preferredFontForTextStyle:UIFontTextStyleBody].fontDescriptor fontDescriptorByAddingAttributes:@{UIFontDescriptorTraitsAttribute: @{UIFontWeightTrait: @(UIFontWeightMedium)}}];
    return [UIFont fontWithDescriptor:descriptor size:0];
}
