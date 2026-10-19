# AVSpeech: the utterance, its rate constants

Three classes of AVFAudio's speech API - `AVSpeechUtterance`, `AVSpeechSynthesisVoice`,
`AVSpeechSynthesizer` - and the constants and delegate protocol around them. Before iOS 7 there was no
public speech API on this release (6.1.3 exports none of the classes), so an application that strong-imports
them fails to load: dyld stops it at launch, which is why these are carried and not reported `absent`
(COORDINATION.md section 2).

This file covers the iOS 7-9 rows, and the two later properties of the synthesizer at its end (`outputChannels`,
iOS 10, and `usesApplicationAudioSession`, iOS 13). The other iOS 10+ and iOS 13+ rows (`attributedSpeechString`,
`speechUtteranceWithAttributedString:`, `prefersAssistiveTechnologySettings`, the personal-voice and SSML and marker
rows, `writeUtterance:`) are not carried here and the registry stays silent on them.

## AVSpeechUtterance (slice 1)

A data class: the text, a voice and four numbers, held as the caller set them. Nothing speaks yet; the engine
that does is the second half of this file.

Measured against the host's own class (`tests/backports/host/avf-speech/run.sh`, 88 checks, host and port in one
binary; a planted pitch-floor control goes red with 5 failures):

- **Defaults.** `+speechUtteranceWithString:` and `-initWithString:` give rate 0.5, pitchMultiplier 1,
  volume 1, both delays 0, voice nil. A plain `-init` gives every number 0 (measured: rate 0, pitch 0,
  volume 0). So the port overrides `initWithString:` and does not override `init`.
- **Setters.** Measured on the host with the inputs listed in checks.m:
  - `rate`: a negative value and NaN become 0. Nothing above is clamped (2 stays 2, infinity stays infinity).
  - `pitchMultiplier`: a value below 0.5 and NaN become 0.5. Nothing above is clamped (3 stays 3).
  - `volume`: a negative value and NaN become 0. Nothing above is clamped (2 stays 2).
  - `preUtteranceDelay` and `postUtteranceDelay`: no clamp at all (-1 stays -1).
- **The string is retained, not copied.** A caller who appends to its `NSMutableString` after building the
  utterance sees the change on both the host and the port.
- **Copy.** `-copy` gives a new object with every number, the same string and the same voice object.
- **Secure coding.** Both declare `NSSecureCoding`. The archive keys are `speechString`, `voice`, `rate`,
  `pitchMultiplier`, `volume`, `preUtteranceDelay`, `postUtteranceDelay` (read with `plutil -p` on the host's
  archive). Decoding without secure coding raises `NSInvalidUnarchiveOperationException` on the host, so the
  port's decode is the secure one.

### The divergence: speechString on a secure round trip

The host's encoder writes `speechString` as nil: in the host's archive the `speechString` key refers to object 0,
which is `$null`, though the utterance held `hello there`. A secure decode on the host therefore returns an
utterance whose `speechString` is nil. The port encodes the string and decodes it back. This is pinned in
checks.m as a divergence: if the host ever keeps the string, the check goes red and this file has to be read
again.

Why the port keeps the string rather than copying the host: the host is a macOS build, and nothing measured here
says iOS 7 writes nil. The port answers what an application expects from a round trip. If the device run shows
iOS 7 writing nil too, the port follows it and this entry changes.

### The voice on decode (narrowed in slice 2)

`-initWithCoder:` decodes `voice` as `NSObject` for now. Naming `AVSpeechSynthesisVoice` in this image would make it
import a class the 6.1.3 release does not carry, and that import fails at load. Slice 2 carries the class and
narrows the decode to it.

### Rate constants

`AVSpeechUtteranceDefaultSpeechRate` 0.5, `AVSpeechUtteranceMinimumSpeechRate` 0.0,
`AVSpeechUtteranceMaximumSpeechRate` 1.0, each `const float`. The host's own AVFAudio gives the same three values
(checks.m, the "constant" lines). The iOS 7.0 armv7 shared cache, read with `tools/corpus/cache-value.lua`, gives
bytes `0000003f` (0.5), `00000000` (0.0) and `0000803f` (1.0) for the three names, so the values are the release's,
not typed from the header. The cache tool's storage column reads 198530148 for the default rate and 4 for the other
two: noted, not explained, and the bytes agree with the host.

