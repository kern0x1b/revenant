#pragma once

#include <ZXing/BarcodeFormat.h>
#include <string>
#include <vector>

struct RevenantBarcodePoint {
    double x;
    double y;
};

struct RevenantBarcodeBox {
    double x;
    double y;
    double width;
    double height;
};

struct RevenantBarcodeObservation {
    std::string payload;
    ZXing::BarcodeFormat format;
    RevenantBarcodeBox boundingBox;
    RevenantBarcodePoint topLeft;
    RevenantBarcodePoint topRight;
    RevenantBarcodePoint bottomRight;
    RevenantBarcodePoint bottomLeft;
};

std::vector<RevenantBarcodeObservation> RevenantBarcodeDecode(const unsigned char* pixels, int width, int height);
