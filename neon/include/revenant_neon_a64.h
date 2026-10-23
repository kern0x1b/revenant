#ifndef REVENANT_NEON_A64_H_
#define REVENANT_NEON_A64_H_

#define REVENANT_A64_INLINE static __inline__ __attribute__((always_inline, unused))

#define REVENANT_RED_Q8(NAME, OPV, OPP, S, T, VT, DT)                          \
REVENANT_A64_INLINE T v##NAME##vq_##S(VT a) {                                  \
  DT m = OPV##_##S(vget_low_##S(a), vget_high_##S(a));                         \
  m = OPP##_##S(m, m);                                                         \
  m = OPP##_##S(m, m);                                                         \
  m = OPP##_##S(m, m);                                                         \
  return vget_lane_##S(m, 0);                                                  \
}

#define REVENANT_RED_Q16(NAME, OPV, OPP, S, T, VT, DT)                         \
REVENANT_A64_INLINE T v##NAME##vq_##S(VT a) {                                  \
  DT m = OPV##_##S(vget_low_##S(a), vget_high_##S(a));                         \
  m = OPP##_##S(m, m);                                                         \
  m = OPP##_##S(m, m);                                                         \
  return vget_lane_##S(m, 0);                                                  \
}

#define REVENANT_RED_Q32(NAME, OPV, OPP, S, T, VT, DT)                         \
REVENANT_A64_INLINE T v##NAME##vq_##S(VT a) {                                  \
  DT m = OPV##_##S(vget_low_##S(a), vget_high_##S(a));                         \
  m = OPP##_##S(m, m);                                                         \
  return vget_lane_##S(m, 0);                                                  \
}

#define REVENANT_RED_D8(NAME, OPP, S, T, VT)                                   \
REVENANT_A64_INLINE T v##NAME##v_##S(VT a) {                                   \
  VT m = OPP##_##S(a, a);                                                      \
  m = OPP##_##S(m, m);                                                         \
  m = OPP##_##S(m, m);                                                         \
  return vget_lane_##S(m, 0);                                                  \
}

#define REVENANT_RED_D16(NAME, OPP, S, T, VT)                                  \
REVENANT_A64_INLINE T v##NAME##v_##S(VT a) {                                   \
  VT m = OPP##_##S(a, a);                                                      \
  m = OPP##_##S(m, m);                                                         \
  return vget_lane_##S(m, 0);                                                  \
}

#define REVENANT_RED_D32(NAME, OPP, S, T, VT)                                  \
REVENANT_A64_INLINE T v##NAME##v_##S(VT a) {                                   \
  VT m = OPP##_##S(a, a);                                                      \
  return vget_lane_##S(m, 0);                                                  \
}

REVENANT_RED_Q8(max, vmax, vpmax, u8, uint8_t, uint8x16_t, uint8x8_t)
REVENANT_RED_Q8(max, vmax, vpmax, s8, int8_t, int8x16_t, int8x8_t)
REVENANT_RED_Q8(min, vmin, vpmin, u8, uint8_t, uint8x16_t, uint8x8_t)
REVENANT_RED_Q8(min, vmin, vpmin, s8, int8_t, int8x16_t, int8x8_t)
REVENANT_RED_Q16(max, vmax, vpmax, u16, uint16_t, uint16x8_t, uint16x4_t)
REVENANT_RED_Q16(max, vmax, vpmax, s16, int16_t, int16x8_t, int16x4_t)
REVENANT_RED_Q16(min, vmin, vpmin, u16, uint16_t, uint16x8_t, uint16x4_t)
REVENANT_RED_Q16(min, vmin, vpmin, s16, int16_t, int16x8_t, int16x4_t)
REVENANT_RED_Q32(max, vmax, vpmax, u32, uint32_t, uint32x4_t, uint32x2_t)
REVENANT_RED_Q32(max, vmax, vpmax, s32, int32_t, int32x4_t, int32x2_t)
REVENANT_RED_Q32(min, vmin, vpmin, u32, uint32_t, uint32x4_t, uint32x2_t)
REVENANT_RED_Q32(min, vmin, vpmin, s32, int32_t, int32x4_t, int32x2_t)

