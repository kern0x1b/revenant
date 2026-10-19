#include <stddef.h>
#include <stdint.h>

/* The "magic" shadow UIKit's drop shadow view lays under a sheet (facts/UIKit/UISheetPresentationController.md). */

/* The lower-intensity vibrant colour matrix -[_UIShadowView _updateShadowVisualStyling] (0x189229340 in UIKitCore of
   16.0) gives it, rows R G B A of five columns: r g b a and a constant. */
extern const float charon_sheet_shadow_matrix[20];

/* The alpha of one corner of the kit image _UIPopoverShadow, generated at a scale: 200 x 200 points, 200 * scale pixels
   per side, row 0 along the outer edge, the last pixel at the card's inner corner. Made once per scale and kept. */
const uint8_t *charon_sheet_shadow_corner(unsigned scale);

/* The cap inset -[_UIRoundedRectShadowView _loadImageIfNecessary] (0x188efd9d0) stretches the 400-point image with, for
   a shadow view of a size, a corner radius and a screen scale. */
double charon_sheet_shadow_cap(double width, double height, double radius, double scale);

/* One destination pixel, RGBA premultiplied and taken as opaque, turned into the shadow's pixel at a profile alpha:
   the matrix of the destination, clamped, with the matrix's own alpha times the profile's, premultiplied. Laid over the
   destination source-over, it leaves what the vibrant matrix leaves. */
void charon_sheet_shadow_pixel(uint8_t *pixel, double alpha);

/* A reading of what lies under the shadow view turned into the shadow over it, in place. x and y are the point, in the
   shadow view, of the first pixel's top left corner; dx and dy the points per pixel; width and height the shadow view's
   size, cap its cap inset (charon_sheet_shadow_cap) and scale the screen's, which picks the profile. 0 when the memory
   for the profile could not be had, and the pixels are left as they were. */
int charon_sheet_shadow_shade(uint8_t *pixels, size_t columns, size_t rows, size_t rowBytes, double x, double y, double dx, double dy,
                              double width, double height, double cap, unsigned scale);
