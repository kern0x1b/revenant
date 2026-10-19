// The three members of the text element tree that arrived in iOS 16, as a category, because a file carries the
// API of one release and a second @implementation of the same class is a duplicate symbol at link. What the
// header declares is in NSTextElement.h of SDK 26.2; what the host's own UIKit answers is in
// facts/UIKit/NSTextRange15.md.
//
// An element tree is what these three describe, and the port carries the shape of it rather than the layout
// that fills it: an element with no parent has no children, and every element is one the content manager
// enumerates. The tree the layout classes build - a table's rows inside a table, a list element inside a
// paragraph - is the content manager's to make out of elements an application or a subclass supplies, and these
// are the three answers that describe whatever tree it made.

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
    // Every element is one the document enumerates, the base class included: the host answers YES for a plain
    // NSTextElement and for a paragraph, and there is nothing abstract about a property the answer cannot
    // vary (M4).
    return YES;
}

@end

@implementation NSTextParagraph (Elements16)

- (BOOL)isRepresentedElement
{
    return YES;
}

@end
