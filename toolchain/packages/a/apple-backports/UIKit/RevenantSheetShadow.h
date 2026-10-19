#include <stddef.h>
#include <stdint.h>

extern const float revenant_sheet_shadow_matrix[20];

const uint8_t *revenant_sheet_shadow_corner(unsigned scale);

double revenant_sheet_shadow_cap(double width, double height, double radius, double scale);

void revenant_sheet_shadow_pixel(uint8_t *pixel, double alpha);

int revenant_sheet_shadow_emulator(uint8_t *pixels, size_t columns, size_t rows, size_t rowBytes, double x, double y, double dx, double dy,
                              double width, double height, double cap, unsigned scale);
