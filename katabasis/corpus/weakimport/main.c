#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

// Three weak imports, and what each answers once translated. getppid and execl exist on iOS 6, so a native build
// says "present" for both and so must the translated one; os_unfair_lock_lock is absent from iOS 6 itself, so absent
// is what a native build says too. check.sh builds this file both ways and runs both on the device.
extern int getppid(void) __attribute__((weak_import));
extern int execl(const char *, const char *, ...) __attribute__((weak_import));
extern void os_unfair_lock_lock(void *) __attribute__((weak_import));

static void failed(const char *what, int result) {
  printf("%s %d %s\n", what, result, errno == ENOENT ? "ENOENT" : "other");
}

// A form that succeeds replaces the process, so each runs in a child that prints through a shell what arrived, and the
// parent reports how the child ended.
static void spawned(const char *what, void (*exec_it)(void)) {
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0) {
    exec_it();
    _exit(127);
  }
  int status = 0;
  waitpid(pid, &status, 0);
  printf("%s exited %d\n", what, WIFEXITED(status) ? WEXITSTATUS(status) : -1);
}

static void run_execv(void) {
  char *argv[] = {"sh", "-c", "echo execv $0 $1", "a", "b", 0};
  execv("/bin/sh", argv);
}
static void run_execvp(void) {
  char *argv[] = {"sh", "-c", "echo execvp $0 $1", "a", "b", 0};
  execvp("sh", argv);
}
static void run_execvP(void) {
  char *argv[] = {"sh", "-c", "echo execvP $0 $1", "a", "b", 0};
  execvP("sh", "/nonexistent:/bin", argv);
}
static void run_execlp(void) { execlp("sh", "sh", "-c", "echo execlp $0 $1", "a", "b", (char *)0); }

int main(void) {
  char *argv[] = {"x", "y", 0};
  char *envp[] = {"FOO=env", 0};
  printf("getppid %s\n", getppid ? "present" : "absent");
  printf("execl %s\n", execl ? "present" : "absent");
  printf("os_unfair_lock_lock %s\n", os_unfair_lock_lock ? "present" : "absent");
  // Each form of exec fails on a missing file with -1 and ENOENT, and comes back.
  failed("execl", execl("/var/nonexistent/xl", "x", "y", (char *)0));
  failed("execle", execle("/var/nonexistent/xl", "x", "y", (char *)0, envp));
  failed("execlp", execlp("nonexistent-xl", "x", "y", (char *)0));
  failed("execv", execv("/var/nonexistent/xl", argv));
  failed("execve", execve("/var/nonexistent/xl", argv, envp));
  failed("execvp", execvp("nonexistent-xl", argv));
  failed("execvP", execvP("nonexistent-xl", "/var/nonexistent", argv));
  spawned("execv", run_execv);
  spawned("execvp", run_execvp);
  spawned("execvP", run_execvP);
  spawned("execlp", run_execlp);
  // And one that succeeds replaces this process with a shell that shows what arrived: the arguments after the list's
  // first, and the environment.
  fflush(stdout);
  execle("/bin/sh", "sh", "-c", "echo $0 $1 $FOO", "arg0", "arg1", (char *)0, envp);
  printf("execle returned\n");
  return 1;
}
