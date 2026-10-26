#import "../Foundation/check.h"
#import <Intents/Intents.h>
#import <objc/runtime.h>

static Class revenant_subclass(Class base, const char *name)
{
    Class subclass = objc_allocateClassPair(base, name, 0);
    objc_registerClassPair(subclass);
    return subclass;
}

static NSInteger revenant_status(id result)
{
    return [[result valueForKey:@"resolutionStatus"] integerValue];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Class objectClass = NSClassFromString(@"INObjectRevenant");
    Class resultClass = NSClassFromString(@"INObjectResolutionResultRevenant");
    revenant_check((resultClass != Nil) != revenant_negative, "INObjectResolutionResult implementation is present", NSStringFromClass(resultClass));
    if (!objectClass || !resultClass)
        return revenant_finish();

    INObject *hostAda = [[INObject alloc] initWithIdentifier:@"ada" displayString:@"Ada Lovelace"];
    INObject *hostGrace = [[INObject alloc] initWithIdentifier:@"grace" displayString:@"Grace Hopper"];
    Class hostSubclass = revenant_subclass([INObjectResolutionResult class], "RevenantHostResultSubclass");
    id hostSubclassObject = hostSubclass;
    id hostSuccess = [hostSubclassObject successWithResolvedObject:hostAda];
    revenant_check([hostSuccess isKindOfClass:hostSubclass], "host success keeps the receiver's subclass", NSStringFromClass([hostSuccess class]));
    id hostDisambiguation = [hostSubclassObject disambiguationWithObjectsToDisambiguate:@[hostAda, hostGrace]];
    revenant_check([hostDisambiguation isKindOfClass:hostSubclass], "host disambiguation keeps the receiver's subclass", NSStringFromClass([hostDisambiguation class]));
    id hostConfirmation = [hostSubclassObject confirmationRequiredWithObjectToConfirm:hostAda];
    revenant_check([hostConfirmation isKindOfClass:hostSubclass], "host confirmation keeps the receiver's subclass", NSStringFromClass([hostConfirmation class]));

    id backportAda = [[objectClass alloc] initWithIdentifier:@"ada" displayString:@"Ada Lovelace"];
    id backportGrace = [[objectClass alloc] initWithIdentifier:@"grace" displayString:@"Grace Hopper"];
    id baseSuccess = [resultClass successWithResolvedObject:backportAda];
    revenant_check([baseSuccess class] == resultClass, "base success is an instance of the base class", NSStringFromClass([baseSuccess class]));
    revenant_check(revenant_status(baseSuccess) == 3, "base success has the success status", [NSString stringWithFormat:@"%ld", (long)revenant_status(baseSuccess)]);

    Class backportSubclass = revenant_subclass(resultClass, "RevenantBackportResultSubclass");
    id backportSubclassObject = backportSubclass;

    id success = [backportSubclassObject successWithResolvedObject:backportAda];
    revenant_check([success class] == backportSubclass, "backport success returns the receiver's subclass", NSStringFromClass([success class]));
    revenant_check(revenant_status(success) == 3, "backport success has the success status", [NSString stringWithFormat:@"%ld", (long)revenant_status(success)]);
    revenant_check([[success valueForKey:@"resolvedValue"] isEqual:backportAda], "backport success keeps the resolved object", NSStringFromClass([[success valueForKey:@"resolvedValue"] class]));

    id disambiguation = [backportSubclassObject disambiguationWithObjectsToDisambiguate:@[backportAda, backportGrace]];
    revenant_check([disambiguation class] == backportSubclass, "backport disambiguation returns the receiver's subclass", NSStringFromClass([disambiguation class]));
    revenant_check(revenant_status(disambiguation) == 4, "backport disambiguation has the disambiguation status", [NSString stringWithFormat:@"%ld", (long)revenant_status(disambiguation)]);
    revenant_check([[disambiguation valueForKey:@"valuesToDisambiguate"] count] == 2, "backport disambiguation keeps both choices", [NSString stringWithFormat:@"%@", [disambiguation valueForKey:@"valuesToDisambiguate"]]);

    id confirmation = [backportSubclassObject confirmationRequiredWithObjectToConfirm:backportGrace];
    revenant_check([confirmation class] == backportSubclass, "backport confirmation returns the receiver's subclass", NSStringFromClass([confirmation class]));
    revenant_check(revenant_status(confirmation) == 5, "backport confirmation has the confirmation status", [NSString stringWithFormat:@"%ld", (long)revenant_status(confirmation)]);
    revenant_check([[confirmation valueForKey:@"valueToConfirm"] isEqual:backportGrace], "backport confirmation keeps the object to confirm", NSStringFromClass([[confirmation valueForKey:@"valueToConfirm"] class]));

    return revenant_finish();
}
