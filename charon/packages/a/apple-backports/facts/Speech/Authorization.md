# The speech recognizer before a permission is requested: what the host answers

Measured by `tests/backports/host/speech-authorization/speech.m`, whose answers are in `expected.txt` and checked by
`run.sh`. The probe reads the state and never requests a permission, so no prompt is shown.

On this host (a Mac):

- `+[SFSpeechRecognizer authorizationStatus]` is 0, not determined.
- The en-US recognizer is non-nil, `isAvailable` is 1, `supportsOnDeviceRecognition` is 1, and its locale is en-US.
- Its delegate is nil and its queue is set.

## What is not measured

The coordinator's rows assume the authorization flow answers as a device without on-device recognition (a 4S-class
answer): `supportsOnDeviceRecognition` 0, and recognition by the network. This host is not such a device, and no
such device is available here, so that answer cannot be measured. The port's row for the on-device answer therefore
has no measured value for that device class, and the rows that depend on it stay owed.

The recognition itself is not measured either: no open engine (pocketsphinx or whisper.cpp) is built into the port,
and the rows for the task state, its error, and its finish and cancel have no engine behind them. The 10 Speech rows
stay owed.
