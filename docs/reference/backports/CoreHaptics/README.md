# CoreHaptics on iOS 6

CoreHaptics is an iOS 13 framework. The backport covers the haptic surface Telegram 13.0.0 uses in
`Display/Source/HapticFeedback.swift` (`ContinuousHaptic`): the event parameter, the event, the pattern, the engine
and the pattern player. It maps haptic events to the phone's vibration motor. The motor has one strength and no
sharpness, so only the timing of a haptic is mapped.

## What the iPhone 4S has

The iOS 6.1.3 armv7 shared cache exports the private vibration API:

| Symbol | Library |
|---|---|
| `FigVibratorIsVibratorAvailable`, `FigVibratorGetMinMaxDurations`, `FigVibratorStop`, `FigVibratorInitialize`, `FigVibratorStartOneShot`, `FigVibratorStartRepeating`, `FigVibratorPlayVibration`, `FigVibratorPlayVibrationWithDictionary` | CoreMedia |
| `kFigVibratorParamKey_Intensity`, `kFigVibratorParamKey_OnDuration`, `kFigVibratorParamKey_OffDuration`, `kFigVibratorParamKey_Period`, `kFigVibratorParamKey_TotalDuration`, `kFigVibratorParamKey_VibePattern` | CoreMedia |
| `AudioServicesPlaySystemSoundWithVibration` | AudioToolbox |

`AudioServicesPlaySystemSound` and `kSystemSoundID_Vibrate` are public AudioToolbox API and are there on iOS 6.

`frameworks/Backports/tests/device_probe/corehaptics_main.m` ran on the claimed iPhone 4S with iOS 6.1.3 and
reported:

```
vibrator_available=1
durations_result=-5555 min=0/1 max=0/1
fig_stop_symbol=yes
play_with_vibration_symbol=yes
```

So the phone has a vibrator, and `FigVibratorGetMinMaxDurations` answers `-5555`: the FigVibrator of CoreMedia is
not initialized in a plain process, and the minimum and maximum pulse lengths are not readable that way. The
backport therefore does not use that call.

The probe also measured the mechanical effect of a pulse. The accelerometer of the phone, sampled at 100 Hz, shows
the same deviation from gravity (0.005 g to 0.008 g) with and without a vibration, and with a sound played through
the speaker, so the phone's case does not move enough to be seen where it lies. The microphone hears the room and a
sound played through the speaker at the same level, but not the motor. The system log records nothing for a
vibration. **No pulse length is measured**: the duration of a vibration on this phone is not established by these
measurements, and the backport does not claim one.

## The mapping

| Haptic | What the phone is asked to do |
|---|---|
| A transient event | one vibration of the event's length, or of 40 ms when the event has none |
| A continuous event | one vibration of the event's length |
| An event's intensity | below 0.5 nothing is played, above it the vibration is played at the intensity asked for |
| Sharpness | not expressed at all; the motor has no sharpness |
| A dynamic intensity control | scales the intensity of the events at or after its time |
| `supportsHaptics` | whether the phone has a vibrator (`FigVibratorIsVibratorAvailable`) |
| `supportsAudio` | NO: the phone plays no audio with a haptic |

The vibration itself goes through `AudioServicesPlaySystemSoundWithVibration` (AudioToolbox, `dlsym`) with the
sound ID `kSystemSoundID_Vibrate`, a `VibePattern` array of millisecond durations that alternate on and off and
start with on, and an `Intensity` value. This is the same call the UIKit feedback generators use
([the generators](../UIKit/FeedbackGenerators.md)).

The threshold of 0.5 is a choice and not a measurement: the motor has one strength, so a haptic the phone cannot
play weakly is not played at all rather than played at full strength. Whether iOS 6 uses the `Intensity` key is not
measured, so the intensity is passed to the system as it is.

## The engine

`CHHapticEngine` is the phone's vibration motor. `initAndReturnError:` fails with `CHHapticErrorCodeNotSupported`
on a device without a vibrator, as CoreHaptics does without haptics hardware. `startAndReturnError:` starts it,
`stopWithCompletionHandler:` stops the players and the vibration, and `notifyWhenPlayersFinished:` runs the handler
when the last player has finished. `currentTime` is the system uptime.

The player plays the events of its pattern at their times, with `dispatch_after` on a queue of its own, and finishes
when the pattern's length has passed. `stopAtTime:error:` and `cancelAndReturnError:` stop the player, and with it
the motor: the phone has one motor, so stopping one player stops the vibration of another.

## What is not there

- The advanced player (`createAdvancedPlayerWithPattern:error:`) and the parameter curves
  (`initWithEvents:parameterCurves:error:`) fail with `CHHapticErrorCodeOperationNotPermitted`: a motor has no
  playback rate and no curve.
- The audio resources (`registerAudioResource:options:error:`, `unregisterAudioResource:error:`,
  `initWithAudioResourceID:...`) fail with the same code: the phone plays no audio with a haptic.
- A pattern that carries a parameter curve is refused by `initWithDictionary:error:` for the same reason. The rest of
  the AHAP dictionary format is read, and `exportDictionaryAndReturnError:` writes it.

## Checks

The host test compares the backport with CoreHaptics on macOS, where the framework exists: the constants, the
property round trips of the event parameter and the event, the pattern length of six cases, the length of a pattern
of two events, and the exported pattern dictionary. The device probe ran the whole surface on the phone: the engine
is created, started, the pattern of a 0.5 second continuous event has that length, the player is created and starts
and stops, and the engine stops. No panic report was added by these runs.
