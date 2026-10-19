#import <UIKit/UIKit.h>
#import "CharonTraitStyle.h"

static CharonTraitChangeObserver *charon_trait_change_observers;
static NSUInteger charon_trait_change_observer_count;

void charon_add_trait_change_observer(CharonTraitChangeObserver observer)
{
    if (!observer)
        return;
    CharonTraitChangeObserver *grown =
        realloc(charon_trait_change_observers, (charon_trait_change_observer_count + 1) * sizeof(*grown));
    if (!grown)
        return;
    charon_trait_change_observers = grown;
    charon_trait_change_observers[charon_trait_change_observer_count++] = observer;
}

void charon_call_trait_change_observers(NSArray *environments, NSArray *previous)
{
    for (NSUInteger index = 0; index < charon_trait_change_observer_count; index++)
        charon_trait_change_observers[index](environments, previous);
}