Read from the iOS 6.1.3 armv7 cache with the same tool, none of the three names exists: a dash for each (the
ledger, `AVFAudio.tsv`, rows 51-53, says so too). The same run read `AVSpeechSynthesizer` as absent from 6.1.3.

## AVSpeechSynthesisVoice (slice 2, measured; committed, the gate is not yet run on it)

The release's voice listing, read in the 6.1.3 guest (`tests/backports/host/avf-speech/voices/probe.m`, run with
`xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/avfspeechvoices`, pass):

- `VoiceServices.framework` is not loaded in a process by default: `NSClassFromString(@"VSSpeechSynthesizer")` is nil
  until the framework is dlopen'd. Loaded by path, the class answers.
- Class methods (names from `tools/corpus/objc-inventory.lua` on the 6.1.3 cache, found by the probe on the image):
  `+availableLanguageCodes` (36 codes), `+availableVoicesForLanguageCode:` (one `NSString` name per code),
  `+availableVoices` (the names for the current language: one, `Samantha`, on the guest's en-US), `+isSystemSpeaking`.
- The 36 voices: one per language code, named by the release: ar-SA Maged, cs-CZ Zuzana, da-DK Ida, de-DE Anna,
  el-GR Alexandros, en-AU Karen, en-GB Daniel, en-IE Moira, en-US Samantha, en-ZA Tessa, es-ES Monica, es-MX Paulina,
  fi-FI Mikko, fr-CA Julie, fr-FR Thomas, hi-IN Lekha, hu-HU Eszter, id-ID Damayanti, it-IT Silvia, ja-JP Kyoko,
  ko-KR Yuna, nl-BE Ellen, nl-NL Xander, no-NO Stine, pl-PL Agata, pt-BR Raquel, pt-PT Joana, ro-RO Simona,
  ru-RU Milena, sk-SK Laura, sv-SE Alva, th-TH Narisa, tr-TR Aylin, zh-CN Ting-Ting, zh-HK Sin-Ji, zh-TW Ya-Ling.
  The same set is on the image's file system: `VoiceServices.framework/TTSResources/<code>/clc_<code>_<voice>_cfg1.dat`
  (72 `clc_` files: a language pack and a voice per code).
- The listing carries no identifier, no quality and no gender. `quality` is Default for every voice on the image (the
  listing has no quality field), and the host's 180 voices are all quality 1, which is Default.
- The listing is in `voices/listing-6.1.3.txt` (the probe's own lines, pass on iPhone4,1 6.1.3 at time scale 10). The
  host's test stub (`tests/backports/host/avf-speech/voice-checks.m`) holds these 36 pairs, and run.sh checks it.

The host (macOS, measured in the run folder `.agent-work/runs/v-avspeech3/host/`, not committed) answers differently in
size and form: 180 `speechVoices` with identifiers such as `com.apple.voice.compact.en-US.Samantha`, and on this macOS
there is no VoiceServices framework (dlopen finds none, and `VSSpeechSynthesizer` is absent), so the port's listing is
empty on the host and the differential feeds the port the 6.1.3 listing through the stub. The rules the port follows,
measured on the host:

- `voiceWithLanguage:nil` is the current language's voice (Samantha). A bare language answers the current language's
  voice when the current language has that primary language (`en` is Samantha under en-US, Daniel under en-GB, Thomas
  for `fr` under fr-FR); otherwise the first voice of that language in the host's order (`en` is Karen under de-DE,
  `fr` is Amelie under en-US). `en-NZ` answers as `en`. `xx-YY` and the empty string answer nil.
- `voiceWithIdentifier:` answers nil for nil, an unknown identifier, `com.apple.voice.compact.en-US.Samantha ` (a
  trailing space), and `AVSpeechSynthesisVoiceIdentifierAlex` on this host. It ignores case: `...zh-HK.SinJi` answers
  Sinji, as `...zh-HK.Sinji` does.
- The identifier of a voice (measured with `host-match2.m`): where the host's voiceWithLanguage: with the release's code
  gives a voice with the release's name (accents and hyphens folded), the identifier is the host's. That is 22 of the
  36: the table in `AVSpeechSynthesisVoice7.m` (`RevenantHostIdentifiers`). Most are `com.apple.voice.super-compact.<code>.<name>`;
  en-US Samantha is `com.apple.voice.compact.` (the one `compact` on the host); the host's identifier drops the hyphen
  (`Ting-Ting` is `Tingting`, `Sin-Ji` is `Sinji`). The other 14 voices have no host voice under their name and language
  (ar-SA Maged, da-DK Ida, el-GR Alexandros, fr-CA Julie, fi-FI Mikko, hu-HU Eszter, it-IT Silvia, no-NO Stine,
  pl-PL Agata, pt-BR Raquel, ro-RO Simona, th-TH Narisa, tr-TR Aylin, zh-TW Ya-Ling). Their identifier is built by the
  host's pattern, `com.apple.voice.super-compact.<code>.<name>` with the hyphen dropped, and the host answers nil for
  each (checked by voice-checks.m). That built identifier is the one thing in this section not measured on a host
  voice: the coordinator's ruling of 2026-10-15 (the identifier is the host's; a voice the host lacks gets the host's
  pattern) is in `coordination/crutches.md`.
