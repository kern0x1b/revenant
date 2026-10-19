# Names of CoreText, MobileCoreServices, CoreImage and MapKit that iOS 7 to 10 added

iOS 7.0 added the language attribute of an attributed string and seven of the input keys a `CIFilter` takes; iOS 8.0 added the
ruby annotation attribute and the type identifiers of an AIFF file, a font, tab-separated text, a waveform audio file and a zip archive; iOS 9.0 added the
launch option that asks Maps for transit directions; iOS 10.0 added the option that lets a `CIContext` cache intermediate images.

Source: CoreText, MobileCoreServices, CoreImage and MapKit of the arm64 shared cache of iOS 12.0, where each constant is a string and its text was read; an
iPad 2 running 6.1.3 and the iOS 6.0 emulator, asked with `dlsym`, which export none of the names.

## Where iOS 6 differs

iOS 6 exports none of them. They are carried with the text above, so that an application that names one loads. The input keys are the strings the
filters of iOS 6 read their inputs by (`inputScale`, `inputCenter`, `inputIntensity` and the rest), so they select the same input on the filters that have it. The
type identifiers are not declared by the type database of iOS 6 unless the release declares them, so `UTTypeConformsTo` and the extension of a file are the
answers of the release. The ruby annotation attribute and the language attribute are read by nothing in CoreText of iOS 6, Maps of iOS 6
reads no launch option for transit directions, and the context reads no option to cache.
