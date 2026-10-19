#import <Foundation/Foundation.h>

NSString *charon_renames_probe_value(NSString *name);

@interface CharonRenamesProbe : NSObject
- (id)setObject:(id)object forTrait:(id)trait;
- (id)object;
- (id)target;
- (id)value;
@end

@implementation CharonRenamesProbe

- (id)setObject:(id)object forTrait:(id)trait
{
    return @([charon_renames_probe_value([object description]) hasPrefix:trait]);
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

@interface CharonRenamesProbe (CharonRenamesProbeExtras)
- (id)extra;
@end

@implementation CharonRenamesProbe (CharonRenamesProbeExtras)

- (id)extra
{
    return self;
}

@end

@interface NSString (CharonRenamesProbeCategory)
- (NSString *)probeOf:(id)object forKey:(id)key;
@end

@implementation NSString (CharonRenamesProbeCategory)

- (NSString *)probeOf:(id)object forKey:(id)key
{
    return [NSString stringWithFormat:@"%@/%@/%@", self, object, key];
}

@end

NSString *charon_renames_probe_value(NSString *name)
{
    return [name uppercaseString];
}
