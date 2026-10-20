#import <UIKit/UIKit.h>

@implementation NSTextElement (Elements16)

- (NSArray<__kindof NSTextElement *> *)childElements
{
    return @[];
}

- (NSTextElement *)parentElement
{
    return nil;
}

- (BOOL)isRepresentedElement
{
    return YES;
}

@end

@implementation NSTextParagraph (Elements16)

- (BOOL)isRepresentedElement
{
    return YES;
}

@end
