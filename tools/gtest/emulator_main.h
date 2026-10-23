#ifndef REVENANT_TOOLS_GTEST_EMULATOR_MAIN_H_
#define REVENANT_TOOLS_GTEST_EMULATOR_MAIN_H_

// Emulator runs take no arguments: the emulator boots the test binary as pid 1, so the filter
// comes from a file in the guest. Call this before InitGoogleTest in a test binary's main.
void ApplyEmulatorGtestFilter();

#endif  // REVENANT_TOOLS_GTEST_EMULATOR_MAIN_H_
