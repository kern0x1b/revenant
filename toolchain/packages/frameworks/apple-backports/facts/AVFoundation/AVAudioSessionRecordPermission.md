# The record permission of the audio session, iOS 7.0 and 8.0

iOS 7.0 added `-[AVAudioSession requestRecordPermission:]`, which asks the user whether the application may record, and iOS 8.0 added
`-recordPermission`, the answer without asking: undetermined, denied or granted.

Source: the header of iOS 16.4; `tccd` of the root file system of iOS 6.1.3, which lists kTCCServiceAddressBook, Calendar, Reminders, Photos, Twitter, Facebook, SinaWeibo and BluetoothPeripheral and no microphone, and that of iOS 9.3.6, which lists kTCCServiceMicrophone.

## Where iOS 6 differs

The permission is new to iOS 7: the privacy service of iOS 6 has no entry for the microphone, and recording is never refused for want of it. So the permission is
granted: `-recordPermission` answers `AVAudioSessionRecordPermissionGranted` and `-requestRecordPermission:` calls its handler once, off the main thread, with YES, as the
release does with its own answer. The camera is separate, and is answered in `+[AVCaptureDevice authorizationStatusForMediaType:]`.
