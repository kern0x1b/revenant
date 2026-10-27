# Vision text recognition on iOS 6

`VNRecognizeTextRequest` is implemented in the Vision backport with Tesseract 5.5.3 and Leptonica 1.85.0, on the models that Tesseract's `tessdata_fast` and `tessdata_best` repositories publish. This page says what it answers, where the answers differ from Apple's Vision, how each difference was measured, and what is still open.

## What it answers

The request reads the languages from `recognitionLanguages`, at the level from `recognitionLevel` and the revision from `revision`. The revision is the one macOS Vision reports; the backport answers the same identifiers as macOS Vision revision 1, 2 and 3 for the accurate level, and the six languages of the fast level for revision 3.

`supportedRecognitionLanguagesForTextRecognitionLevel:revision:error:` answers only the languages whose model is installed in `/usr/share/revenant/tessdata/{fast,best}`. Apple's list is the list of languages the framework supports; the backport's list is the list of languages this device can read. With no model installed the list is empty. Asking for a language that is not installed at its level fails with an error; it does not fall back to another language.

Tesseract's language code for each identifier is:

| Vision identifiers | Tesseract model | Note |
| --- | --- | --- |
| `en-US`, `fr-FR`, `it-IT`, `de-DE`, `es-ES`, `pt-BR` | `eng`, `fra`, `ita`, `deu`, `spa`, `por` | the six fast-level languages |
| `zh-Hans`, `yue-Hans` | `chi_sim` | `yue-Hans` is the closest model, not Cantonese |
| `zh-Hant`, `yue-Hant` | `chi_tra` | `yue-Hant` is the closest model, not Cantonese |
| `ar-SA`, `ars-SA` | `ara` | `ars-SA` is the closest model, not Najdi Arabic |
| `no-NO`, `nn-NO`, `nb-NO` | `nor` | one model serves the three |
| `vi-VT` | `vie` | `vi-VT` is Apple's identifier for Vietnamese |
| the other identifiers of revision 3 | the same ISO 639-2 code | `ko-KR`, `ja-JP`, `ru-RU`, `uk-UA`, `th-TH`, `tr-TR`, `id-ID`, `cs-CZ`, `da-DK`, `nl-NL`, `ms-MY`, `pl-PL`, `ro-RO`, `sv-SE`, `fi-FI`, `hi-IN`, `mr-IN` |

Thirty-three identifiers share 28 models. The fast level has six models.

## Measured sizes

These are the models as published, measured on the pinned commits:

| Set | Bytes |
| --- | --- |
| fast, six languages (`/fast`) | 13,747,392 |
| best, six fast-level languages | 58,595,708 |
| best, 28 languages | 313,768,723 (299.2 MiB) |
| fast, 28 languages | 79,327,361 |

The fast level reads six languages, so only those six fast models are packaged. The accurate level packages one model per Tesseract code.

## Packaging

The layout is decided; the packaging run that ships it is not wired yet (see Status).

- `org.revenant.vision-text-fast` installs the six `tessdata_fast` models in `/usr/share/revenant/tessdata/fast`.
- `org.revenant.vision-text-<lang>` installs one `tessdata_best` model in `/usr/share/revenant/tessdata/best`, for each of the 28 languages.
- The Backports package depends on `org.revenant.vision-text-fast` and recommends `en`, `ru` and `uk`, so an app that reads Russian or Ukrainian has the models without a second install.
- The module `toolchain/modules/apple/vision_text.lua` writes these packages from the `tessdata` package's install directory; `toolchain/modules/debian.lua` writes the `Recommends` field.

## Where it differs from Apple's Vision

Each difference below is measured by `frameworks/Backports/tests/Vision/text_test.mm` against macOS Vision on the same image, or follows from the Tesseract output the backport reads.

- **Accuracy.** The accurate-level models read the fixtures to the text macOS Vision reads; the fast models misread a character in one fixture, `42` as `A2` in `de.png`. The fast check therefore allows an edit distance of at most 0.2 of the expected length, and the accurate check requires an exact match.
- **Box positions.** Tesseract's line and word boxes are compared with Vision's boxes in normalized coordinates. The tolerance is 0.04 on each of origin and size. The worst accurate deviation measured is 0.0323 (`uk.png`), so the tolerance has 0.008 of headroom. A tighter tolerance fails a fixture that is correct.
- **Word boxes.** Tesseract segments words; macOS Vision reports characters. macOS splits `10:30` into two words and the backport keeps it as one. The word ranges returned are found in the line text in order, and a word whose text is not found is skipped.
- **Confidence.** The backport reports the mean of Tesseract's word confidences divided by 100. macOS Vision reports discrete values, 0.5 or 1.0.
- **Candidates.** `topCandidates:` returns one candidate per line.
- **Minimum text height.** `minimumTextHeight` is applied to the line boxes.
- **Correction.** `usesLanguageCorrection = NO` turns off Tesseract's dictionaries. That approximates Vision's behaviour; it is not the same algorithm.
- **Custom words.** `customWords` is written to a user-words file in `NSTemporaryDirectory()` and loaded by Tesseract.
- **Spacing in CJK text.** Tesseract places a space between each Chinese, Japanese or Korean word unit. The backport drops a space when both neighbours are ideographs or kana. Without this the Chinese fixture reads `你 好 世界`.
- **Line text.** The text of a line is Tesseract's own line text, not a join of its words, so the spacing of Latin text is kept. Word ranges are found in that text afterwards.
- **Region of interest.** The region is cropped into a buffer before recognition, and the boxes are shifted back by the region's origin. Passing the region to Tesseract with `SetRectangle` returned no lines for a region that starts at row 0.
- **Vertical text.** The `chi_sim_vert` and `jpn_vert` models are not packaged. Tesseract logs that it cannot find them and reads the horizontal text.

## Noise and exit

- Leptonica is built without its image codecs, and Tesseract's TIFF probe is answered in the build (`LEPT_TIFF_RESULT`, `LEPT_TIFF_COMPILE_SUCCESS`). Leptonica and Tesseract then print to stderr: `pixReadMemTiff`, `bmfCreate`, `changeFormatForMissingLib`, `Parameter not found`, and `Detected N diacritics`. None of these changes a result.
- The host test prints `LEAK` lines at exit. The engine is kept until the process ends, so its model state is still allocated when the leak checker runs. The engine is a raw pointer that is deleted only when the language or the model changes; a `unique_ptr` version aborted at exit with `mutex lock failed: Invalid argument`.

## Status

- Compiled for `armv7-apple-ios6.0`: the six Vision sources pass a syntax check against the iOS 6 SDK.
- Host tests pass against the macOS Vision language lists and the fixture text: the default run and the negative control.
- Packaging modules are written, and their tests pass: `debian_test` (including the `Recommends` field) and `vision_text_test` (the fast package, a Russian package, the recommended names, and a refused missing model).
- Not yet done: wiring `vision_text.write` into the packaging run, which needs the `tessdata` install directory in that run. The `tessdata` recipe installs the 34 models the layout uses (about 390 MB) on its first install. They are needed only by the packaging run, not by an app build, so whether the packaging run gets them through the package manager is still to be decided.
- Not yet measured on the device: the iPhone 4S (A5, 512 MB) timing and resident memory for the best models. The result will be recorded here before the accurate level is shipped to the phone.
