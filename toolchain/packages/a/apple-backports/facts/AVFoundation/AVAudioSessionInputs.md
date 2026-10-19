# The inputs of the audio session, iOS 7.0

iOS 7.0 added `-[AVAudioSession availableInputs]`, the inputs the session could record from, `preferredInput` and `-setPreferredInput:error:`, which ask the
session to record from one of them.

Source: the header of iOS 16.4; `AVAudioSession.currentRoute` of iOS 6.0, which lists the inputs in use (the iOS 6.0 emulator lists the built-in microphone for a session of the record category).

## Where iOS 6 differs

iOS 6 knows the inputs of the route in use, and has no way to name another. `availableInputs` is the inputs of the current route, so it lists the built-in microphone, or the microphone of a headset
that is plugged in, and not the inputs the route could have taken. `-setPreferredInput:error:` succeeds for nil, which clears the preference, and for an input that is
already an input of the current route, which is the one in use, and `preferredInput` answers that input for as long as it stays in the route. For any other input it answers NO, with
an error of the domain `NSOSStatusErrorDomain` and the code `AVAudioSessionErrorCodeResourceNotAvailable` and a description that says iOS 6 cannot switch to it: the input is not switched, and YES is not made up.
The code is a choice among the header's codes for a resource that is not there; the release has no answer to compare it with.