REVENANT_RED_Q8(add, vadd, vpadd, u8, uint8_t, uint8x16_t, uint8x8_t)
REVENANT_RED_Q8(add, vadd, vpadd, s8, int8_t, int8x16_t, int8x8_t)
REVENANT_RED_Q16(add, vadd, vpadd, u16, uint16_t, uint16x8_t, uint16x4_t)
REVENANT_RED_Q16(add, vadd, vpadd, s16, int16_t, int16x8_t, int16x4_t)
REVENANT_RED_Q32(add, vadd, vpadd, u32, uint32_t, uint32x4_t, uint32x2_t)
REVENANT_RED_Q32(add, vadd, vpadd, s32, int32_t, int32x4_t, int32x2_t)

REVENANT_A64_INLINE uint64_t vaddvq_u64(uint64x2_t a) {
  return vgetq_lane_u64(a, 0) + vgetq_lane_u64(a, 1);
}

REVENANT_A64_INLINE int64_t vaddvq_s64(int64x2_t a) {
  return vgetq_lane_s64(a, 0) + vgetq_lane_s64(a, 1);
}

REVENANT_RED_D8(max, vpmax, u8, uint8_t, uint8x8_t)
REVENANT_RED_D8(max, vpmax, s8, int8_t, int8x8_t)
REVENANT_RED_D8(min, vpmin, u8, uint8_t, uint8x8_t)
REVENANT_RED_D8(min, vpmin, s8, int8_t, int8x8_t)
REVENANT_RED_D16(max, vpmax, u16, uint16_t, uint16x4_t)
REVENANT_RED_D16(max, vpmax, s16, int16_t, int16x4_t)
REVENANT_RED_D16(min, vpmin, u16, uint16_t, uint16x4_t)
REVENANT_RED_D16(min, vpmin, s16, int16_t, int16x4_t)
REVENANT_RED_D32(max, vpmax, u32, uint32_t, uint32x2_t)
REVENANT_RED_D32(max, vpmax, s32, int32_t, int32x2_t)
REVENANT_RED_D32(min, vpmin, u32, uint32_t, uint32x2_t)
REVENANT_RED_D32(min, vpmin, s32, int32_t, int32x2_t)

REVENANT_RED_D8(add, vpadd, u8, uint8_t, uint8x8_t)
REVENANT_RED_D8(add, vpadd, s8, int8_t, int8x8_t)
REVENANT_RED_D16(add, vpadd, u16, uint16_t, uint16x4_t)
REVENANT_RED_D16(add, vpadd, s16, int16_t, int16x4_t)
REVENANT_RED_D32(add, vpadd, u32, uint32_t, uint32x2_t)
REVENANT_RED_D32(add, vpadd, s32, int32_t, int32x2_t)

REVENANT_A64_INLINE uint16_t vaddlvq_u8(uint8x16_t a) {
  uint64x2_t y = vpaddlq_u32(vpaddlq_u16(vpaddlq_u8(a)));
  return (uint16_t)(vgetq_lane_u64(y, 0) + vgetq_lane_u64(y, 1));
}

REVENANT_A64_INLINE int16_t vaddlvq_s8(int8x16_t a) {
  int64x2_t y = vpaddlq_s32(vpaddlq_s16(vpaddlq_s8(a)));
  return (int16_t)(vgetq_lane_s64(y, 0) + vgetq_lane_s64(y, 1));
}

REVENANT_A64_INLINE uint32_t vaddlvq_u16(uint16x8_t a) {
  uint64x2_t y = vpaddlq_u32(vpaddlq_u16(a));
  return (uint32_t)(vgetq_lane_u64(y, 0) + vgetq_lane_u64(y, 1));
}

