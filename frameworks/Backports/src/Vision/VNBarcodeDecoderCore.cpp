#include "VNBarcodeDecoderCore.hpp"
#include <ZXing/ImageView.h>
#include <ZXing/ReadBarcode.h>
#include <ZXing/ReaderOptions.h>
#include <algorithm>
#include <cmath>

static double revenant_barcode_normalize(double value, int extent)
{
    return std::max(0.0, std::min(1.0, value / extent));
}

static RevenantBarcodePoint revenant_barcode_point(ZXing::PointI point, int width, int height)
{
    return {revenant_barcode_normalize(point.x, width), revenant_barcode_normalize(height - point.y, height)};
}

std::vector<RevenantBarcodeObservation> RevenantBarcodeDecode(const unsigned char* pixels, int width, int height)
{
    std::vector<RevenantBarcodeObservation> observations;
    if (pixels == nullptr || width <= 0 || height <= 0)
        return observations;
    ZXing::ReaderOptions options;
    options.formats(ZXing::BarcodeFormat::QRCode | ZXing::BarcodeFormat::PDF417);
    ZXing::ImageView image(pixels, width, height, ZXing::ImageFormat::Lum);
    for (const ZXing::Barcode& barcode : ZXing::ReadBarcodes(image, options)) {
        if (!barcode.isValid())
            continue;
        const ZXing::Position& position = barcode.position();
        RevenantBarcodeObservation observation;
        observation.payload = barcode.text();
        observation.format = barcode.format();
        observation.topLeft = revenant_barcode_point(position.topLeft(), width, height);
        observation.topRight = revenant_barcode_point(position.topRight(), width, height);
        observation.bottomRight = revenant_barcode_point(position.bottomRight(), width, height);
        observation.bottomLeft = revenant_barcode_point(position.bottomLeft(), width, height);
        double minX = std::min(std::min(observation.topLeft.x, observation.topRight.x), std::min(observation.bottomLeft.x, observation.bottomRight.x));
        double minY = std::min(std::min(observation.topLeft.y, observation.topRight.y), std::min(observation.bottomLeft.y, observation.bottomRight.y));
        double maxX = std::max(std::max(observation.topLeft.x, observation.topRight.x), std::max(observation.bottomLeft.x, observation.bottomRight.x));
        double maxY = std::max(std::max(observation.topLeft.y, observation.topRight.y), std::max(observation.bottomLeft.y, observation.bottomRight.y));
        observation.boundingBox = {minX, minY, maxX - minX, maxY - minY};
        if (observation.boundingBox.width > 0 && observation.boundingBox.height > 0)
            observations.push_back(std::move(observation));
    }
    return observations;
}
