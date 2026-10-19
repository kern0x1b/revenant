// probe.m - the fixture tests/backports/host/renames/run.sh renames. It holds both kinds of name the differential
// has to move apart from the framework's: a category on a host class, whose selectors can collide with the host's
// and must be prefixed whole, and the port's own class, whose selectors cannot collide once the class is renamed.
// The selectors are chosen to be the ones a -D cannot rename: setObject:forTrait: is three identifiers, and
// `object`, `target` and `value` are words the SDK's own headers use as plain identifiers (os/object.h declares
// @interface OS_object, and every Objective-C source that includes dispatch gets it). ASCII only: this file goes
// through prefix_selectors.py, which renames by byte offset.
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

// a category on the port's own class: the class is renamed, so the members of this one are already apart
// from the host's class of the same name and must keep their own spelling
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
