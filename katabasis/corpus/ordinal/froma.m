#import <objc/runtime.h>
#import "shared.h"
@interface FromA : Shared @end
@implementation FromA @end
int main(void) { return objc_getClass("FromA") != 0; }
