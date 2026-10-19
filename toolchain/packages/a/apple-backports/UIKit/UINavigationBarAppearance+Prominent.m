#import "CharonBarAppearance.h"

@implementation UINavigationBarAppearance (CharonProminent)

- (UIBarButtonItemAppearance *)prominentButtonAppearance
{
    return self.doneButtonAppearance;
}

- (void)setProminentButtonAppearance:(UIBarButtonItemAppearance *)prominentButtonAppearance
{
    self.doneButtonAppearance = prominentButtonAppearance;
}

@end

@implementation UIToolbarAppearance (CharonProminent)

- (UIBarButtonItemAppearance *)prominentButtonAppearance
{
    return self.doneButtonAppearance;
}

- (void)setProminentButtonAppearance:(UIBarButtonItemAppearance *)prominentButtonAppearance
{
    self.doneButtonAppearance = prominentButtonAppearance;
}

@end
