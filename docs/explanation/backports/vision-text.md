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

The `tessdata` recipe takes a `languages` option: a list of Tesseract codes, or `all`. The default is `eng,rus,ukr`. Each code is installed at the fast level where the fast level answers it (the six languages of the table above), and at the accurate level where tessdata_best has its model. The packaging configuration installs the default set; the host tests install `all`.

Each installed model is one package, installed in `/usr/share/revenant/tessdata/{fast,best}`:

- `org.revenant.vision-text-best-eng` and `org.revenant.vision-text-fast-eng` are the accurate and the fast English models. The Backports package depends on both.
- `org.revenant.vision-text-best-rus` and `org.revenant.vision-text-best-ukr` are the accurate Russian and Ukrainian models. The Backports package recommends them.
- `org.revenant.vision-text-fast-<code>` is the fast model of each of the other five fast-level languages, and `org.revenant.vision-text-best-<code>` is the accurate model for each code. An underscore in the code becomes a hyphen, so `chi_sim` is `best-chi-sim`. Nothing depends on these; an app that needs one of them installs its package.

`toolchain/modules/apple/vision_text.lua` writes one package for each installed model. `platform.vision_text_debs` calls it with the install directory of the `tessdata` package that the Vision target requires, and `backports_package` writes the Depends and Recommends fields.

The fast level answers only the six languages of macOS's fast list, so it has no Russian or Ukrainian model at all; `ru-RU` and `uk-UA` are read at the accurate level, as on macOS. For that reason the Backports package recommends `best-rus` and `best-ukr`, and the fast Russian and Ukrainian models are not packaged.

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

## Measured on the iPhone 4S

The probe is a C++ and Objective-C program over `VNTextRecognizer.h`, built for `armv7-apple-ios6.0` and run on an iPhone 4S with iOS 6.1.3. It recognizes one image three times in one process; the first run includes loading the model. The probe must be linked with the project's `ld64` (`-fuse-ld=`): a binary linked with Xcode's linker crashed at startup on the device with a segmentation fault or a bad system call, and the same program linked with `ld64` ran.

| Model | Image | Run 1 s | Run 2 s | Run 3 s | Peak RSS MiB | Resident after each run MiB |
| --- | --- | --- | --- | --- | --- | --- |
| best `eng` | `en-two-lines.png` | 4.60 | 3.80 | 3.82 | 51.8 | 21.8, 26.0, 30.2 |
| best `rus` | `ru.png` | 5.50 | 4.72 | 4.71 | 51.5 | 22.5, 26.7, 31.0 |
| best `ukr` | `uk.png` | 5.21 | 4.68 | 4.67 | 38.7 | 22.3, 26.4, 30.6 |
| fast `eng` | `en-two-lines.png` | 0.88 | 0.64 | 0.65 | 24.8 | 15.2, 19.4, 23.6 |

The text read matches the fixtures: `Hello, world` and `Vision text 2026` for English, `Привет, мир` and `Текст на русском языке` for Russian, `Привіт, світ` and `Текст українською мовою` for Ukrainian.

- Memory: the accurate level's peak is about 52 MiB on a device with 512 MiB, so the accurate level fits the A5 in memory.
- Time: an accurate recognition of a two-line image takes about 4.7 seconds, against about 0.65 seconds for the fast level. The first recognition adds about 0.8 seconds to load the model. A full page takes longer; that was not measured.
- Growth: each recognition after the first leaves about 4.2 MiB more resident. The cause is not determined. The probe runs no autorelease pool, so Objective-C objects of earlier runs stay until exit; that does not account for the whole growth.

## Status

- Compiled for `armv7-apple-ios6.0`: the six Vision sources pass a syntax check against the iOS 6 SDK, and the probe runs on the iPhone 4S (above).
- Host tests pass against the macOS Vision language lists and the fixture text: the default run and the negative control. The host tests were rerun after the `tessdata` recipe took the `languages` option.
- Packaging modules are written, and their tests pass: `debian_test` (including the `Recommends` field) and `vision_text_test` (the per-model packages, the dependency and recommendation names, an unknown model, and a missing license). The `tessdata` recipe configures and installs for macOS.
- Not yet run: a full iOS packaging run that writes the Backports package and the model packages together. The iOS default set (`eng,rus,ukr`) was not installed for iOS in this run.
- Open: the growth of resident memory across recognitions.