- `currentLanguageCode` is the first preferred language with its region filled from the locale. Measured with
  `-AppleLanguages "(xx)" -AppleLocale yy` (the locale override works only as command-line arguments): `fr-CA` with
  locale `en_GB` gives `fr-CA` (the language wins); `ja` with `ja_JP` gives `ja-JP`; `de` with `de_DE` gives `de-DE`;
  `(de)` with `en_US_POSIX` gives `de-DE`; `en-GB` gives `en-GB`. Two divergences from a plain tag: `zh-Hans-CN`
  gives `cmn-CN`, and `ar-SA` gives `ar-001` (the host's list has no `ar-SA`, and `sr-Latn-RS` also gives `ar-001`).
  The port resolves the tag against the release's own codes: exact match, else the first code of the same primary
  language, else the tag itself.

The port (`AVFoundation/AVSpeechSynthesisVoice7.m`) builds `speechVoices` from the listing (36 on 6.1.3), answers
`voiceWithLanguage:` and `voiceWithIdentifier:` over that list, and `currentLanguageCode` as above. The host
differential is `tests/backports/host/avf-speech/voice-checks.m` (run.sh, four locale variants, a planted identifier
that goes red). The pinned divergences: the release's ar-SA against the host's ar-001 (the answers of `ar`, `ar-SA`,
nil under ar-SA, and currentLanguageCode), and the host's cmn-CN against the release's zh-CN (zh-Hans-CN).

Not done in this slice: the gate on this tree, the release split, and the speaking
engine (`AVSpeechSynthesizer`). The 6.1.3 selectors of `VSSpeechSynthesizer` for speaking are in the inventory, and
the delegate protocol `VSSpeechSynthesizerDelegate` is there too (`speechSynthesizer:didFinishSpeaking:withError:`,
`speechSynthesizer:willSpeakRangeOfSpeechString:`, the start, pause and continue callbacks): the delegate order and
the no-voice behaviour are not measured yet.

## AVSpeechSynthesizer (slice 2, measured on the host and in the 6.1.3 guest)

The synthesizer is carried by driving the release's private `VSSpeechSynthesizer` (VoiceServices, loaded by path, found
by name as the voice class does). Its selectors, from `tools/corpus/objc-inventory.lua` on the 6.1.3 cache and the
guest's own `class_copyMethodList` dump (`tests/backports/host/avf-speech/speak/probe.m`, run 2 of v-avspeech4):

- used: `-startSpeakingString:` (id), `-stopSpeakingAtNextBoundary:` (int), `-pauseSpeakingAtNextBoundary:` (int),
  `-continueSpeaking`, `-isSpeaking` (BOOL), `-setRate:` / `-rate` (float), `-minimumRate`, `-maximumRate`,
  `-setPitch:` / `-pitch` (float), `-setVolume:` / `-volume` (float), `-setVoice:` / `-voice` (id), `-setDelegate:` (id).
- the synchronous forms `-stopSpeakingAtNextBoundary:synchronously:` and `-pauseSpeakingAtNextBoundary:synchronously:`
  (int, BOOL) exist; the port does not use them (see the order below).
