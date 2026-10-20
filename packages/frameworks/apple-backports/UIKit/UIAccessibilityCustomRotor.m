#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantRotorsKey;

@implementation UIAccessibilityCustomRotorSearchPredicate {
@private
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

@implementation NSObject (RevenantAccessibilityCustomRotor)

- (NSArray<UIAccessibilityCustomRotor *> *)accessibilityCustomRotors
{
    return objc_getAssociatedObject(self, &RevenantRotorsKey);
}

- (void)setAccessibilityCustomRotors:(NSArray<UIAccessibilityCustomRotor *> *)accessibilityCustomRotors
{
    objc_setAssociatedObject(self, &RevenantRotorsKey, accessibilityCustomRotors, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
