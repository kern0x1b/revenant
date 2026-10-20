#import <objc/runtime.h>
#import "shared.h"
@interface SysSub : Shared @end
@implementation SysSub @end
int main(void) { return objc_getClass("SysSub") != 0; }
