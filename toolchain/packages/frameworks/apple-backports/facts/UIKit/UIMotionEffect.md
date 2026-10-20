# UIMotionEffect, UIInterpolatingMotionEffect, UIMotionEffectGroup

Source: UIKit of iOS 9.3.5, armv7 (`dyld_shared_cache_armv7`), read with `xmake firmware extract`
and the method addresses of `objc.code_map`.

## Archiving

`-[UIMotionEffect encodeWithCoder:]` (0x25808bf9) writes one key, `preferredMotionAnalyzerSettingsDictionary`,
whose value is `-[settings archiveDictionary]` of the effect's motion analyzer settings; `initWithCoder:`
(0x25808b2d) calls `init` on super, decodes that key and, when it is there, rebuilds the settings with
`+settingsFromArchiveDictionary:` and `-_setPreferredMotionAnalyzerSettings:`. The settings are a private
class of the motion engine, so the backport neither writes nor reads that key: iOS 6 has no such engine.

`-[UIInterpolatingMotionEffect encodeWithCoder:]` (0x25808e35) and `initWithCoder:` (0x25808f75) use the
ivar names as keys, and the pairs are symmetric:

| key | encoded with | decoded with |
|---|---|---|
| `_keyPath` | `encodeObject:forKey:` | `decodeObjectForKey:` |
| `_minimumRelativeValue` | `CA_encodeObject:forKey:conditional:` | `CA_decodeObjectForKey:` |
| `_maximumRelativeValue` | `CA_encodeObject:forKey:conditional:` | `CA_decodeObjectForKey:` |
| `_type` | `encodeInteger:forKey:` | `decodeIntegerForKey:` |
| `_horizontalAccelerationBoostFactor` | `encodeObject:forKey:` | `decodeDoubleForKey:` |
| `_verticalAccelerationBoostFactor` | `encodeObject:forKey:` | `decodeDoubleForKey:` |

`CA_encodeObject:forKey:conditional:` is QuartzCore's addition to NSCoder; for the plain numbers a relative
value holds it writes what `encodeObject:forKey:` writes, which is what the backport uses.

`-[UIMotionEffectGroup encodeWithCoder:]` (0x258094a1) writes `_motionEffects` with `encodeObject:forKey:`,
and `initWithCoder:` (0x258094d1) reads it with `decodeObjectForKey:` after `[super initWithCoder:]`.

The two acceleration boost factors are private API of the release, so the backport does not carry them; an
archive it writes is read by iOS 9's own class, which leaves them at their defaults.
