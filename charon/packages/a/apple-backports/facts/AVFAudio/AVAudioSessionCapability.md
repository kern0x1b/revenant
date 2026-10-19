# AVAudioSessionCapability and AVAudioSessionPortExtensionBluetoothMicrophone

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config), in `AVAudioSessionCapability26.m` -
one object file, one release, both classes being iOS 26.

Both classes describe a facility of the audio route, and the only question this port can answer
honestly is whether the release has one. A capability answers its two properties as a device without
the facility does: `isSupported` `NO` and `isEnabled` `NO`. That is the shape the header gives, and
the shape a program that checks a facility before using it already handles - it asks, and it does not
use what is not there.

**What the release holds, read and not assumed.** iOS 6.1.3's armv7 shared cache exports no
AVAudioSession port-extension API at all, and its route is an `AVAudioSessionRouteDescription` of port
types it names itself: the built-in microphone, the receiver, the headphones. A Bluetooth microphone
of the kind these two classes describe - one that captures far-field audio, or one that records at
high quality over a Bluetooth link - is an accessory this release's route has no way to name, so
neither capability is supported.

`AVAudioSessionPortExtensionBluetoothMicrophone` therefore holds two real `AVAudioSessionCapability`
objects, one per capability, each answering `isSupported` `NO`; they are not `nil`, because the
header declares both properties `nonnull` and an application that sends `isSupported` to `nil` would
get a crash instead of an answer.
