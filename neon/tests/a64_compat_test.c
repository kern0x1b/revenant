// Prints one line per AArch64-only intrinsic that neon/include implements: its name and a hash of
// its results over the same pseudorandom inputs. Built for arm64 it calls the native intrinsics;
// built for armv7 it calls the compatibility header. The two outputs must be identical.

#include <arm_neon.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define ITERATIONS 512

static uint64_t state = 0x9E3779B97F4A7C15ULL;
static uint64_t hash;

static uint8_t next_byte(void) {
  state ^= state << 13;
  state ^= state >> 7;
  state ^= state << 17;
  return (uint8_t)(state >> 24);
}

#define RANDOM_VALUE(T)                                  \
  ({                                                     \
    T value_;                                            \
    uint8_t *bytes_ = (uint8_t *)&value_;                \
    for (size_t i_ = 0; i_ < sizeof(T); i_++) {          \
      bytes_[i_] = next_byte();                          \
    }                                                    \
    value_;                                              \
  })

static void mix(const void *data, size_t size) {
  const uint8_t *bytes = (const uint8_t *)data;
  for (size_t i = 0; i < size; i++) {
    hash ^= bytes[i];
    hash *= 1099511628211ULL;
  }
}

#define BEGIN() (hash = 1469598103934665603ULL)
#define END(name) printf("%s %016llx\n", name, (unsigned long long)hash)

