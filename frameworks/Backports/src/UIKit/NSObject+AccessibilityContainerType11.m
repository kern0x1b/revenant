#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantContainerTypeKey;
static const char RevenantDragSourcesKey;
static const char RevenantDropPointsKey;

@implementation NSObject (RevenantAccessibilityContainerType11)

- (UIAccessibilityContainerType)accessibilityContainerType
{
    return (UIAccessibilityContainerType)[objc_getAssociatedObject(self, &RevenantContainerTypeKey) integerValue];
}

- (void)setAccessibilityContainerType:(UIAccessibilityContainerType)accessibilityContainerType
{
    objc_setAssociatedObject(self, &RevenantContainerTypeKey, @(accessibilityContainerType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<UIAccessibilityLocationDescriptor *> *)accessibilityDragSourceDescriptors
{
    return objc_getAssociatedObject(self, &RevenantDragSourcesKey);
}

- (void)setAccessibilityDragSourceDescriptors:(NSArray<UIAccessibilityLocationDescriptor *> *)descriptors
{
    objc_setAssociatedObject(self, &RevenantDragSourcesKey, descriptors, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSArray<UIAccessibilityLocationDescriptor *> *)accessibilityDropPointDescriptors
{
    return objc_getAssociatedObject(self, &RevenantDropPointsKey);
}

- (void)setAccessibilityDropPointDescriptors:(NSArray<UIAccessibilityLocationDescriptor *> *)descriptors
{
    objc_setAssociatedObject(self, &RevenantDropPointsKey, descriptors, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
