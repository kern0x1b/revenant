# Names of AVFoundation that iOS 7 to 9 added

iOS 7.0 added `AVAudioSessionMediaServicesWereLostNotification`, `AVAudioSessionModeVideoChat`, `AVAudioSessionPortBluetoothLE`,
`AVCaptureSessionPresetInputPriority` and the strings that name the machine readable codes a metadata output finds
(`AVMetadataObjectTypeQRCode` and the nine other one-dimensional and two-dimensional codes); iOS 8.0 added the notification of a change of the audio
engine's configuration, the notification and key of the hint to silence secondary audio, and three more code types; iOS 9.0 added the 4K preset.

Source: AVFoundation and AVFAudio of the arm64 shared cache of iOS 12.0, where each constant is a string and its text was read; an iPad 2 running
6.1.3 and the iOS 6.0 emulator, asked with `dlsym`, which export none of the names.

## What it is

Constant strings. An application names them to ask the audio session for a mode or to observe its notifications, to choose a preset for a capture session,
and to ask a metadata output for the codes it finds.

## Where iOS 6 differs

iOS 6 exports none of them, and an application that names one is not loaded at all. They are carried with the text above, so that it loads. Nothing behind
them exists: the audio session of iOS 6 posts none of the notifications, a capture session does not accept the input priority or the 4K preset
(`canSetSessionPreset:` answers NO), and a metadata output of iOS 6 finds faces only, so its available types do not list any of the codes and it never delivers a
machine readable code object. An application that asks the output for its available types before it sets them, or a session for `canSetSessionPreset:`
before it sets a preset, gets the answer of the release.