#define TEST1(FN, RT, AT)                                \
  do {                                                   \
    BEGIN();                                             \
    for (int k = 0; k < ITERATIONS; k++) {               \
      AT a = RANDOM_VALUE(AT);                           \
      RT r = FN(a);                                      \
      mix(&r, sizeof(r));                                \
    }                                                    \
    END(#FN);                                            \
  } while (0)

#define TEST2(FN, RT, AT, BT)                            \
  do {                                                   \
    BEGIN();                                             \
    for (int k = 0; k < ITERATIONS; k++) {               \
      AT a = RANDOM_VALUE(AT);                           \
      BT b = RANDOM_VALUE(BT);                           \
      RT r = FN(a, b);                                   \
      mix(&r, sizeof(r));                                \
    }                                                    \
    END(#FN);                                            \
  } while (0)

#define TEST3(FN, RT, AT, BT, CT)                        \
  do {                                                   \
    BEGIN();                                             \
    for (int k = 0; k < ITERATIONS; k++) {               \
      AT a = RANDOM_VALUE(AT);                           \
      BT b = RANDOM_VALUE(BT);                           \
      CT c = RANDOM_VALUE(CT);                           \
      RT r = FN(a, b, c);                                \
      mix(&r, sizeof(r));                                \
    }                                                    \
    END(#FN);                                            \
  } while (0)

int main(void) {
  TEST1(vmaxvq_u8, uint8_t, uint8x16_t);
  TEST1(vmaxvq_s8, int8_t, int8x16_t);
  TEST1(vmaxvq_u16, uint16_t, uint16x8_t);
  TEST1(vmaxvq_s16, int16_t, int16x8_t);
  TEST1(vmaxvq_u32, uint32_t, uint32x4_t);
  TEST1(vmaxvq_s32, int32_t, int32x4_t);
  TEST1(vminvq_u8, uint8_t, uint8x16_t);
  TEST1(vminvq_s8, int8_t, int8x16_t);
  TEST1(vminvq_u16, uint16_t, uint16x8_t);
  TEST1(vminvq_s16, int16_t, int16x8_t);
  TEST1(vminvq_u32, uint32_t, uint32x4_t);
  TEST1(vminvq_s32, int32_t, int32x4_t);
  TEST1(vaddvq_u8, uint8_t, uint8x16_t);
  TEST1(vaddvq_s8, int8_t, int8x16_t);
  TEST1(vaddvq_u16, uint16_t, uint16x8_t);
  TEST1(vaddvq_s16, int16_t, int16x8_t);
  TEST1(vaddvq_u32, uint32_t, uint32x4_t);
  TEST1(vaddvq_s32, int32_t, int32x4_t);
  TEST1(vaddvq_u64, uint64_t, uint64x2_t);
  TEST1(vaddvq_s64, int64_t, int64x2_t);

  TEST1(vmaxv_u8, uint8_t, uint8x8_t);
  TEST1(vmaxv_s8, int8_t, int8x8_t);
  TEST1(vmaxv_u16, uint16_t, uint16x4_t);
  TEST1(vmaxv_s16, int16_t, int16x4_t);
  TEST1(vmaxv_u32, uint32_t, uint32x2_t);
  TEST1(vmaxv_s32, int32_t, int32x2_t);
  TEST1(vminv_u8, uint8_t, uint8x8_t);
  TEST1(vminv_s8, int8_t, int8x8_t);
  TEST1(vminv_u16, uint16_t, uint16x4_t);
  TEST1(vminv_s16, int16_t, int16x4_t);
  TEST1(vminv_u32, uint32_t, uint32x2_t);
  TEST1(vminv_s32, int32_t, int32x2_t);
  TEST1(vaddv_u8, uint8_t, uint8x8_t);
  TEST1(vaddv_s8, int8_t, int8x8_t);
  TEST1(vaddv_u16, uint16_t, uint16x4_t);
  TEST1(vaddv_s16, int16_t, int16x4_t);
  TEST1(vaddv_u32, uint32_t, uint32x2_t);
  TEST1(vaddv_s32, int32_t, int32x2_t);

  TEST1(vaddlvq_u8, uint16_t, uint8x16_t);
  TEST1(vaddlvq_s8, int16_t, int8x16_t);
  TEST1(vaddlvq_u16, uint32_t, uint16x8_t);
  TEST1(vaddlvq_s16, int32_t, int16x8_t);
  TEST1(vaddlvq_u32, uint64_t, uint32x4_t);
  TEST1(vaddlv_u8, uint16_t, uint8x8_t);

  TEST2(vpaddq_u8, uint8x16_t, uint8x16_t, uint8x16_t);
  TEST2(vpaddq_s8, int8x16_t, int8x16_t, int8x16_t);
  TEST2(vpaddq_u16, uint16x8_t, uint16x8_t, uint16x8_t);
  TEST2(vpaddq_s16, int16x8_t, int16x8_t, int16x8_t);
  TEST2(vpaddq_u32, uint32x4_t, uint32x4_t, uint32x4_t);
  TEST2(vpaddq_s32, int32x4_t, int32x4_t, int32x4_t);

  TEST2(vqtbl1q_u8, uint8x16_t, uint8x16_t, uint8x16_t);
  TEST2(vqtbl1q_s8, int8x16_t, int8x16_t, uint8x16_t);
  TEST2(vqtbl1_u8, uint8x8_t, uint8x16_t, uint8x8_t);
  TEST2(vqtbl2q_u8, uint8x16_t, uint8x16x2_t, uint8x16_t);
  TEST2(vqtbl2q_s8, int8x16_t, int8x16x2_t, uint8x16_t);
  TEST2(vqtbl3q_u8, uint8x16_t, uint8x16x3_t, uint8x16_t);
  TEST2(vqtbl3q_s8, int8x16_t, int8x16x3_t, uint8x16_t);
  TEST2(vqtbl4q_u8, uint8x16_t, uint8x16x4_t, uint8x16_t);
  TEST2(vqtbl4q_s8, int8x16_t, int8x16x4_t, uint8x16_t);

#define ZIP_Q(S, VT)                                     \
  TEST2(vzip1q_##S, VT, VT, VT);                         \
  TEST2(vzip2q_##S, VT, VT, VT);                         \
  TEST2(vuzp1q_##S, VT, VT, VT);                         \
  TEST2(vuzp2q_##S, VT, VT, VT);                         \
  TEST2(vtrn1q_##S, VT, VT, VT);                         \
  TEST2(vtrn2q_##S, VT, VT, VT);
#define ZIP_D(S, VT)                                     \
  TEST2(vzip1_##S, VT, VT, VT);                          \
  TEST2(vzip2_##S, VT, VT, VT);                          \
  TEST2(vuzp1_##S, VT, VT, VT);                          \
  TEST2(vuzp2_##S, VT, VT, VT);                          \
  TEST2(vtrn1_##S, VT, VT, VT);                          \
  TEST2(vtrn2_##S, VT, VT, VT);
  ZIP_Q(u8, uint8x16_t)
  ZIP_Q(s8, int8x16_t)
  ZIP_Q(u16, uint16x8_t)
  ZIP_Q(s16, int16x8_t)
  ZIP_Q(u32, uint32x4_t)
  ZIP_Q(s32, int32x4_t)
  ZIP_Q(f32, float32x4_t)
  ZIP_D(u8, uint8x8_t)
  ZIP_D(s8, int8x8_t)
  ZIP_D(u16, uint16x4_t)
  ZIP_D(s16, int16x4_t)
  ZIP_D(u32, uint32x2_t)
  ZIP_D(s32, int32x2_t)
  ZIP_D(f32, float32x2_t)
  TEST2(vtrn1q_s64, int64x2_t, int64x2_t, int64x2_t);
  TEST2(vtrn2q_s64, int64x2_t, int64x2_t, int64x2_t);
  TEST2(vtrn1q_u64, uint64x2_t, uint64x2_t, uint64x2_t);
  TEST2(vtrn2q_u64, uint64x2_t, uint64x2_t, uint64x2_t);

  TEST1(vmovl_high_u8, uint16x8_t, uint8x16_t);
  TEST1(vmovl_high_s8, int16x8_t, int8x16_t);
  TEST1(vmovl_high_u16, uint32x4_t, uint16x8_t);
  TEST1(vmovl_high_s16, int32x4_t, int16x8_t);
  TEST1(vmovl_high_u32, uint64x2_t, uint32x4_t);
  TEST1(vmovl_high_s32, int64x2_t, int32x4_t);

  TEST2(vmovn_high_u16, uint8x16_t, uint8x8_t, uint16x8_t);
  TEST2(vmovn_high_s16, int8x16_t, int8x8_t, int16x8_t);
  TEST2(vmovn_high_u32, uint16x8_t, uint16x4_t, uint32x4_t);
  TEST2(vmovn_high_s32, int16x8_t, int16x4_t, int32x4_t);
  TEST2(vmovn_high_u64, uint32x4_t, uint32x2_t, uint64x2_t);
  TEST2(vmovn_high_s64, int32x4_t, int32x2_t, int64x2_t);
  TEST2(vqmovn_high_u16, uint8x16_t, uint8x8_t, uint16x8_t);
  TEST2(vqmovn_high_s16, int8x16_t, int8x8_t, int16x8_t);
  TEST2(vqmovn_high_u32, uint16x8_t, uint16x4_t, uint32x4_t);
  TEST2(vqmovn_high_s32, int16x8_t, int16x4_t, int32x4_t);
  TEST2(vqmovn_high_u64, uint32x4_t, uint32x2_t, uint64x2_t);
  TEST2(vqmovn_high_s64, int32x4_t, int32x2_t, int64x2_t);
  TEST2(vqmovun_high_s16, uint8x16_t, uint8x8_t, int16x8_t);
  TEST2(vqmovun_high_s32, uint16x8_t, uint16x4_t, int32x4_t);
  TEST2(vqmovun_high_s64, uint32x4_t, uint32x2_t, int64x2_t);

  TEST2(vmull_high_s8, int16x8_t, int8x16_t, int8x16_t);
  TEST2(vmull_high_u8, uint16x8_t, uint8x16_t, uint8x16_t);
  TEST2(vmull_high_s16, int32x4_t, int16x8_t, int16x8_t);
  TEST2(vmull_high_u16, uint32x4_t, uint16x8_t, uint16x8_t);
  TEST2(vmull_high_s32, int64x2_t, int32x4_t, int32x4_t);
  TEST2(vmull_high_u32, uint64x2_t, uint32x4_t, uint32x4_t);
  TEST3(vmlal_high_s8, int16x8_t, int16x8_t, int8x16_t, int8x16_t);
  TEST3(vmlal_high_u8, uint16x8_t, uint16x8_t, uint8x16_t, uint8x16_t);
  TEST3(vmlal_high_s16, int32x4_t, int32x4_t, int16x8_t, int16x8_t);
  TEST3(vmlal_high_u16, uint32x4_t, uint32x4_t, uint16x8_t, uint16x8_t);
  TEST3(vmlal_high_s32, int64x2_t, int64x2_t, int32x4_t, int32x4_t);
  TEST3(vmlal_high_u32, uint64x2_t, uint64x2_t, uint32x4_t, uint32x4_t);

  TEST1(vneg_s64, int64x1_t, int64x1_t);
  TEST1(vnegq_s64, int64x2_t, int64x2_t);
  TEST1(vabs_s64, int64x1_t, int64x1_t);
  TEST1(vabsq_s64, int64x2_t, int64x2_t);
  TEST1(vcltzq_s16, uint16x8_t, int16x8_t);
  TEST1(vcltzq_s64, uint64x2_t, int64x2_t);

  BEGIN();
  for (int k = 0; k < ITERATIONS; k++) {
    int16x8_t a = RANDOM_VALUE(int16x8_t);
    int16x8_t r0 = vdupq_laneq_s16(a, 0);
    int16x8_t r1 = vdupq_laneq_s16(a, 1);
    int16x8_t r2 = vdupq_laneq_s16(a, 2);
    int16x8_t r3 = vdupq_laneq_s16(a, 3);
    int16x8_t r4 = vdupq_laneq_s16(a, 4);
    int16x8_t r5 = vdupq_laneq_s16(a, 5);
    int16x8_t r6 = vdupq_laneq_s16(a, 6);
    int16x8_t r7 = vdupq_laneq_s16(a, 7);
    mix(&r0, sizeof(r0));
    mix(&r1, sizeof(r1));
    mix(&r2, sizeof(r2));
    mix(&r3, sizeof(r3));
    mix(&r4, sizeof(r4));
    mix(&r5, sizeof(r5));
    mix(&r6, sizeof(r6));
    mix(&r7, sizeof(r7));
  }
  END("vdupq_laneq_s16");
  return 0;
}
