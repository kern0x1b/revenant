#import <Foundation/Foundation.h>

NSString *revenant_renames_probe_value(NSString *name);

@interface RevenantRenamesProbe : NSObject
- (id)setObject:(id)object forTrait:(id)trait;
- (id)object;
- (id)target;
- (id)value;
@end

@implementation RevenantRenamesProbe

- (id)setObject:(id)object forTrait:(id)trait
{
    return @([revenant_renames_probe_value([object description]) hasPrefix:trait]);
}

- (id)object
{
    return self;
}

- (id)target
{
    return self;
}

- (id)value
{
    return self;
}

@end

@interface RevenantRenamesProbe (RevenantRenamesProbeExtras)
- (id)extra;
@end

@implementation RevenantRenamesProbe (RevenantRenamesProbeExtras)

- (id)extra
{
    return self;
}

@end

@interface NSString (RevenantRenamesProbeCategory)
- (NSString *)probeOf:(id)object forKey:(id)key;
@end

@implementation NSString (RevenantRenamesProbeCategory)

- (NSString *)probeOf:(id)object forKey:(id)key
{
    return [NSString stringWithFormat:@"%@/%@/%@", self, object, key];
}

@end

NSString *revenant_renames_probe_value(NSString *name)
{
    return [name uppercaseString];
}
