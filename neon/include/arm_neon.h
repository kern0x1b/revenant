#ifndef REVENANT_NEON_ARM_NEON_H_
#define REVENANT_NEON_ARM_NEON_H_

#include_next <arm_neon.h>

#if !defined(__aarch64__)
#include "revenant_neon_a64.h"
#endif

#endif  // REVENANT_NEON_ARM_NEON_H_
