# SFSpeechRecognitionRequest and its subclasses, SFTranscription, SFTranscriptionSegment, SFSpeechRecognitionResult, iOS 10

The Speech classes of iOS 10 that carry data: the three request classes, the result, the transcription and the segment.
The release (6.1.3) has no Speech framework, so an application that strong-imports one of these classes does not load.
This library carries the classes. No recognizer runs on this device: the recognizer and the task are not carried by this
library, and nothing here captures audio, opens the microphone, or sends audio anywhere.

Sources: the Speech headers of the macOS 27.0 SDK (`SFSpeechRecognitionRequest.h`, `SFSpeechURLRecognitionRequest` and
`SFSpeechAudioBufferRecognitionRequest` in the same header, `SFSpeechRecognitionResult.h`, `SFTranscription.h`,
`SFTranscriptionSegment.h`) for every declaration, availability and property. The defaults are measured on the host, a
Mac, as a bare command-line tool (no bundle, no usage description), against its own Speech framework. The measurement is
`tests/backports/host/speech-data/`.

## What is measured on the host

| question | host answer |
| --- | --- |
| `-[SFSpeechURLRecognitionRequest initWithURL:]`, then `URL` | the URL as given |
| URL request `taskHint` | 0 (unspecified) |
| URL request `shouldReportPartialResults` | YES |
| URL request `contextualStrings` | an empty array |
| URL request `interactionIdentifier` | nil |
| fresh `SFSpeechAudioBufferRecognitionRequest` `taskHint`, `shouldReportPartialResults`, `contextualStrings` | 0, YES, an empty array |
| fresh buffer request `nativeAudioFormat` | 16000 Hz, 1 channel, Int16 common format, interleaved |
| fresh `SFTranscription` `formattedString`, `segments` | nil, nil |
| secure archive of a fresh `SFTranscription` | succeeds, no error |
| secure unarchive of that archive | succeeds, class SFTranscription, formattedString nil |
| fresh `SFTranscriptionSegment` `substring`, `alternativeSubstrings` | nil, nil |
| fresh segment `substringRange`, `timestamp`, `duration`, `confidence` | 0/0, 0, 0, 0 |
| `-copy` of a fresh segment | succeeds, the same values |
| fresh `SFSpeechRecognitionResult` `isFinal` | NO |
| fresh `SFSpeechRecognitionResult` `transcriptions` | raises NSInvalidArgumentException ("object cannot be nil"), the process aborts |

The differential compares every case except the last one, which the host cannot answer; that case is named in the run.

## What the port answers

- The requests keep the values they are given. A fresh request has the host defaults above. The append and end-of-audio
  methods are accepted and do nothing: the audio is not kept, because nothing on this release reads it.
- `nativeAudioFormat` is an `AVAudioFormat` built as the host answers, 16 kHz, one channel, interleaved Int16. It is
  built from the AVFoundation port, which this library links.
- A transcription and a segment are the values an application gives them, which on this device is always the fresh
  defaults. Both support secure coding and copy, and their archive keys are the property names.
- A result is not final and has an empty array of transcriptions and no best transcription.

## Where the port differs from the host

- **A fresh result's `transcriptions`.** The host raises an exception, and the application dies. The port returns an
  empty array, because an API must never crash the caller. This is the one measured answer the port does not copy. The
  differential cannot compare it (case 7), and the host side is named as a crash, not as agreement.

## Not carried in this library

- The iOS 13 and later properties of these classes: `requiresOnDeviceRecognition`, `addsPunctuation`,
  `customizedLanguageModel`, `speechRecognitionMetadata`, `speakingRate`, `averagePauseDuration`, `voiceAnalytics`.
  They are declared with a later availability in the SDK header and are not on any iOS 10 path.
- The classes of iOS 13 and later: `SFSpeechRecognitionMetadata`, `SFSpeechLanguageModel`,
  `SFSpeechLanguageModelConfiguration`, `SFVoiceAnalytics`, `SFAcousticFeature`.
- `SFSpeechRecognizer`, `SFSpeechRecognitionTask` and their delegates: the recognizer and the task are a later slice of
  this library, not measured here.
- `SFSpeechErrorDomain`, an iOS 17 constant. It is not a source of this slice: the build exports it from the committed
  constants record `spec/Speech/constants.tsv`, and the release-split check names its first release as 18.0. Its
  registry entry and its facts belong to the constants slice, not to these classes.

## Not measured

- The secure coding round trip of a populated transcription or segment: the header gives no setter for their values, so
  the host can only produce fresh instances. The port's round trip for populated values is reasoned from the code, not
  measured.
- `nativeAudioFormat` on a request that has had audio appended: the host was asked for a fresh request only.
