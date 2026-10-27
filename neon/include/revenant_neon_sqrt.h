#ifndef REVENANT_NEON_SQRT_H_
#define REVENANT_NEON_SQRT_H_

static __inline__ __attribute__((always_inline, unused)) float32x4_t revenant_vsqrtq_f32(float32x4_t x) {
  uint32x4_t bits = vreinterpretq_u32_f32(x);
  uint32x4_t magnitude = vandq_u32(bits, vdupq_n_u32(0x7fffffffu));
  uint32x4_t nonzero = vcgtq_u32(magnitude, vdupq_n_u32(0));
  uint32x4_t negative = vtstq_u32(bits, vdupq_n_u32(0x80000000u));
  float32x4_t r = vrsqrteq_f32(x);
  r = vmulq_f32(r, vrsqrtsq_f32(vmulq_f32(x, r), r));
  r = vmulq_f32(r, vrsqrtsq_f32(vmulq_f32(x, r), r));
  r = vmulq_f32(r, vrsqrtsq_f32(vmulq_f32(x, r), r));
  float32x4_t root = vmulq_f32(x, r);
  uint32x4_t denormal = vandq_u32(vcltq_u32(magnitude, vdupq_n_u32(0x00800000u)), nonzero);
  root = vbslq_f32(denormal, vdupq_n_f32(0.0f), root);
  root = vbslq_f32(vandq_u32(negative, nonzero), vdupq_n_f32(__builtin_nanf("")), root);
  root = vbslq_f32(vceqq_u32(magnitude, vdupq_n_u32(0)), x, root);
  return vbslq_f32(vceqq_u32(bits, vdupq_n_u32(0x7f800000u)), x, root);
}

#endif
