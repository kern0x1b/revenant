#import <UIKit/UIKit.h>
#import "RevenantTraitStyle.h"

static RevenantTraitChangeObserver *revenant_trait_change_observers;
static NSUInteger revenant_trait_change_observer_count;

void revenant_add_trait_change_observer(RevenantTraitChangeObserver observer)
{
    if (!observer)
        return;
    RevenantTraitChangeObserver *grown =
        realloc(revenant_trait_change_observers, (revenant_trait_change_observer_count + 1) * sizeof(*grown));
    if (!grown)
        return;
    revenant_trait_change_observers = grown;
    revenant_trait_change_observers[revenant_trait_change_observer_count++] = observer;
}

void revenant_call_trait_change_observers(NSArray *environments, NSArray *previous)
{
    for (NSUInteger index = 0; index < revenant_trait_change_observer_count; index++)
        revenant_trait_change_observers[index](environments, previous);
}