- not used: `-startSpeakingString:withLanguageCode:`, `-startSpeakingString:toURL:...`, the attributed forms, `-setMaintainPersistentConnection:`,
  and the four `_handle...` selectors (the synthesizer's own callbacks to itself).
- Delegate calls the guest made (the image's protocol `VSSpeechSynthesizerDelegate` is not registered at run time, so
  `objc_getProtocol` finds nothing; the names are the ones the calls arrived with): `speechSynthesizerDidStartSpeaking:`,
  `speechSynthesizerDidPauseSpeaking:`, `speechSynthesizerDidContinueSpeaking:`, `speechSynthesizer:willSpeakRangeOfSpeechString:`,
  `speechSynthesizer:didFinishSpeaking:phonemesSpoken:withError:`. The three-argument `didFinishSpeaking:withError:` was never called.

Measured in the guest (run 2; times are guest seconds, and the guest runs slower than its clock under load, so only the
order and the flags are read from them):

- **No queue.** A `startSpeakingString:` while another string speaks replaces it silently: the first string gets no
  callback at all, its last word callback is its last event, and the second gets didStart again. The port queues itself
  and sends one string at a time.
- **Start.** `isSpeaking` is 1 at once after the start call; didStart follows later (about 2 s of guest time).
- **Finish.** didFinish with `finished=1`, error nil, and `isSpeaking=0` at the callback.
- **Stop at the immediate boundary (0), asynchronous.** The call returns nil. `isSpeaking` is still 1 at return, and
  didFinish with `finished=0`, error nil arrives about 0.14 s later (`isSpeaking=0` at the callback).
- **Stop at the word boundary (1), asynchronous.** The same callback, arriving at the next word boundary (about 1.1 s later).
- **Stop with a queued second string (VS holds one).** didFinish `finished=0` with error `VSErrorDomain -4005`. Nothing
  for the queued string: it is gone. Stop while idle returns an NSError `VSErrorDomain -4003` ("not currently speaking"),
  so VS's return is nil on success and an error otherwise; the port answers YES or NO from its own state.
- **Synchronous stop (0, synchronously:YES).** The callback comes before the call returns, and `isSpeaking` is 0 at return.
  The port does not use this form: the host returns first (speaking still 1) and then calls didCancel, so the port's
  asynchronous form gives the host's order.
- **Pause at the immediate boundary (0), asynchronous.** didPause about 0.2 s after the call. VS's own `isSpeaking` is 0 at
  the callback; the port keeps its own speaking flag (the host keeps speaking=1 while paused).
- **Pause, synchronous form.** didPause before the call returns (not used, as for stop).
- **Continue.** didContinue about 0.05 s after the call; the speech goes on and ends with didFinish `finished=1`.
- **Pause at the word boundary (1), asynchronous (run 3).** The call returns at once; the next word callbacks come
  (one, then another), and didPause follows one or two words after the call (`isSpeaking` 0 at the callback, as for
  the immediate form). The host pauses at the next word after the call (measured in the host section below). The two
  differ by a word or so; the guest timing is noisy, so the order (word callbacks, then didPause) is what is kept.
- **Voice.** `-setVoice:` takes the voice's name and stores it as given (`setVoice:NoSuchVoice` reads back
  `NoSuchVoice`, and speaking it still finishes with `finished=1`). With no voice set, the reading is `Samantha`
  under the guest's en-US. The port names the voice from `AVSpeechSynthesisVoice` (the current language's voice when
  the utterance has none).
- **Rate.** The image's range is `minimumRate` 0.5, default `rate` 1, `maximumRate` 4. Start to finish of "Hi there, this is
  the test." on the guest: rate 0.5 4.54 s, rate 1 4.20 s, rate 4 0.98 s. Only the maximum is clearly faster; 0.5 and 1 are
  within the guest's noise. The host's rate 0 / 0.5 / 1 gives 3.73 s / 2.21 s / 0.78 s for the same sentence.
