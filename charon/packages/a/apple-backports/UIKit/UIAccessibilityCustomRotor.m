#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// The accessibility rotor, the list an assistive technology walks through an application by. A
// rotor is a name and a block: given a predicate saying where the search is and which way it goes,
// the block answers the next element the rotor should stop on. The element that exposes it is any
// object, through accessibilityCustomRotors.
//
// The release's VoiceOver has no rotor at all, so nothing on this release ever asks a rotor for its
// next item and no block here is ever run by the system. That is the seam and it is written down
// in facts/UIKit/AccessibilityRotor.md; the objects themselves are real, hold what they are given
// and answer for it, and an application that drives them itself gets the same answers the host's
// own UIKit gives, measured under Mac Catalyst and held by tests/backports/host/uikitrotor.
static const char CharonRotorsKey;

@implementation UIAccessibilityCustomRotorSearchPredicate {
@private
    // The item the search is at, and which way it goes from it. The header asks for the current item
    // first, so a block that returns nothing for the first call knows it is at the start.
    UIAccessibilityCustomRotorItemResult *_currentItem;
    UIAccessibilityCustomRotorDirection _searchDirection;
}

- (UIAccessibilityCustomRotorItemResult *)currentItem
{
    return _currentItem;
}

- (void)setCurrentItem:(UIAccessibilityCustomRotorItemResult *)currentItem
{
    _currentItem = currentItem;
}

- (UIAccessibilityCustomRotorDirection)searchDirection
{
    return _searchDirection;
}

- (void)setSearchDirection:(UIAccessibilityCustomRotorDirection)searchDirection
{
    _searchDirection = searchDirection;
}

@end

@implementation UIAccessibilityCustomRotorItemResult {
@private
    // The element the rotor stops on, held weakly as the header says: a result is a place in an
    // element, not a claim on it, and a text view that goes away takes its results with it.
    __unsafe_unretained id _targetElement;
    UITextRange *_targetRange;
}

- (instancetype)initWithTargetElement:(id<NSObject>)targetElement targetRange:(UITextRange *)targetRange
{
    if ((self = [super init])) {
        _targetElement = targetElement;
        _targetRange = targetRange;
    }
    return self;
}

- (instancetype)init
{
    if ((self = [super init]))
        ;
    return self;
}

- (id<NSObject>)targetElement
{
    return _targetElement;
}

- (void)setTargetElement:(id<NSObject>)targetElement
{
    _targetElement = targetElement;
}

- (UITextRange *)targetRange
{
    return _targetRange;
}

- (void)setTargetRange:(UITextRange *)targetRange
{
    _targetRange = targetRange;
}

@end

@implementation UIAccessibilityCustomRotor {
@private
    NSString *_name;
    NSAttributedString *_attributedName;
    UIAccessibilityCustomRotorSearch _itemSearchBlock;
    UIAccessibilityCustomSystemRotorType _systemRotorType;
}

- (instancetype)initWithName:(NSString *)name itemSearchBlock:(UIAccessibilityCustomRotorSearch)itemSearchBlock
{
    if ((self = [super init])) {
        _name = [name copy];
        _itemSearchBlock = [itemSearchBlock copy];
        _systemRotorType = UIAccessibilityCustomSystemRotorTypeNone;
    }
    return self;
}

// The attributed name is the name, styled: setting either moves the other, which is what the header
// says of them, so an assistive technology reading either one describes the rotor the same way.
- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName itemSearchBlock:(UIAccessibilityCustomRotorSearch)itemSearchBlock
{
    if ((self = [super init])) {
        _attributedName = [attributedName copy];
        _name = [attributedName.string copy];
        _itemSearchBlock = [itemSearchBlock copy];
        _systemRotorType = UIAccessibilityCustomSystemRotorTypeNone;
    }
    return self;
}

- (instancetype)initWithSystemType:(UIAccessibilityCustomSystemRotorType)type itemSearchBlock:(UIAccessibilityCustomRotorSearch)itemSearchBlock
{
    if ((self = [super init])) {
        _itemSearchBlock = [itemSearchBlock copy];
        _systemRotorType = type;
    }
    return self;
}

- (instancetype)init
{
    if ((self = [super init]))
        _systemRotorType = UIAccessibilityCustomSystemRotorTypeNone;
    return self;
}

- (NSString *)name
{
    return _name;
}

// The two names are kept in step in both directions, as the header says of them, and setting the
// plain one keeps the style of the attributed one rather than dropping it: measured on the host,
// a rotor made with a plain name already has an attributed name, and setting either name leaves the
// other describing the same rotor.
- (void)setName:(NSString *)name
{
    _name = [name copy];
    if (!_attributedName)
        _attributedName = [[NSAttributedString alloc] initWithString:name ?: @""];
    else
        _attributedName = [[NSAttributedString alloc] initWithString:name ?: @""
                                                                 attributes:[_attributedName attributesAtIndex:0 effectiveRange:NULL]];
}

- (NSAttributedString *)attributedName
{
    return _attributedName;
}

- (void)setAttributedName:(NSAttributedString *)attributedName
{
    _attributedName = [attributedName copy];
    _name = [attributedName.string copy];
}

- (UIAccessibilityCustomRotorSearch)itemSearchBlock
{
    return _itemSearchBlock;
}

- (void)setItemSearchBlock:(UIAccessibilityCustomRotorSearch)itemSearchBlock
{
    _itemSearchBlock = [itemSearchBlock copy];
}

- (UIAccessibilityCustomSystemRotorType)systemRotorType
{
    return _systemRotorType;
}

@end

@implementation NSObject (CharonAccessibilityCustomRotor)

// The rotors this object exposes. Every object can hold them, not only accessibility elements, and
// an element or an ancestor of one is where an assistive technology looks, so the storage is the
// object itself rather than a subclass of ours.
- (NSArray<UIAccessibilityCustomRotor *> *)accessibilityCustomRotors
{
    return objc_getAssociatedObject(self, &CharonRotorsKey);
}

- (void)setAccessibilityCustomRotors:(NSArray<UIAccessibilityCustomRotor *> *)accessibilityCustomRotors
{
    objc_setAssociatedObject(self, &CharonRotorsKey, accessibilityCustomRotors, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
