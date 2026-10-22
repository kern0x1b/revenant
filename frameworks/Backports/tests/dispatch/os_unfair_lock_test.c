#include <os/lock.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
static long counter;

static void *increment(void *unused)
{
    for (int i = 0; i < 100000; i++) {
        os_unfair_lock_lock(&lock);
        counter++;
        os_unfair_lock_unlock(&lock);
    }
    return NULL;
}

static void double_lock(void)
{
    os_unfair_lock_lock(&lock);
    os_unfair_lock_lock(&lock);
}

static void unlock_unowned(void)
{
    os_unfair_lock_unlock(&lock);
}

static void assert_owner_unowned(void)
{
    os_unfair_lock_assert_owner(&lock);
}

static void assert_not_owner_owned(void)
{
    os_unfair_lock_lock(&lock);
    os_unfair_lock_assert_not_owner(&lock);
}

static const char *aborts(void (*operation)(void))
{
    pid_t pid = fork();
    if (pid == 0) {
        operation();
        _exit(0);
    }
    int status = 0;
    waitpid(pid, &status, 0);
    if (WIFSIGNALED(status))
        return "terminates";
    return "returns";
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    printf("trylock unowned: %d\n", os_unfair_lock_trylock(&lock));
    printf("trylock owned by self: %d\n", os_unfair_lock_trylock(&lock));
    os_unfair_lock_assert_owner(&lock);
    os_unfair_lock_unlock(&lock);
    os_unfair_lock_assert_not_owner(&lock);

    pthread_t threads[4];
    for (int i = 0; i < 4; i++)
        pthread_create(&threads[i], NULL, increment, NULL);
    for (int i = 0; i < 4; i++)
        pthread_join(threads[i], NULL);
    printf("counter: %ld\n", counter);

    printf("double lock: %s\n", aborts(double_lock));
    printf("unlock unowned: %s\n", aborts(unlock_unowned));
    printf("assert owner when unowned: %s\n", aborts(assert_owner_unowned));
    printf("assert not owner when owned: %s\n", aborts(assert_not_owner_owned));
    return 0;
}
