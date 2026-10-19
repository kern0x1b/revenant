#import <UIKit/UIKit.h>

UIUserInterfaceStyle charon_trait_style(UITraitCollection *collection);
void charon_set_trait_style(UITraitCollection *collection, UIUserInterfaceStyle style);

// A listener for a trait change, called with the environments that were told and the collection each had
// before, once the change is made. The collection of iOS 17 registers one; see UITraitCollection.m for why a
// listener registers itself rather than being called there by name. Both of these are defined in
// CharonTraitObservers.m, an object that exports no API symbol of its own, because the file that makes the
// change and the file that listens for it are carried from two different releases and a band cannot hold both.
typedef void (*CharonTraitChangeObserver)(NSArray *environments, NSArray *previous);
void charon_add_trait_change_observer(CharonTraitChangeObserver observer);
void charon_call_trait_change_observers(NSArray *environments, NSArray *previous);

// A reader for the value a collection carries for the trait a name is, asked with the name the description knows
// that trait by. known answers whether the port has a definition for the name at all, and isDefault whether the
// value is the one the trait class calls its own default - which is a trait the description prints as nothing.
// Both are answers in their own right and neither is "no value": a trait the port has a definition for is read
// through the definition's own home, and the extras dictionary is where the traits it has no definition for
// live, so a caller that cannot tell the two apart reads a trait of the second kind out of the first kind's
// place. The trait table is carried from 6.0 and a collection's description from 5.0, so the table registers a
// reader and the description asks it; see UITraitCollection+Appearance13.m.
// The type and the registrar are declared in CharonTraits17.h, beside the table they read.

typedef struct {
    __unsafe_unretained NSString *name;
    NSInteger screenDefault;
    int described;
    __unsafe_unretained NSString *first;
    __unsafe_unretained NSString *second;
} CharonTraitKind;

// The `described` code a kind carries is how its value is printed in a collection's description: 0 not at all,
// 1 the pair first/second for a value of 0 or 1, 2 the comma-separated list in `first` indexed by the value, and
// 3 the stored value itself, which is what the object traits of iOS 17 need because they have no pair to print.

void charon_register_trait_kind(CharonTraitKind kind);
NSInteger charon_trait_extra(UITraitCollection *collection, NSString *name);
void charon_set_trait_extra(UITraitCollection *collection, NSString *name, NSInteger value);
NSDictionary *charon_trait_extras(UITraitCollection *collection);
NSDictionary *charon_merge_trait_extras(NSArray *collections);
void charon_apply_trait_extras(UITraitCollection *collection, NSDictionary *extras);
void charon_apply_screen_trait_extras(UITraitCollection *collection);
BOOL charon_trait_extras_contained(UITraitCollection *collection, UITraitCollection *wanted);
BOOL charon_trait_extras_equal(UITraitCollection *a, UITraitCollection *b);
NSUInteger charon_trait_extras_hash(UITraitCollection *collection);
void charon_add_trait_extras_description(UITraitCollection *collection, NSMutableArray *traits);
void charon_encode_trait_extras(UITraitCollection *collection, NSCoder *coder);
void charon_decode_trait_extras(UITraitCollection *collection, NSCoder *coder);

// The same dictionary read and written for a trait whose value is an object rather than a number, which is what
// the object traits of iOS 17 store: a typesetting language, and whether natural alignment resolves from the
// base writing direction. One dictionary holds every trait of a collection, so equality, hashing, coding, the
// merge of traitCollectionWithTraitsFromCollections: and the description all reach them without a store of
// their own. A value of nil removes the entry, as a number of -1 does.
id charon_trait_extra_object(UITraitCollection *collection, NSString *name);
void charon_set_trait_extra_object(UITraitCollection *collection, NSString *name, id value);

// The force touch capability's own storage, written from UITraitCollection+Traits17.m, which keeps a
// collection carrying a new value for that trait beside the file that reads it, and from UITraitCollection.m,
// which gives the screen's own traits the answer this device's hardware gives.
void charon_set_trait_force_touch(UITraitCollection *collection, UIForceTouchCapability capability);
void charon_set_screen_trait_force_touch(UITraitCollection *collection);

// The registrations an observable made, and the delivery that calls them back when the traits they named change.
// UITraitCollection.m's own trait change delivery asks for the call, so a handler fires on the paths the port
// really has: the release reporting a new status bar orientation, and an application setting a trait.
void charon_deliver_trait_registrations(NSArray *environments, NSArray *previous);
