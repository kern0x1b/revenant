#include <stddef.h>
#include <stdint.h>

extern const float charon_sheet_shadow_matrix[20];

const uint8_t *charon_sheet_shadow_corner(unsigned scale);

double charon_sheet_shadow_cap(double width, double height, double radius, double scale);

void charon_sheet_shadow_pixel(uint8_t *pixel, double alpha);

int charon_sheet_shadow_shade(uint8_t *pixels, size_t columns, size_t rows, size_t rowBytes, double x, double y, double dx, double dy,
                              double width, double height, double cap, unsigned scale);
