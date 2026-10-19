#import <Foundation/Foundation.h>

void fuzz_start(int argc, char **argv, int *rounds);
uint32_t fuzz_roll(uint32_t below);
void fuzz_compare(NSString *category, NSString *what, NSString *system, NSString *port);
int fuzz_finish(void);
