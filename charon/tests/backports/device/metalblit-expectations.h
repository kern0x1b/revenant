// metalblit-expectations.h — what macOS Metal answers, read off a real device on this host by
// tests/backports/host/metalblit/oracle.m. tests/backports/device/metalblit.m holds the port to it.
// Nothing here is the port's answer; it is Apple's, measured.
#ifndef METALBLIT_EXPECTATIONS_H
#define METALBLIT_EXPECTATIONS_H

static const char *const metalblit_fill = "0000000000000000abababababababababababababababab00000000000000000000000000000000000000000000000000000000000000000000000000000000";
static const char *const metalblit_buffer_copy = "0000000000000000000000000000000000000000000000000000000000000000000000000000000008090a0b0c0d0e0f10111213141516170000000000000000";
static const char *const metalblit_buffer_overlap = "0001020304050607000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f28292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f";
static const char *const metalblit_buffer_overlap_memmove = "0001020304050607000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f28292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f";
static const char *const metalblit_region_readback = "0000000000000000000000000000000068696a6b6c6d6e6f707172737475767700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088898a8b8c8d8e8f90919293949596970000000000000000000000000000000000000000000000000000000000000000";
static const char *const metalblit_bgra_written = "0102030405060708090a0b0c0d0e0f10";
static const char *const metalblit_bgra_readback = "0102030405060708090a0b0c0d0e0f10";
static const char *const metalblit_mip_level0 = "00102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f0";
static const char *const metalblit_mip_level1 = "20304050a0b0c0d020304050a0b0c0d0";
static const char *const metalblit_mip_rounding = "04";
static const char *const metalblit_mip_smallest_level = "00";
static const int metalblit_smallest_level_readable = 1;
static const int metalblit_mip_levels = 5;
static const int metalblit_level0_width = 16;
static const int metalblit_level0_height = 8;
static const int metalblit_level0_bytes_per_row = 64;
static const int metalblit_level1_width = 8;
static const int metalblit_level1_height = 4;
static const int metalblit_level1_bytes_per_row = 32;
static const int metalblit_level2_width = 4;
static const int metalblit_level2_height = 2;
static const int metalblit_level2_bytes_per_row = 16;
static const int metalblit_level3_width = 2;
static const int metalblit_level3_height = 1;
static const int metalblit_level3_bytes_per_row = 8;
static const int metalblit_level4_width = 1;
static const int metalblit_level4_height = 0;
static const int metalblit_level4_bytes_per_row = 4;
static const int metalblit_mip_is_a_box_average = 1;
static const int metalblit_mip_rounds_down = 0;
static const int metalblit_smallest_level = 4;

#endif
