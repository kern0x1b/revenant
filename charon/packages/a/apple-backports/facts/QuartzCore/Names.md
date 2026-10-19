# Names of QuartzCore that iOS 7 to 12 added

Constant strings of the framework: the formats of the contents of a layer, the conic gradient type, the render options and the keys of the renderer.

Source: QuartzCore of the arm64 shared cache of iOS 12.0, where each constant is a string and its text was read; the header of iOS 16.4 for the type and the release that added each name;
an iPad 2 running 6.1.3 and the iOS 6.0 emulator, asked with `dlsym`, which export none of them.

## Where iOS 6 differs

iOS 6 exports none of these names, and an application that names one is not loaded at all. They are carried, each with the text the newer release gives it, so that an application
that names one loads, as it does on a release that has them. Nothing of iOS 6 produces, reads or posts the string under that name: a key is never found in a dictionary the release makes, a notification
is never posted, and a value an application hands to the release is treated as the release treats any string it does not know, which the release answers as its own code does. An application that
checks whether a feature exists before it uses it (a codec, a capture device type, a key algorithm, a metadata dictionary) gets the answer of the release for that feature, not for the name.
