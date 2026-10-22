#import <Foundation/Foundation.h>
#include <math.h>

typedef struct {
    const char *symbol;
    double base0;
    double base1;
    const char *patterns[2][6];
    const char *names[2][3];
} RevenantMeasurementUnit;

typedef struct {
    const char *dimension;
    const RevenantMeasurementUnit *units;
    size_t count;
} RevenantMeasurementDimension;

extern const RevenantMeasurementDimension revenant_measurement_dimensions[];
extern const size_t revenant_measurement_dimension_count;
