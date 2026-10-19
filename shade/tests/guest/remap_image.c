// remap_image.c: one image of the remap test. Built twice with a different
// IMAGE_VALUE, same size and layout, so dyld can put either at the same base.
int remap_value(void) { return IMAGE_VALUE; }
int remap_padding[1024] = { IMAGE_VALUE };
