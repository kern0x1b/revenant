#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_attributed_attributes_key;

@implementation UIAccessibilityCustomAction (CharonAttributedName11)

- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName target:(id)target selector:(SEL)selector
{
    self = [self initWithName:attributedName.string target:target selector:selector];
    if (self && attributedName.length > 0) {
        objc_setAssociatedObject(self, &charon_attributed_attributes_key,
                                 [[attributedName attributesAtIndex:0 effectiveRange:NULL] copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return self;
}

- (NSAttributedString *)attributedName
{
    NSString *name = self.name ?: @"";
    NSDictionary *attributes = objc_getAssociatedObject(self, &charon_attributed_attributes_key);
    return attributes ? [[NSAttributedString alloc] initWithString:name attributes:attributes]
                      : [[NSAttributedString alloc] initWithString:name];
}

- (void)setAttributedName:(NSAttributedString *)attributedName
{
    NSDictionary *attributes = nil;
    if (attributedName.length > 0)
        attributes = [[attributedName attributesAtIndex:0 effectiveRange:NULL] copy];
    objc_setAssociatedObject(self, &charon_attributed_attributes_key, attributes, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self setName:attributedName.string];
}

@end