REVENANT_A64_INLINE int32_t vaddlvq_s16(int16x8_t a) {
  int64x2_t y = vpaddlq_s32(vpaddlq_s16(a));
  return (int32_t)(vgetq_lane_s64(y, 0) + vgetq_lane_s64(y, 1));
}

REVENANT_A64_INLINE uint64_t vaddlvq_u32(uint32x4_t a) {
  uint64x2_t y = vpaddlq_u32(a);
  return vgetq_lane_u64(y, 0) + vgetq_lane_u64(y, 1);
}

REVENANT_A64_INLINE uint16_t vaddlv_u8(uint8x8_t a) {
  uint64x1_t y = vpaddl_u32(vpaddl_u16(vpaddl_u8(a)));
  return (uint16_t)vget_lane_u64(y, 0);
}

#define REVENANT_PAIR_Q(S, VT)                                                  \
REVENANT_A64_INLINE VT vpaddq_##S(VT a, VT b) {                                 \
  return vcombine_##S(vpadd_##S(vget_low_##S(a), vget_high_##S(a)),             \
                      vpadd_##S(vget_low_##S(b), vget_high_##S(b)));            \
}

REVENANT_PAIR_Q(u8, uint8x16_t)
REVENANT_PAIR_Q(s8, int8x16_t)
REVENANT_PAIR_Q(u16, uint16x8_t)
REVENANT_PAIR_Q(s16, int16x8_t)
REVENANT_PAIR_Q(u32, uint32x4_t)
REVENANT_PAIR_Q(s32, int32x4_t)

REVENANT_A64_INLINE uint8x16_t vqtbl1q_u8(uint8x16_t t, uint8x16_t idx) {
  uint8x8x2_t tab = {{vget_low_u8(t), vget_high_u8(t)}};
  return vcombine_u8(vtbl2_u8(tab, vget_low_u8(idx)), vtbl2_u8(tab, vget_high_u8(idx)));
}

REVENANT_A64_INLINE int8x16_t vqtbl1q_s8(int8x16_t t, uint8x16_t idx) {
  return vreinterpretq_s8_u8(vqtbl1q_u8(vreinterpretq_u8_s8(t), idx));
}

REVENANT_A64_INLINE uint8x8_t vqtbl1_u8(uint8x16_t t, uint8x8_t idx) {
  uint8x8x2_t tab = {{vget_low_u8(t), vget_high_u8(t)}};
  return vtbl2_u8(tab, idx);
}

REVENANT_A64_INLINE uint8x16_t vqtbl2q_u8(uint8x16x2_t t, uint8x16_t idx) {
  uint8x8x4_t tab = {{vget_low_u8(t.val[0]), vget_high_u8(t.val[0]),
                      vget_low_u8(t.val[1]), vget_high_u8(t.val[1])}};
  return vcombine_u8(vtbl4_u8(tab, vget_low_u8(idx)), vtbl4_u8(tab, vget_high_u8(idx)));
}

REVENANT_A64_INLINE int8x16_t vqtbl2q_s8(int8x16x2_t t, uint8x16_t idx) {
  uint8x16x2_t u = {{vreinterpretq_u8_s8(t.val[0]), vreinterpretq_u8_s8(t.val[1])}};
  return vreinterpretq_s8_u8(vqtbl2q_u8(u, idx));
}

REVENANT_A64_INLINE uint8x16_t vqtbl3q_u8(uint8x16x3_t t, uint8x16_t idx) {
  uint8x8x4_t first = {{vget_low_u8(t.val[0]), vget_high_u8(t.val[0]),
                        vget_low_u8(t.val[1]), vget_high_u8(t.val[1])}};
  uint8x8x2_t third = {{vget_low_u8(t.val[2]), vget_high_u8(t.val[2])}};
  uint8x8_t thirty_two = vdup_n_u8(32);
  uint8x8_t lo = vget_low_u8(idx);
  uint8x8_t hi = vget_high_u8(idx);
  return vcombine_u8(vorr_u8(vtbl4_u8(first, lo), vtbl2_u8(third, vsub_u8(lo, thirty_two))),
                     vorr_u8(vtbl4_u8(first, hi), vtbl2_u8(third, vsub_u8(hi, thirty_two))));
}

