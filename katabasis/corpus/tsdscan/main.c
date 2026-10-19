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
