#import <UIKit/UIKit.h>

// -[UIContentView supportsConfiguration:], iOS 16.0.
//
// The header says a view is compatible when it can accept the provided configuration: it takes the
// configuration in its configuration property and can update itself to match. Where the method is absent, the view is taken
// to be compatible with any configuration class that matches the class of its existing configuration.
//
// The port has exactly one content view - UIListContentView, the one -[UIListContentConfiguration
// makeContentView] answers - and CharonConfigurationHost.m's install path already tests the header's
// own rule when it replaces a configuration: it reuses the installed view when the new configuration
// makes the same kind of view, and makes a new one otherwise. So this method answers that test
// instead of a second, weaker one, which is what lets a caller ask before installing.

@implementation UIListContentView (CharonSupportsConfiguration16)

- (BOOL)supportsConfiguration:(id<UIContentConfiguration>)configuration
{
    if (!configuration)
        return NO;
    // The kind of view this configuration would install: the same kind means this view can take it
    // and update itself for it, which is the header's definition of compatible.
    return [[[configuration makeContentView] class] isSubclassOfClass:[self class]];
}

@end