# Vision's barcode symbologies of iOS 15

Six barcode symbologies iOS 15 added are carried in `Vision/Vision15_0.m`, each a string equal to its name:

    VNBarcodeSymbologyCodabar
    VNBarcodeSymbologyGS1DataBar
    VNBarcodeSymbologyGS1DataBarExpanded
    VNBarcodeSymbologyGS1DataBarLimited
    VNBarcodeSymbologyMicroPDF417
    VNBarcodeSymbologyMicroQR

The values are the host's: the host Vision of macOS 27.0.1 (build 26A434) gives each name as its own value, as it does for
the symbologies that were there before. The probe that reads them is `tests/backports/host/vision-coordinates15/probe.m`,
and `run.sh` compares each line with the host's output.

A symbology is a value an application puts in a barcode request's list of symbologies. These six are the names; the
request's own list of the symbologies it detects, `VNDetectBarcodesRequest +supportedSymbologies` in `Vision/VNRequests.m`,
does not yet include them. That is a gap of the request, not of these constants, and it is open: the request has to learn
the six before a barcode of one of these types can be asked for by name.

What is not proved: the values are macOS 27's, not iOS 15's, and are not read from an iOS 15 cache. A value that changed
between the two would pass the host comparison and be wrong on a device.
