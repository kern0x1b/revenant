#import "CharonSCN.h"

@implementation NSValue (SceneKitAdditions)

+ (NSValue *)valueWithSCNVector3:(SCNVector3)v
{
    return [NSValue valueWithBytes:&v objCType:@encode(SCNVector3)];
}

+ (NSValue *)valueWithSCNVector4:(SCNVector4)v
{
    return [NSValue valueWithBytes:&v objCType:@encode(SCNVector4)];
}

+ (NSValue *)valueWithSCNMatrix4:(SCNMatrix4)v
{
    return [NSValue valueWithBytes:&v objCType:@encode(SCNMatrix4)];
}

- (SCNVector3)SCNVector3Value
{
    SCNVector3 v = SCNVector3Make(0, 0, 0);
    if (strcmp(self.objCType, @encode(SCNVector3)) == 0) {
        [self getValue:&v];
    }
    return v;
}

- (SCNVector4)SCNVector4Value
{
    SCNVector4 v = SCNVector4Make(0, 0, 0, 0);
    if (strcmp(self.objCType, @encode(SCNVector4)) == 0) {
        [self getValue:&v];
    }
    return v;
}

- (SCNMatrix4)SCNMatrix4Value
{
    if (strcmp(self.objCType, @encode(SCNMatrix4)) == 0) {
        SCNMatrix4 v;
        [self getValue:&v];
        return v;
    }
    return SCNMatrix4Identity;
}

@end
