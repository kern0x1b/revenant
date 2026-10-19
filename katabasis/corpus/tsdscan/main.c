// corpus/tsdscan: a control for xlate's own build-time TSD-offset scan (xlate/src/tsd_scan.cpp),
// which backs coordination/crutches.md's "TPIDRRO_EL0 backed by a mostly-zero block" entry: this
// is what makes that entry's measurement provably scoped rather than a one-time claim by hand.
// Each case below is emitted as one inline asm block on purpose (fixed registers, clobbered
// explicitly) so nothing the compiler could insert -- a spill, a reload -- lands between the
// instructions, and every helper is a separate, unstripped, non-inlined symbol so xlate's refusal
// message can name it.
//
// Built twice by check.sh, from this one file, at -DTSD_OFFSET:
//   0x358  Swift's __PTK_FRAMEWORK_SWIFT_KEY7 (slot 107 * 8), the one offset runtime/runtime.c's
//          fake TSD block is sized and zeroed for: xlate must accept this build.
//   0x40   an offset nothing has ever measured a guest touching: xlate must refuse to build it,
//          naming every function below.
//
// The three cases are the three shapes the scanner has to catch, and each one was a measured false
// negative of an earlier revision of it:
//   read_tsd_slot      straight-line mrs then a fixed-offset load.
//   dead_path_clobber  the load's register is clobbered on ONE arm of a branch, in address order
//                      between the mrs and the load. A sweep in address order clears the tracking
//                      there and misses the access, which the taken arm reaches with the base
//                      still live. It needs a block graph with a join, not a linear pass.
//   callee_reads_tsd   the base crosses a real call in a callee-saved register (x24) and the
//                      callee reads it with no mrs of its own. A per-function analysis cannot see
//                      it; the ABI says x19-x28 survive, so this needs propagation across calls.
#ifndef TSD_OFFSET
#error "build with -DTSD_OFFSET=0x358 (must pass) or another offset, e.g. 0x40 (must fail)"
#endif

__attribute__((noinline)) unsigned long read_tsd_slot(void) {
  unsigned long value;
  __asm__ volatile(
      "mrs x9, TPIDRRO_EL0\n\t"
      "ldr %0, [x9, %1]\n\t"
      : "=r"(value)
      : "i"(TSD_OFFSET)
      : "x9");
  return value;
}

// The branch is on x10, NOT on the base register, and that is the whole point: a scanner that
// flags "the base is used in a form it does not model" gets a loud (if wrong) failure here for
// free, which is not the miss this case is about. x10 is 1, so the branch is always taken, the
// clobber below is dead, and the load really does read the base -- the program's behaviour is
// ordinary, only a sweep in address order is wrong about it.
__attribute__((noinline)) unsigned long dead_path_clobber(void) {
  unsigned long value;
  __asm__ volatile(
      "mrs x9, TPIDRRO_EL0\n\t"
      "mov x10, #1\n\t"
      "cbnz x10, 1f\n\t"
      "mov x9, x0\n\t"
      "1:\n\t"
      "ldr %0, [x9, %1]\n\t"
      : "=r"(value)
      : "i"(TSD_OFFSET)
      : "x9", "x10", "cc");
  return value;
}

__attribute__((noinline)) unsigned long callee_reads_tsd(void) {
  unsigned long value;
  __asm__ volatile(
      "ldr %0, [x24, %1]\n\t"
      : "=r"(value)
      : "i"(TSD_OFFSET)
      : "x24", "memory");
  return value;
}

__attribute__((noinline)) unsigned long callee_saved_handoff(void) {
  unsigned long value;
  __asm__ volatile(
      "mrs x24, TPIDRRO_EL0\n\t"
      "bl _callee_reads_tsd\n\t"
      : "=r"(value)
      :
      : "x24", "memory");
  return value;
}

int main(void) {
  return (int)(read_tsd_slot() + dead_path_clobber() + callee_saved_handoff());
}