- **Pitch and volume.** The image's defaults are pitch 0.5 and volume 0.8. `setVolume:0.3` and `setPitch:1.0` read back as 0.3 and 1 (run 3), so both are stored as given. Neither has a timing or a callback effect that
  either the host or the guest can show (no audio on the emulator; the host's timing does not move with them). The
  port's mapping for both is a rule, not a measurement (see the report).
- **Delays.** No selector of VSSpeechSynthesizer takes a delay. On the host, `preUtteranceDelay` and `postUtteranceDelay` of
  3 s move no callback and no finish time (`delays` runs in the run folder), so the port ignores them.

Host (macOS 27.0.1, `.agent-work/runs/v-avspeech4/host/`, not committed), the order the port matches:

- One short utterance: `speakUtterance:` returns with `speaking=0`; didStart follows about 0.02 s later with `speaking=1`;
  the willSpeakRange callbacks come; didFinish comes with `speaking` 1 or 0, and which one varies from run to run (not
  explained: measure.m and delay.m read both). The transcript in synth-checks.m leaves the flag
  out of didFinish for that reason; the other callbacks' flags are fixed on the host and are checked.
- Stop (immediate or word) on a speaking utterance: `stopSpeakingAtBoundary:` returns YES with `speaking=1`; then didCancel
  (immediate about 1 ms after, word at the next word boundary), with `speaking=0`. Stop while idle returns NO.
- Pause (immediate): returns YES with `paused=0`; didPause follows at once with `paused=1`. Pause at the word boundary
  does the same at the next word. Continue returns YES; didContinue follows with `paused=0`. Continue or pause when
  not in that state return NO.
- Queue: a second `speakUtterance:` while one speaks is queued, not raised; the second's didStart follows the first's
  didFinish, and `speaking` stays 1 across the change. The same object enqueued twice plays twice (no exception,
  although the header says it raises).
- Stop with a queue: one stop cancels every utterance, the current one and the queued ones, in queue order, with
  `speaking=0` at each didCancel; the queue is empty afterwards.
- Pause, then stop: didCancel for both, `paused=0` afterwards.
- Rate: 0 / 0.5 / 1 gives 3.73 s / 2.21 s / 0.78 s to didFinish; pitch 2 and volume 0 change no timing.

## AVSpeechSynthesizer's later properties (slice 3)

Two properties the header adds to the synthesizer after iOS 7 are carried as categories beside the class, one release per
file (`AVFoundation/AVSpeechSynthesizer10.m` for `outputChannels`, `AVFoundation/AVSpeechSynthesizer13.m` for
`usesApplicationAudioSession`), with the storage an associated object as `AVCaptureControls18.m` keeps its later
session property. Their rows are `registry/AVFoundation/ios10avspeech.json` and `ios13avspeech.json`. The class's own
file no longer names them (its `@dynamic` lines are gone), so a caller who sends either one reaches the implementation,
and the 6.1.3 gate sees them as built.

Host (macOS 27.0.1; the macOS SDK marks both properties `API_UNAVAILABLE(macos)`, so the harness sends them by selector
name; the probe is `.agent-work/runs/v-avspeech5/probe-host/`, not committed):

- **Declared.** `outputChannels` is `retain, nonatomic` and read-write (`T@"NSArray",&,N`); `usesApplicationAudioSession`
  is `BOOL`, `assign`, read-write (`TB,N`). Both selectors answer on the host's class.
- **outputChannels.** A fresh synthesizer answers nil (the header's default). `@[]` reads back as `@[]`, and nil reads
  back as nil. An array of the route's own `AVAudioSessionChannelDescription` objects (`AVAudioSession.sharedInstance`,
  `currentRoute`, the outputs' `channels`: two on this host's speaker route) reads back as the same array object.
- **usesApplicationAudioSession.** A fresh synthesizer answers NO, in six reads over three runs. `set NO` reads NO and
  `set YES` reads YES. **The header says the default is YES** (`AVSpeechSynthesis.h`, the property's comment), so the
  host contradicts its own header here, as the speechString divergence above does. The port answers NO, which is the
  host's answer. What an iOS device answers on a fresh synthesizer is not measured here.

Both are checked by the host differential: `tests/backports/host/avf-speech/synth-checks.m`, the scenario
`later properties`, compares each answer of the host's class with the port's. A planted control (`run.sh` with
`AVSPEECH_LATER_MUTANT=audio-session`, which makes the copy's default YES) goes red at that scenario, host 0 against port 1.

On 6.1.3 (the image's cache read with `tools/corpus/objc-inventory.lua`, 12549 rows; the class `VSSpeechSynthesizer` and
the protocol `VSSpeechSynthesizerDelegate`):

- **outputChannels: open.** No selector of `VSSpeechSynthesizer`, class or instance, has a name with `channel` or
  `session` in it (the instance selectors are the ones listed in the synthesizer section above, with the footprint and
  persistent-connection ones). So 6.1.3 has nothing to route speech to a channel with, and the port keeps the value
  and does not route it. Named open: the release has no per-channel routing the port could call.
- **usesApplicationAudioSession: open.** The release has no such flag, and whether its speech uses the application's
  session is not measured. The guest probe (`speak/probe.m`) does not read `AVAudioSession`'s category or its activity,
  so it cannot show it, and the emulator has no audio to show it another way. The port's answer is the value the caller
  set, which nothing on 6.1.3 reads. Named open.
