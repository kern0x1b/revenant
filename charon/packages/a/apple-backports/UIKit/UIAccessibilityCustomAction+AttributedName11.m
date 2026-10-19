#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-property-implementation"
// the SDK header declares this member on the class, and the port builds the class itself, so the
// category implementing it is the whole of the answer here; UIAccessibilityCustomAction+Handler13.m
// silences the same warning for the same reason
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The attributed name of a custom action, arrived in iOS 11.0. Its own file rather than the class's,
// which carries the 7.0 initialiser: one object, one release, which is what tools/release-split.lua
// reads. The class's ivars are in that other file and this file may not name them -- a file whose
// release already has an API symbol is left out of the earlier bands, so a call across would be an
// undefined symbol there and in the earlier bands only -- so what this file keeps is the part that is
// its own: the attributes.
//
// What it is: the name, styled, and the STRING is the plain name the class already keeps. Recorded
// from the host's own UIKit under Mac Catalyst by tests/backports/host/uikitconst over the cases in
// device/uikitconst-cases.m, which the device test reads:
//   - an action made with a plain name ALREADY has an attributed name, and its string is that name;
//   - setting the attributed one sets the plain name;
//   - setting the plain one leaves the attributed name describing the same action, keeping the style;
//   - initWithAttributedName:target:selector: keeps the attributes it was given and the target it was
//     passed.
// So the two are one name in two spellings, the plain one is the string and this file is the style,
// and neither is a second source of truth for the other. Deriving the string rather than storing it is
// what makes setName: work without this file touching the class's own setter: a category cannot
// override the method the class itself implements, so moving the string across in both directions from
// here would either lose the plain write or call the plain setter in a loop.
static const char charon_attributed_attributes_key;

@implementation UIAccessibilityCustomAction (CharonAttributedName11)

- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName target:(id)target selector:(SEL)selector
{
    self = [self initWithName:attributedName.string target:target selector:selector];
    if (self && attributedName.length > 0) {
        // the attributes of the whole string, which is what the host keeps too: a custom action's name
        // is styled as one run, and splitting it into per-run attributes would answer something the
        // header does not have a place for
        objc_setAssociatedObject(self, &charon_attributed_attributes_key,
                                 [[attributedName attributesAtIndex:0 effectiveRange:NULL] copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return self;
}

- (NSAttributedString *)attributedName
{
    // An action made with no name still has one, and it is the empty string: measured on the host, an
    // action from -initWithName:nil target: nil selector: NULL answers a `name` of length 0 and an
    // `attributedName` whose string is empty and which is not nil at all. So this does not answer nil
    // for a name it has none of -- the plain name is already nil here and the host substitutes the
    // empty string, and a caller asking an action for the string it is described by gets one back.
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
    // a send, not a dot-syntax write: a write is renamed by the property name it reads, and a category
    // on a host class has both the accessor and the setter renamed. The plain setter only changes the
    // string, and the getter above reads it back, so the two stay in step with no path back here.
    [self setName:attributedName.string];
}

@end
