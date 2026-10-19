#import "CharonLists.h"

NSString *charon_elided_text(NSString *text)
{
    if (!text.length)
        return @"''";
    NSUInteger length = text.length;
    if (length < 3)
        return [NSString stringWithFormat:@"'%@'", text];
    return [NSString stringWithFormat:@"'%@...%@' (length = %lu)", [text substringToIndex:1], [text substringFromIndex:length - 1], (unsigned long)length];
}

UIFont *charon_medium_font(CGFloat pointSize)
{
    return [UIFont systemFontOfSize:pointSize weight:UIFontWeightMedium];
}

UIFont *charon_medium_body_font(void)
{
    UIFontDescriptor *descriptor = [[UIFont preferredFontForTextStyle:UIFontTextStyleBody].fontDescriptor fontDescriptorByAddingAttributes:@{UIFontDescriptorTraitsAttribute: @{UIFontWeightTrait: @(UIFontWeightMedium)}}];
    return [UIFont fontWithDescriptor:descriptor size:0];
}