REVENANT_A64_INLINE int8x16_t vqtbl3q_s8(int8x16x3_t t, uint8x16_t idx) {
  uint8x16x3_t u = {{vreinterpretq_u8_s8(t.val[0]), vreinterpretq_u8_s8(t.val[1]),
                     vreinterpretq_u8_s8(t.val[2])}};
  return vreinterpretq_s8_u8(vqtbl3q_u8(u, idx));
}

REVENANT_A64_INLINE uint8x16_t vqtbl4q_u8(uint8x16x4_t t, uint8x16_t idx) {
  uint8x8x4_t first = {{vget_low_u8(t.val[0]), vget_high_u8(t.val[0]),
                        vget_low_u8(t.val[1]), vget_high_u8(t.val[1])}};
  uint8x8x4_t second = {{vget_low_u8(t.val[2]), vget_high_u8(t.val[2]),
                         vget_low_u8(t.val[3]), vget_high_u8(t.val[3])}};
  uint8x8_t thirty_two = vdup_n_u8(32);
  uint8x8_t lo = vget_low_u8(idx);
  uint8x8_t hi = vget_high_u8(idx);
  return vcombine_u8(vorr_u8(vtbl4_u8(first, lo), vtbl4_u8(second, vsub_u8(lo, thirty_two))),
                     vorr_u8(vtbl4_u8(first, hi), vtbl4_u8(second, vsub_u8(hi, thirty_two))));
}

REVENANT_A64_INLINE int8x16_t vqtbl4q_s8(int8x16x4_t t, uint8x16_t idx) {
  uint8x16x4_t u = {{vreinterpretq_u8_s8(t.val[0]), vreinterpretq_u8_s8(t.val[1]),
                     vreinterpretq_u8_s8(t.val[2]), vreinterpretq_u8_s8(t.val[3])}};
  return vreinterpretq_s8_u8(vqtbl4q_u8(u, idx));
}

#define REVENANT_ZIP_Q(S, VT)                                                   \
REVENANT_A64_INLINE VT vzip1q_##S(VT a, VT b) { return vzipq_##S(a, b).val[0]; } \
REVENANT_A64_INLINE VT vzip2q_##S(VT a, VT b) { return vzipq_##S(a, b).val[1]; } \
REVENANT_A64_INLINE VT vuzp1q_##S(VT a, VT b) { return vuzpq_##S(a, b).val[0]; } \
REVENANT_A64_INLINE VT vuzp2q_##S(VT a, VT b) { return vuzpq_##S(a, b).val[1]; } \
REVENANT_A64_INLINE VT vtrn1q_##S(VT a, VT b) { return vtrnq_##S(a, b).val[0]; } \
REVENANT_A64_INLINE VT vtrn2q_##S(VT a, VT b) { return vtrnq_##S(a, b).val[1]; }

#define REVENANT_ZIP_D(S, VT)                                                   \
REVENANT_A64_INLINE VT vzip1_##S(VT a, VT b) { return vzip_##S(a, b).val[0]; } \
REVENANT_A64_INLINE VT vzip2_##S(VT a, VT b) { return vzip_##S(a, b).val[1]; } \
REVENANT_A64_INLINE VT vuzp1_##S(VT a, VT b) { return vuzp_##S(a, b).val[0]; } \
REVENANT_A64_INLINE VT vuzp2_##S(VT a, VT b) { return vuzp_##S(a, b).val[1]; } \
REVENANT_A64_INLINE VT vtrn1_##S(VT a, VT b) { return vtrn_##S(a, b).val[0]; } \
REVENANT_A64_INLINE VT vtrn2_##S(VT a, VT b) { return vtrn_##S(a, b).val[1]; }

