#import "RevenantWeak.h"
#import <objc/runtime.h>

@interface RevenantWeakBox : NSObject {
@public
    __weak id _target;
}
@end

@implementation RevenantWeakBox
@end

id revenant_weak_get(id owner, const void *key)
{
    return ((RevenantWeakBox *)objc_getAssociatedObject(owner, key))->_target;
}

void revenant_weak_set(id owner, const void *key, id target)
{
    RevenantWeakBox *box = objc_getAssociatedObject(owner, key);
    if (!box && target) {
        box = [[RevenantWeakBox alloc] init];
        objc_setAssociatedObject(owner, key, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    box->_target = target;
}
