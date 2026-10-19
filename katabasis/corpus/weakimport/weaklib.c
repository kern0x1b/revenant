// A library that checks for getppid before it calls it.
extern int getppid(void) __attribute__((weak_import));
int weak_user(void) { return getppid ? getppid() : 0; }
