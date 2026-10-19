// An executable that calls getppid without checking, next to a library that does check.
extern int getppid(void);
extern int weak_user(void);
int main(void) { return getppid() + weak_user(); }
