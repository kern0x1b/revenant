#include "RevenantMPSBilinear.h"
#include <math.h>
#include <stdlib.h>

static const double revenantMPSBilinearWeightSteps = 256.0;

typedef struct {
    long low, high;
    double lowWeight, highWeight;
} RevenantMPSBilinearAxis;

static long revenantMPSBilinearIndex(long index, size_t count, int edgeMode)
{
    if (index >= 0 && index < (long)count)
        return index;
    if (edgeMode == RevenantMPSBilinearEdgeClamp)
        return index < 0 ? 0 : (long)count - 1;
    return -1;
}

static void revenantMPSBilinearAxis(RevenantMPSBilinearAxis *axis, size_t destination, double scale, double translate,
                                    size_t count, int edgeMode)
{
    double position = ((double)destination + 0.5 - translate) / scale - 0.5;
    double floorPosition = floor(position);
    double fraction = floor((position - floorPosition) * revenantMPSBilinearWeightSteps + 0.5) /
                      revenantMPSBilinearWeightSteps;
    long index = (long)floorPosition;
    axis->low = revenantMPSBilinearIndex(index, count, edgeMode);
    axis->high = revenantMPSBilinearIndex(index + 1, count, edgeMode);
    axis->lowWeight = 1.0 - fraction;
    axis->highWeight = fraction;
}

int RevenantMPSBilinearResample(const float *source, size_t sourceWidth, size_t sourceHeight, size_t channels,
                                int edgeMode, RevenantMPSBilinearTransform transform,
                                float *output, size_t originX, size_t originY, size_t width, size_t height)
{
    if (edgeMode != RevenantMPSBilinearEdgeZero && edgeMode != RevenantMPSBilinearEdgeClamp)
        return 0;
    RevenantMPSBilinearAxis *columns = malloc(sizeof *columns * (width ? width : 1));
    RevenantMPSBilinearAxis *rows = malloc(sizeof *rows * (height ? height : 1));
    if (!columns || !rows) {
        free(columns);
        free(rows);
        return 0;
    }
    for (size_t x = 0; x < width; x++)
        revenantMPSBilinearAxis(&columns[x], originX + x, transform.scaleX, transform.translateX, sourceWidth, edgeMode);
    for (size_t y = 0; y < height; y++)
        revenantMPSBilinearAxis(&rows[y], originY + y, transform.scaleY, transform.translateY, sourceHeight, edgeMode);
    for (size_t y = 0; y < height; y++) {
        const RevenantMPSBilinearAxis *row = &rows[y];
        for (size_t x = 0; x < width; x++) {
            const RevenantMPSBilinearAxis *column = &columns[x];
            float *out = output + (y * width + x) * channels;
            long rowIndices[2] = {row->low, row->high};
            double rowWeights[2] = {row->lowWeight, row->highWeight};
            long columnIndices[2] = {column->low, column->high};
            double columnWeights[2] = {column->lowWeight, column->highWeight};
            for (size_t k = 0; k < channels; k++) {
                double value = 0.0;
                for (int r = 0; r < 2; r++) {
                    if (rowIndices[r] < 0)
                        continue;
                    for (int c = 0; c < 2; c++) {
                        if (columnIndices[c] < 0)
                            continue;
                        value += rowWeights[r] * columnWeights[c] *
                                 source[((size_t)rowIndices[r] * sourceWidth + (size_t)columnIndices[c]) * channels + k];
                    }
                }
                out[k] = (float)value;
            }
        }
    }
    free(columns);
    free(rows);
    return 1;
}
