#ifndef REVENANT_NEON_FMA_H_
#define REVENANT_NEON_FMA_H_

#include <math.h>

static __inline__ __attribute__((always_inline, unused)) float32x4_t revenant_vfmaq_f32(float32x4_t a, float32x4_t b, float32x4_t c) {
  float addend[4], multiplier[4], multiplicand[4], lanes[4];
  vst1q_f32(addend, a);
  vst1q_f32(multiplier, b);
  vst1q_f32(multiplicand, c);
  for (int lane = 0; lane < 4; lane++)
    lanes[lane] = fmaf(multiplier[lane], multiplicand[lane], addend[lane]);
  return vld1q_f32(lanes);
}

#endif
