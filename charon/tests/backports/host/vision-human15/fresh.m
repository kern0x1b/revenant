/* fresh.m - what a VNHumanObservation made with -init answers, on the host and in the port, property by property. The
 * UUID is left out: it is a new one on each call. Both sides compile this file; the host's Vision is the framework and the
 * port's is its sources. */
#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <objc/runtime.h>

int main(void)
{
    VNHumanObservation *human = [[VNHumanObservation alloc] init];
    if (!human) {
        printf("init answers nil\n");
        return 1;
    }
    printf("class %s\n", object_getClassName(human));
    printf("upperBodyOnly %d\n", (int)human.upperBodyOnly);
    printf("boundingBox %s\n", NSStringFromRect(NSRectFromCGRect(human.boundingBox)).UTF8String);
    printf("confidence %f\n", human.confidence);
    printf("respondsToInit %d respondsToNew %d\n", [VNHumanObservation instancesRespondToSelector:@selector(init)],
           [VNHumanObservation respondsToSelector:@selector(new)]);
    return 0;
}
