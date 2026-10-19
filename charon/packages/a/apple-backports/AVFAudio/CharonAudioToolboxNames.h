// The two AudioComponent notification names the release's own AudioToolbox has from iOS 7 and iOS 9. Their values are
// the strings the SDK's AudioComponent.h names them by. A host test (tests/backports/host/audiotoolbox-constants) includes
// this header and checks each value against the host's own symbol, so the port's definition and the host's are the same.
#define CharonAudioComponentRegistrationsChangedName @"com.apple.coreaudio.AudioComponentRegistrationsChanged"
#define CharonAudioComponentInstanceInvalidatedName @"com.apple.coreaudio.AudioComponentInstanceInvalidated"