REVENANT_ZIP_Q(u8, uint8x16_t)
REVENANT_ZIP_Q(s8, int8x16_t)
REVENANT_ZIP_Q(u16, uint16x8_t)
REVENANT_ZIP_Q(s16, int16x8_t)
REVENANT_ZIP_Q(u32, uint32x4_t)
REVENANT_ZIP_Q(s32, int32x4_t)
REVENANT_ZIP_Q(f32, float32x4_t)
REVENANT_ZIP_D(u8, uint8x8_t)
REVENANT_ZIP_D(s8, int8x8_t)
REVENANT_ZIP_D(u16, uint16x4_t)
REVENANT_ZIP_D(s16, int16x4_t)
REVENANT_ZIP_D(u32, uint32x2_t)
REVENANT_ZIP_D(s32, int32x2_t)
REVENANT_ZIP_D(f32, float32x2_t)

REVENANT_A64_INLINE int64x2_t vtrn1q_s64(int64x2_t a, int64x2_t b) {
  return vcombine_s64(vget_low_s64(a), vget_low_s64(b));
}
REVENANT_A64_INLINE int64x2_t vtrn2q_s64(int64x2_t a, int64x2_t b) {
  return vcombine_s64(vget_high_s64(a), vget_high_s64(b));
}
REVENANT_A64_INLINE uint64x2_t vtrn1q_u64(uint64x2_t a, uint64x2_t b) {
  return vcombine_u64(vget_low_u64(a), vget_low_u64(b));
}
REVENANT_A64_INLINE uint64x2_t vtrn2q_u64(uint64x2_t a, uint64x2_t b) {
  return vcombine_u64(vget_high_u64(a), vget_high_u64(b));
}

#define REVENANT_MOVL_HIGH(S, VT, WVT)                                          \
REVENANT_A64_INLINE WVT vmovl_high_##S(VT a) { return vmovl_##S(vget_high_##S(a)); }

REVENANT_MOVL_HIGH(u8, uint8x16_t, uint16x8_t)
REVENANT_MOVL_HIGH(s8, int8x16_t, int16x8_t)
REVENANT_MOVL_HIGH(u16, uint16x8_t, uint32x4_t)
REVENANT_MOVL_HIGH(s16, int16x8_t, int32x4_t)
REVENANT_MOVL_HIGH(u32, uint32x4_t, uint64x2_t)
REVENANT_MOVL_HIGH(s32, int32x4_t, int64x2_t)

#define REVENANT_NARROW_HIGH(FN, S, RVT, AVT, RESVT, CS)                        \
REVENANT_A64_INLINE RESVT FN##_high_##S(RVT r, AVT a) {                         \
  return vcombine_##CS(r, FN##_##S(a));                                         \
}

REVENANT_NARROW_HIGH(vmovn, u16, uint8x8_t, uint16x8_t, uint8x16_t, u8)
REVENANT_NARROW_HIGH(vmovn, s16, int8x8_t, int16x8_t, int8x16_t, s8)
REVENANT_NARROW_HIGH(vmovn, u32, uint16x4_t, uint32x4_t, uint16x8_t, u16)
REVENANT_NARROW_HIGH(vmovn, s32, int16x4_t, int32x4_t, int16x8_t, s16)
REVENANT_NARROW_HIGH(vmovn, u64, uint32x2_t, uint64x2_t, uint32x4_t, u32)
REVENANT_NARROW_HIGH(vmovn, s64, int32x2_t, int64x2_t, int32x4_t, s32)
REVENANT_NARROW_HIGH(vqmovn, u16, uint8x8_t, uint16x8_t, uint8x16_t, u8)
REVENANT_NARROW_HIGH(vqmovn, s16, int8x8_t, int16x8_t, int8x16_t, s8)
REVENANT_NARROW_HIGH(vqmovn, u32, uint16x4_t, uint32x4_t, uint16x8_t, u16)
REVENANT_NARROW_HIGH(vqmovn, s32, int16x4_t, int32x4_t, int16x8_t, s16)
REVENANT_NARROW_HIGH(vqmovn, u64, uint32x2_t, uint64x2_t, uint32x4_t, u32)
REVENANT_NARROW_HIGH(vqmovn, s64, int32x2_t, int64x2_t, int32x4_t, s32)

