# CIImage imageByApplyingFilter, iOS 8.0 and 11.0

iOS 8.0 added `-[CIImage imageByApplyingFilter:withInputParameters:]`, which makes a filter, gives it this image and some values, and returns the output image, and iOS 11.0
added `-imageByApplyingFilter:`, the same with no values.

Source: the host's CoreImage, asked for a filter that does not exist, a key the filter does not have, parameters that are nil, an image given as the input in the parameters and the
default values of a filter; an iPad 2 running 6.1.3 for the filters of the release.

## What it does

The filter is made by name, and nil is the answer for a name that names none. Its default values are set, this image is its input image, and each parameter is set by its
key: a key the filter has takes the value, a key it does not have raises `NSUnknownKeyException` from the key-value coding of the filter, and `inputImage` in the
parameters replaces this image. A parameter of the wrong type is handed to the filter and raises nothing, on the host and on iOS 6 alike. The image is the filter's output image.

The images that come out are those of the filters of iOS 6, so their extents and pixels are the release's own; the Gaussian blur of iOS 6 grows a 64 by 64 image to 94 by 94 for a radius of 5, as the host's does
(`tests/backports/device/record-filter.m` prints it).
