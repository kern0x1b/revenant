extern int getppid(void);
extern int weak_user(void);
int main(void) { return getppid() + weak_user(); }