REVENANT_A64_INLINE uint8x16_t vqmovun_high_s16(uint8x8_t r, int16x8_t a) {
  return vcombine_u8(r, vqmovun_s16(a));
}
REVENANT_A64_INLINE uint16x8_t vqmovun_high_s32(uint16x4_t r, int32x4_t a) {
  return vcombine_u16(r, vqmovun_s32(a));
}
REVENANT_A64_INLINE uint32x4_t vqmovun_high_s64(uint32x2_t r, int64x2_t a) {
  return vcombine_u32(r, vqmovun_s64(a));
}

#define REVENANT_MULL_HIGH(S, VT, WVT)                                          \
REVENANT_A64_INLINE WVT vmull_high_##S(VT a, VT b) {                            \
  return vmull_##S(vget_high_##S(a), vget_high_##S(b));                         \
}

#define REVENANT_MLAL_HIGH(S, VT, WVT)                                          \
REVENANT_A64_INLINE WVT vmlal_high_##S(WVT acc, VT a, VT b) {                   \
  return vmlal_##S(acc, vget_high_##S(a), vget_high_##S(b));                    \
}

REVENANT_MULL_HIGH(s8, int8x16_t, int16x8_t)
REVENANT_MULL_HIGH(u8, uint8x16_t, uint16x8_t)
REVENANT_MULL_HIGH(s16, int16x8_t, int32x4_t)
REVENANT_MULL_HIGH(u16, uint16x8_t, uint32x4_t)
REVENANT_MULL_HIGH(s32, int32x4_t, int64x2_t)
REVENANT_MULL_HIGH(u32, uint32x4_t, uint64x2_t)

REVENANT_MLAL_HIGH(s8, int8x16_t, int16x8_t)
REVENANT_MLAL_HIGH(u8, uint8x16_t, uint16x8_t)
REVENANT_MLAL_HIGH(s16, int16x8_t, int32x4_t)
REVENANT_MLAL_HIGH(u16, uint16x8_t, uint32x4_t)
REVENANT_MLAL_HIGH(s32, int32x4_t, int64x2_t)
REVENANT_MLAL_HIGH(u32, uint32x4_t, uint64x2_t)

REVENANT_A64_INLINE int64x1_t vneg_s64(int64x1_t a) {
  return vsub_s64(vdup_n_s64(0), a);
}

REVENANT_A64_INLINE int64x2_t vnegq_s64(int64x2_t a) {
  return vsubq_s64(vdupq_n_s64(0), a);
}

REVENANT_A64_INLINE int64x1_t vabs_s64(int64x1_t a) {
  int64x1_t sign = vshr_n_s64(a, 63);
  return vsub_s64(veor_s64(a, sign), sign);
}

REVENANT_A64_INLINE int64x2_t vabsq_s64(int64x2_t a) {
  int64x2_t sign = vshrq_n_s64(a, 63);
  return vsubq_s64(veorq_s64(a, sign), sign);
}

REVENANT_A64_INLINE uint16x8_t vcltzq_s16(int16x8_t a) {
  return vcltq_s16(a, vdupq_n_s16(0));
}

REVENANT_A64_INLINE uint64x2_t vcltzq_s64(int64x2_t a) {
  return vreinterpretq_u64_s64(vshrq_n_s64(a, 63));
}

#define vdupq_laneq_s16(v, lane) vdupq_n_s16(vgetq_lane_s16((v), (lane)))

#endif
