# AVMusicEvent, AVMusicUserEvent and AVParameterEvent

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config), all three in one object file
`AVMusicEvent16.m` because all three arrived in iOS 16 and an object is carried from one release on
(`modules/apple/backports.lua`, `minimums()`).

In the SDK 26.2 header `AVMusicEvent` is an **empty** base class:

```objc
@interface AVMusicEvent : NSObject
@end
```

whose whole job is to be the root of the hierarchy a track enumerates. So there is nothing to
translate here: a parameter event is its id, scope, element and value, and a user event is the data
the application's own callback is handed. Both are the value objects the header describes, kept and
read back.

**`AVMusicUserEvent.sizeInBytes`** is the length of the data `-initWithData:` was given. The 26.2
header gives that class only those two members, so the port adds no accessor of its own - the data
travels through the track's user callback, which reads it by its own path.

**Where the track takes these events** is the sequencer's business, not this file's: `MusicSequence`'s
own C API (`MusicSequenceNewTrack`, `MusicSequenceSetUserCallback`, `MusicSequenceGetInfoDictionary`,
`MusicSequenceFileCreateData` and the rest) is exported in full by AudioToolbox on iOS 6.1.3, so the
sequencer and the MIDI events that go with it are built over the release's own rather than over a
translation of it. That family is a later delivery; see the handoff.
