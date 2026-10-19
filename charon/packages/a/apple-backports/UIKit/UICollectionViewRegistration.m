#import "CharonLists.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#import <objc/runtime.h>

static const char CharonRegisteredKey;

@interface UICollectionViewCellRegistration (CharonLists)
- (NSString *)charon_identifier;
@end

@interface UICollectionViewSupplementaryRegistration (CharonLists)
- (NSString *)charon_identifier;
@end

@implementation UICollectionViewCellRegistration {
@private
    Class _cellClass;
    UINib *_cellNib;
    UICollectionViewCellRegistrationConfigurationHandler _configurationHandler;
    NSString *_identifier;
}

+ (instancetype)registrationWithCellClass:(Class)cellClass configurationHandler:(UICollectionViewCellRegistrationConfigurationHandler)configurationHandler
{
    UICollectionViewCellRegistration *registration = [[self alloc] init];
    registration->_cellClass = cellClass;
    registration->_configurationHandler = [configurationHandler copy];
    registration->_identifier = [NSString stringWithFormat:@"UICollectionViewCellRegistration.%@.%p", NSStringFromClass(cellClass), registration];
    return registration;
}

+ (instancetype)registrationWithCellNib:(UINib *)cellNib configurationHandler:(UICollectionViewCellRegistrationConfigurationHandler)configurationHandler
{
    UICollectionViewCellRegistration *registration = [[self alloc] init];
    registration->_cellNib = cellNib;
    registration->_configurationHandler = [configurationHandler copy];
    registration->_identifier = [NSString stringWithFormat:@"UICollectionViewCellRegistration.nib.%p", registration];
    return registration;
}

- (Class)cellClass
{
    return _cellClass;
}

- (UINib *)cellNib
{
    return _cellNib;
}

- (UICollectionViewCellRegistrationConfigurationHandler)configurationHandler
{
    return _configurationHandler;
}

- (NSString *)charon_identifier
{
    return _identifier;
}

@end

@implementation UICollectionViewSupplementaryRegistration {
@private
    Class _supplementaryClass;
    UINib *_supplementaryNib;
    NSString *_elementKind;
    UICollectionViewSupplementaryRegistrationConfigurationHandler _configurationHandler;
    NSString *_identifier;
}

+ (instancetype)registrationWithSupplementaryClass:(Class)supplementaryClass elementKind:(NSString *)elementKind
                              configurationHandler:(UICollectionViewSupplementaryRegistrationConfigurationHandler)configurationHandler
{
    UICollectionViewSupplementaryRegistration *registration = [[self alloc] init];
    registration->_supplementaryClass = supplementaryClass;
    registration->_elementKind = [elementKind copy];
    registration->_configurationHandler = [configurationHandler copy];
    registration->_identifier = [NSString stringWithFormat:@"UICollectionViewSupplementaryRegistration.%@.%@.%p", NSStringFromClass(supplementaryClass), elementKind, registration];
    return registration;
}

+ (instancetype)registrationWithSupplementaryNib:(UINib *)supplementaryNib elementKind:(NSString *)elementKind
                            configurationHandler:(UICollectionViewSupplementaryRegistrationConfigurationHandler)configurationHandler
{
    UICollectionViewSupplementaryRegistration *registration = [[self alloc] init];
    registration->_supplementaryNib = supplementaryNib;
    registration->_elementKind = [elementKind copy];
    registration->_configurationHandler = [configurationHandler copy];
    registration->_identifier = [NSString stringWithFormat:@"UICollectionViewSupplementaryRegistration.nib.%@.%p", elementKind, registration];
    return registration;
}

- (Class)supplementaryClass
{
    return _supplementaryClass;
}

- (UINib *)supplementaryNib
{
    return _supplementaryNib;
}

- (NSString *)elementKind
{
    return _elementKind;
}

- (UICollectionViewSupplementaryRegistrationConfigurationHandler)configurationHandler
{
    return _configurationHandler;
}

- (NSString *)charon_identifier
{
    return _identifier;
}

@end

static BOOL charon_first_use(UICollectionView *view, NSString *identifier)
{
    NSMutableSet *known = objc_getAssociatedObject(view, &CharonRegisteredKey);
    if (!known) {
        known = [[NSMutableSet alloc] init];
        objc_setAssociatedObject(view, &CharonRegisteredKey, known, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if ([known containsObject:identifier])
        return NO;
    [known addObject:identifier];
    return YES;
}

@implementation UICollectionView (CharonRegistrations)

- (__kindof UICollectionViewCell *)dequeueConfiguredReusableCellWithRegistration:(UICollectionViewCellRegistration *)registration forIndexPath:(NSIndexPath *)indexPath item:(id)item
{
    NSString *identifier = [registration charon_identifier];
    if (!identifier)
        [NSException raise:NSInternalInconsistencyException format:@"UIKit internal inconsistency: registration missing reuse identifier (null)"];
    if (charon_first_use(self, identifier)) {
        if (registration.cellNib)
            [self registerNib:registration.cellNib forCellWithReuseIdentifier:identifier];
        else
            [self registerClass:registration.cellClass forCellWithReuseIdentifier:identifier];
    }
    UICollectionViewCell *cell = [self dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:indexPath];
    if (registration.configurationHandler)
        registration.configurationHandler(cell, indexPath, item);
    return cell;
}

- (__kindof UICollectionReusableView *)dequeueConfiguredReusableSupplementaryViewWithRegistration:(UICollectionViewSupplementaryRegistration *)registration forIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = [registration charon_identifier];
    if (!identifier)
        [NSException raise:NSInternalInconsistencyException format:@"UIKit internal inconsistency: registration missing element kind (null)"];
    if (charon_first_use(self, identifier)) {
        if (registration.supplementaryNib)
            [self registerNib:registration.supplementaryNib forSupplementaryViewOfKind:registration.elementKind withReuseIdentifier:identifier];
        else
            [self registerClass:registration.supplementaryClass forSupplementaryViewOfKind:registration.elementKind withReuseIdentifier:identifier];
    }
    UICollectionReusableView *view = [self dequeueReusableSupplementaryViewOfKind:registration.elementKind withReuseIdentifier:identifier forIndexPath:indexPath];
    if (registration.configurationHandler)
        registration.configurationHandler(view, registration.elementKind, indexPath);
    return view;
}

@end
