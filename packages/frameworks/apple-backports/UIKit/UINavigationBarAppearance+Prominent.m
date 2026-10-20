#import "RevenantBarAppearance.h"

@implementation UINavigationBarAppearance (RevenantProminent)

- (UIBarButtonItemAppearance *)prominentButtonAppearance
{
    return self.doneButtonAppearance;
}

- (void)setProminentButtonAppearance:(UIBarButtonItemAppearance *)prominentButtonAppearance
{
    self.doneButtonAppearance = prominentButtonAppearance;
}

@end

@implementation UIToolbarAppearance (RevenantProminent)

- (UIBarButtonItemAppearance *)prominentButtonAppearance
{
    return self.doneButtonAppearance;
}

- (void)setProminentButtonAppearance:(UIBarButtonItemAppearance *)prominentButtonAppearance
{
    self.doneButtonAppearance = prominentButtonAppearance;
}

@end
