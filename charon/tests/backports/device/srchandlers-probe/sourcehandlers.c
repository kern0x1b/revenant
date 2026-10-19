/* What the release itself does with a barrier source's cancellation and registration handlers, and what
   it does with a barrier EVENT handler, on the emulated iPhone3,1 at 6.1.3 (10B329). One scenario per
   process.

   Two measured facts about that release are what this program is for.

   1. libdispatch-228 already runs a cancellation and a registration handler alone on a concurrent target
      queue. The shims that used to stand beside these readings are withdrawn - they answered alone=yes
      where the release already answers alone=yes, and the step where they take the handler off the
      source ends the process on signal 5 here - so no shim of the cancellation or registration kind is in
      the binary at all, and `nm` in run.sh checks that next to the LC_UUID gate. This program builds from
      origin/main.
   2. The barrier EVENT handler's shim is on origin/main and is measured here beside the release's own
      call, in the shim and system columns: the event cases carry both, the cancellation and registration
      cases only the system's. The event handler is the one handler a source really runs, so its reading
      does not depend on a call that has to take a handler off a source first - which is the step that is
      fatal here.

   The case body, the line format and the readings are those of tests/compat_test.py's
   DISPATCH_SOURCE_HANDLERS, so the guest's answers can be laid beside the host's field by field; what
   is gone is the second column, which is why this file is its own program and not a copy of that one.

   Two things about this guest are measured, not assumed, and both are why it is driven the way it is:

     - `xmake emulate run` takes a bare path. A command with words after the path comes back
       `fail(spawn error 2)`, and the program is run with argc == 1 and nothing else: measured 2026-10-04
       with the same binary installed by the same deb, `/usr/libexec/sourcehandlers` prints
       `argc=1 argv0=/usr/libexec/sourcehandlers` while `/usr/libexec/sourcehandlers cancel concurrent
       system` never starts. So the scenario cannot be named on the command line here.
     - fork works. A child that does nothing, that prints, that makes a queue, that makes a barrier block,
       that makes a source and reads a record off it and that runs a dispatch_async and waits for it all
       exit 0 on this release; measured 2026-10-04, the six children in main's first loop. So with no
       arguments the process forks one child per scenario, which is what one scenario per process needs.

   The line is what the harness's parse() reads, so the keys are the same and in the same order.

   A scenario whose child ends on a signal says so, and names the signal: WEXITSTATUS of a signalled child
   is 0, so a probe that reads only the exit status reports a clean end for a process that died. */

#include <Block.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include "dispatch_source_state.h"

/* Cases, and what each asks of the target queue:

     cancel         a barrier cancellation handler, the source resumed, then cancelled.
     registration   a barrier registration handler, then resumed: the resume is what runs it.
     neverresumed   a barrier cancellation handler on a source that was never resumed, then cancelled.
     retargetbefore the source is made on one queue and handed another before the handler is set.
     retargetafter  the handler is set on one queue and the source handed another before the cancel.
     onqueue        the call is made from a block already running on the source's own target queue.
     resumecancel   a registration handler and a cancellation handler on one source, resumed and then
                    cancelled from off the queue, and the order the two ran in read out. gapMs is the wait
                    between the two calls, and it is a parameter because the release's own answer at gap 0
                    is a race and not a rule: measured on the host, gap 0 answers C alone and gap 1 answers
                    RC, because the resume submits the registration handler to the target queue and
                    returns, and a cancel that arrives before that submission has run discards it. The
                    guest asks it at 50 ms, which is where the host settles to RC on both widths.

   Every case but onqueue and resumecancel puts a block on the target queue that records that it started and
   does not return until told, so three things can be read:
     held   the call under test returned while that block was still running - that is, it did not wait
     ran    the handler ran at all, read after the holder has been let go and the call has been joined
     alone  the handler entered while that block was no longer running - that is, it ran alone, which a
            barrier queue gives and an ordinary one does not
   and second is which of the two queues the handler ran on, read from a specific this program puts on each
   queue with the call that names it (dispatch_queue_set_specific, iOS 5 and later, and not deprecated at
   any of this repository's deployment targets: measured 2026-10-04, compiling this file for
   armv7-apple-ios6.1.3 with -Wall -Wdeprecated-declarations and no diagnostic). The second queue is made
   the same width as the first, so "alone" means the same thing in every row.

   The onqueue case has no separate holder: the block that holds the target queue is the block the call is
   made from, which is the whole point of it, so "held" would be meaningless and what is read is whether
   the call returns at all. The holder signals a semaphore of its own when the call has returned and never
   the handler's, so the handler's answer cannot be the holder's.

   The call under test is made on a thread of its own and joined where there is a holder, so nothing here
   can hang the run, and nothing is released under a call that is still in it. Not a fork per scenario:
   the fork is in main, before any queue exists, so a child inherits no thread pool and creates its own -
   which is the whole reason a scenario is worth a process of its own, since a case recorded in another's
   answer is not an answer. The source is never released either, because libdispatch traps on releasing a
   source that was never resumed and neverresumed asks about one.

   Every call below is the release's own, named as the SDK names it, and nothing renames it for this
   program: the guest project compiles what it links exactly as packages/a/apple-compat/xmake.lua
   compiles it, one plain `clang -Os -fvisibility=hidden -c` with no forced include of the renaming
   headers. A forced include is what an IMAGE gets, so that the calls in the image bind to a shim; it
   must not reach a shim's own translation unit either, or the shim's call to the release is the shim
   again, and it must not reach this program, or these readings would be the shims' and not the
   release's. run.sh's nm gate checks that no plain dispatch name is claimed by the binary at all.

   The handler is made through dispatch_block_create with DISPATCH_BLOCK_BARRIER, which on this release is
   this package's own call: dispatch_block_create arrived in iOS 8, and this package's reads the release's
   when there is one and makes the block itself when there is not, which is what puts the barrier bit
   where its own dispatch_block.h can read it. A plain block literal carries no such bit, so a caller on
   this release that wants a barrier block has to make it this way - and the question this program asks
   is what the release does with such a handler when nobody has renamed anything for it. */

static volatile int holderInside;
static volatile int handlerAlone;
static volatile int handlerRan;
static volatile int handlerOnSecond;
static volatile int returned;
/* Which of the two handlers ran, and in which order, for the resumecancel case. A block literal cannot
   capture a char array, so both handlers append to this one. */
static char order[8];

/* The two shims of the barrier event handler, both on origin/main, reached by the names their headers
   carry and not by any plain dispatch name - `nm` in run.sh lists what the binary claims. The resume is
   the shim's too in that column, because the shim's setter asks the activation record its own resume
   writes and would otherwise hand the handler to the release as it is. */
void charon_dispatch_resume(dispatch_object_t);
void charon_dispatch_source_set_event_handler(dispatch_source_t, dispatch_block_t);

static int useSystem;
static int registration;
static int never;
static int onQueue;
static int resumeCancel;
static int ordinaryAsync;
static int eventCase;
static int eventAfterResume;
static int ordinaryEvent;
static dispatch_source_t source;
static dispatch_queue_t second;
static dispatch_queue_t held;
static dispatch_semaphore_t entered;
static dispatch_semaphore_t release;
static dispatch_semaphore_t handlerDone;
static dispatch_block_t handler;
static const char *width;
/* Where an answer goes. It is stdout when this program is run with a scenario named on the command line,
   and it is the writing end of a pipe when it is run on this guest with no arguments at all: a forked
   child's writes to this guest's standard output do not reach the runner's capture, which is measured - on
   2026-10-04 twelve children each printed exactly one line and exited 0, and every one of the parent's own
   lines arrived while not one of theirs did. So the child answers through a pipe and the parent, whose own
   output does arrive, reads it and prints it. */
static FILE *answers;

static void tag(dispatch_queue_t queue, const void *value)
{
    /* dispatch_queue_set_specific is what names the queue a block runs on. */
    dispatch_queue_set_specific(queue, (const void *)0x636861726f6e51u, (void *)value, NULL);
}

static void *where(void)
{
    return dispatch_get_specific((const void *)0x636861726f6e51u);
}

static void *make_source(dispatch_queue_t queue)
{
    return dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
}

static void set_cancel(dispatch_source_t target, dispatch_block_t handler)
{
    dispatch_source_set_cancel_handler(target, handler);
}

static void set_registration(dispatch_source_t target, dispatch_block_t handler)
{
    dispatch_source_set_registration_handler(target, handler);
}

static void retarget(dispatch_object_t target, dispatch_queue_t queue)
{
    dispatch_set_target_queue(target, queue);
}

static void resume_it(dispatch_object_t target)
{
    if (useSystem)
        dispatch_resume(target);
    else
        charon_dispatch_resume(target);
}

static void cancel_it(dispatch_source_t target)
{
    dispatch_source_cancel(target);
}

/* What every handler here records when it runs, so a source's cancellation handler, its registration
   handler and its event handler, and the ordinary block of the control, are all read the same way. */
static void note_handler_ran(void)
{
    handlerAlone = holderInside ? 0 : 1;
    handlerRan = 1;
    handlerOnSecond = where() == (void *)2 ? 1 : 0;
    if (resumeCancel) {
        size_t length = strlen(order);
        if (length + 1 < sizeof order) {
            order[length] = 'C';
            order[length + 1] = 0;
        }
    }
    dispatch_semaphore_signal(handlerDone);
}

static void set_event(dispatch_source_t target, dispatch_block_t handler)
{
    if (useSystem)
        dispatch_source_set_event_handler(target, handler);
    else
        charon_dispatch_source_set_event_handler(target, handler);
}

static void call_under_test(void)
{
    if (registration)
        resume_it(source);
    else
        cancel_it(source);
    returned = 1;
}

/* The control for the ordinaryasync case: an ordinary block submitted to the target queue, from a thread of
   its own, where every other case puts a source's handler there. `held` and `handlerDone` are file scope
   because a block literal cannot capture them out of the function that made them, and this program runs
   one scenario per process anyway. */
static void *ordinary_runner(void *ignored)
{
    (void)ignored;
    dispatch_async(held, ^{
        handlerAlone = holderInside ? 0 : 1;
        handlerRan = 1;
        dispatch_semaphore_signal(handlerDone);
    });
    returned = 1;
    return NULL;
}

static void *runner(void *ignored)
{
    (void)ignored;
    call_under_test();
    return NULL;
}

static void say(const char *which, const char *held, const char *ran)
{
    fprintf(answers, "%s %s %s: held=%s ran=%s alone=%s second=%s returned=%s order=%s\n", which, width,
            useSystem ? "system" : "shim", held, ran,
            handlerAlone < 0 ? "n/a" : (handlerAlone ? "yes" : "no"),
            handlerOnSecond < 0 ? "n/a" : (handlerOnSecond ? "yes" : "no"),
            returned ? "yes" : "no", order[0] ? order : "-");
}

/* A source's EVENT handler, which is the handler a source really runs. The source is a timer set to fire
   every 50 ms, the holder is put in the target queue first and left there across the resume, and the
   handler is waited for while that block is still running - which is what makes alone readable here: a
   handler that runs in that time ran BESIDE the holder, and one that does not has to wait for it. The
   width of the answer is the whole question for a barrier event handler, and the case exists on both.

   eventafresume is the second configuration the shim decides: a handler set after the source's first
   resume, which libdispatch-703 reads no barrier bit for. The timer is set before the resume either way,
   because dispatch_resume on a timer source with no interval set is a client error. */
static int event_scenario(const char *which)
{
    dispatch_source_set_timer(source, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC),
                              DISPATCH_TIME_FOREVER, 50 * NSEC_PER_MSEC);
    dispatch_async(held, ^{
        holderInside = 1;
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
        holderInside = 0;
    });
    dispatch_semaphore_wait(entered, DISPATCH_TIME_FOREVER);
    if (eventAfterResume) {
        resume_it(source);
        returned = 1;
        set_event(source, handler);
    } else {
        set_event(source, handler);
        resume_it(source);
        returned = 1;
    }
    long ranWhileHeld = dispatch_semaphore_wait(handlerDone, dispatch_time(DISPATCH_TIME_NOW, 1500 * NSEC_PER_MSEC));
    if (ranWhileHeld != 0) {
        dispatch_semaphore_signal(release);
        dispatch_semaphore_wait(handlerDone, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
    }
    say(which, "n/a", handlerRan ? "yes" : "no");
    return 0;
}

/* One scenario, named by its arguments because this guest names nothing on the command line: main forks
   one child per scenario and calls this in the child. The gap is the wait resumecancel leaves between
   its two calls. */
static int scenario(const char *which, int isSerial, int api, int gapMs)
{
    width = isSerial ? "serial" : "concurrent";
    useSystem = !api;
    registration = strcmp(which, "registration") == 0;
    never = strcmp(which, "neverresumed") == 0;
    int retargetBefore = strcmp(which, "retargetbefore") == 0;
    int retargetAfter = strcmp(which, "retargetafter") == 0;
    onQueue = strcmp(which, "onqueue") == 0;
    resumeCancel = strcmp(which, "resumecancel") == 0;
    ordinaryAsync = strcmp(which, "ordinaryasync") == 0;
    eventAfterResume = strcmp(which, "eventafresume") == 0;
    ordinaryEvent = strcmp(which, "ordinaryevent") == 0;
    eventCase = ordinaryEvent || eventAfterResume || strcmp(which, "event") == 0;

    holderInside = 0;
    handlerAlone = -1;
    handlerRan = 0;
    handlerOnSecond = -1;
    returned = 0;
    order[0] = 0;

    dispatch_queue_attr_t attr = strcmp(width, "serial") == 0 ? DISPATCH_QUEUE_SERIAL : DISPATCH_QUEUE_CONCURRENT;
    dispatch_queue_t queue = dispatch_queue_create("target", attr);
    second = dispatch_queue_create("second", attr);
    tag(queue, (const void *)1);
    tag(second, (const void *)2);
    source = (dispatch_source_t)make_source(queue);
    int firstIsTarget = 1;

    entered = dispatch_semaphore_create(0);
    release = dispatch_semaphore_create(0);
    handlerDone = dispatch_semaphore_create(0);
    /* ordinaryEvent is the control and gets a plain block literal: on this release the release's own
       libdispatch reads no block's flags, so a block literal is exactly what a caller here hands to
       dispatch_source_set_event_handler, and the shim's own test for a barrier block reads the bit this
       package's dispatch_block_create puts there. */
    /* Block_copy is this package's own public call on a block and lives in <Block.h>, which this file
       includes for it: it used to arrive through dispatch_source_state.h, which carried the include for
       the records those blocks belonged to, and that header no longer does. Measured 2026-10-04: with the
       include only transitive, building this file on a tree without those records ends at
       "call to undeclared function 'Block_copy'" and the probe does not build at all. */
    handler = ordinaryEvent ? Block_copy(^{ note_handler_ran(); })
                            : dispatch_block_create(DISPATCH_BLOCK_BARRIER, ^{ note_handler_ran(); });

    held = queue;
    if (eventCase)
        return event_scenario(which);

    if (retargetBefore) {
        retarget(source, second);
        firstIsTarget = 0;
    }
    if (registration) {
        set_registration(source, handler);
    } else {
        set_cancel(source, handler);
        /* resumecancel makes the resume itself, with a cancel straight after it, and a second resume on a
           running source traps in _dispatch_lane_resume. */
        if (!never && !resumeCancel)
            resume_it(source);
    }
    if (retargetAfter) {
        retarget(source, second);
        firstIsTarget = 0;
    }
    if (resumeCancel) {
        dispatch_block_t registration_handler = dispatch_block_create(DISPATCH_BLOCK_BARRIER, ^{
            size_t length = strlen(order);
            if (length + 1 < sizeof order) {
                order[length] = 'R';
                order[length + 1] = 0;
            }
        });
        set_registration(source, registration_handler);
        set_cancel(source, handler);
        resume_it(source);
        if (gapMs > 0)
            usleep((useconds_t)gapMs * 1000);
        cancel_it(source);
        for (int waited = 0; waited < 3000 && strlen(order) < 2; waited++)
            usleep(1000);
        say(which, "n/a", strlen(order) > 1 ? "yes" : "no");
        return 0;
    }

    held = firstIsTarget ? queue : second;
    if (onQueue) {
        dispatch_semaphore_t callReturned = dispatch_semaphore_create(0);
        dispatch_async(held, ^{
            holderInside = 1;
            dispatch_semaphore_signal(entered);
            dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
            holderInside = 0;
            call_under_test();
            dispatch_semaphore_signal(callReturned);
        });
        dispatch_semaphore_wait(entered, DISPATCH_TIME_FOREVER);
        dispatch_semaphore_signal(release);
        long called = dispatch_semaphore_wait(callReturned, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
        dispatch_semaphore_wait(handlerDone, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
        say(which, "n/a", handlerRan ? "yes" : "no");
        return called ? 1 : 0;
    }

    dispatch_async(held, ^{
        holderInside = 1;
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
        holderInside = 0;
    });
    dispatch_semaphore_wait(entered, DISPATCH_TIME_FOREVER);

    /* The control every `alone` reading on this guest is read against: the same holder in the same target
       queue, and an ORDINARY block submitted to it where every other case submits a source's handler. An
       ordinary block on a concurrent queue runs beside the holder, so this answers alone=no; if it answered
       alone=yes then this queue runs one block at a time and `alone` would say nothing about a barrier on
       this guest, in either column. */
    pthread_t thread;
    pthread_create(&thread, NULL, ordinaryAsync ? ordinary_runner : runner, NULL);
    for (int waited = 0; waited < 2000 && !returned; waited++)
        usleep(1000);
    int returnedWhileHeld = returned;
    dispatch_semaphore_signal(release);
    pthread_join(thread, NULL);
    long ranLater = dispatch_semaphore_wait(handlerDone, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
    say(which, returnedWhileHeld ? "yes" : "no", (ranLater == 0 || handlerRan) ? "yes" : "no");
    return 0;
}

/* What this guest can be asked to do, one child each, before any scenario runs. The fork below is the
   whole reason this program can measure one scenario per process here, so it is measured rather than
   assumed: a child that makes a queue, that makes a barrier block, that makes a source and reads a
   record off it, and whose dispatch_async runs, all exit 0 on this release - measured 2026-10-04, and
   re-measured by every run of this program. If one of them ever does not, the fork is no longer sound
   and the scenario answers after it are worth nothing, so the failure is printed and not swallowed. */
static void child_nothing(void) {}
static void child_prints(void) { printf("a child reached its own first statement\n"); }
static void child_queue(void)
{
    dispatch_queue_t made = dispatch_queue_create("probe", DISPATCH_QUEUE_CONCURRENT);
    printf("a child made a queue: %s\n", made ? "yes" : "NO");
}
static void child_block(void)
{
    dispatch_block_t made = dispatch_block_create(DISPATCH_BLOCK_BARRIER, ^{ printf("the barrier block ran\n"); });
    printf("a child made a barrier block: %s\n", made ? "yes" : "NO");
}
static void child_source(void)
{
    dispatch_queue_t queue = dispatch_queue_create("probe", DISPATCH_QUEUE_CONCURRENT);
    dispatch_source_t made = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    printf("a child made a source: %s, and read a record off it: %s\n", made ? "yes" : "NO",
           charon_dispatch_is_object(made) ? "readable" : "NOT READABLE");
}
static void child_async(void)
{
    dispatch_queue_t queue = dispatch_queue_create("probe", DISPATCH_QUEUE_CONCURRENT);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(queue, ^{ dispatch_semaphore_signal(done); });
    long got = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
    printf("a child ran a dispatch_async and waited for it: %s\n", got ? "NO" : "yes");
}

static void check_guest(void)
{
    static const struct {
        const char *what;
        void (*body)(void);
    } checks[] = {
        {"a child that does nothing", child_nothing},
        {"a child that prints", child_prints},
        {"a child that makes a queue", child_queue},
        {"a child that makes a barrier block", child_block},
        {"a child that makes a source and reads a record off it", child_source},
        {"a child whose dispatch_async runs", child_async},
    };
    for (unsigned i = 0; i < sizeof checks / sizeof checks[0]; i++) {
        fflush(stdout);
        pid_t child = fork();
        if (child == 0) {
            checks[i].body();
            fflush(stdout);
            _exit(0);
        }
        if (child < 0) {
            printf("guest %s: FORK FAILED\n", checks[i].what);
            continue;
        }
        int status = 0;
        waitpid(child, &status, 0);
        if (WIFSIGNALED(status))
            printf("guest %s: ENDED ON SIGNAL %d (%s)\n", checks[i].what, WTERMSIG(status),
                   strsignal(WTERMSIG(status)));
        else if (!WIFEXITED(status) || WEXITSTATUS(status) != 0)
            printf("guest %s: ENDED status=%d\n", checks[i].what, WEXITSTATUS(status));
        else
            printf("guest %s: ok\n", checks[i].what);
    }
}

/* The one place the two hosts differ, so it is here and not scattered through the program: on the host
   the arguments name the scenario and this runs once, answering on stdout; on this guest there are none, so
   one child per scenario is forked, the child answers on a pipe and this reads it back and prints it.
   WEXITSTATUS of a signalled child is 0, so a child's status is read with WIFSIGNALED and WTERMSIG, and a
   child that died is reported as the signal it died of rather than as a clean end. The fork is before any
   queue exists, so a child inherits no thread pool and creates its own, and it exits with _exit because the
   atexit handlers of a forked child are not this child's to run. */
int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    answers = stdout;
    printf("the guest reports %ld processors, and OS_dispatch_source is %s\n",
           sysconf(_SC_NPROCESSORS_ONLN), objc_getClass("OS_dispatch_source") ? "present" : "ABSENT");
    check_guest();

    static const char *cases[] = {"cancel", "registration", "neverresumed", "retargetbefore",
                                  "retargetafter", "onqueue", "resumecancel", "ordinaryasync"};
    /* The event cases, which are the ones asked of both columns: the release's own
       dispatch_source_set_event_handler, and the shim origin/main carries for it. Every other case is
       only the release's, because the shims those measured are withdrawn. */
    static const char *eventCases[] = {"event", "eventafresume", "ordinaryevent"};
    static const struct {
        const char **names;
        unsigned count;
        int bothColumns;
    } groups[] = {{cases, sizeof cases / sizeof cases[0], 0},
                  {eventCases, sizeof eventCases / sizeof eventCases[0], 1}};
    for (unsigned g = 0; g < sizeof groups / sizeof groups[0]; g++) {
        for (unsigned c = 0; c < groups[g].count; c++) {
            for (int serial = 0; serial < 2; serial++) {
                for (int api = 0; api < (groups[g].bothColumns ? 2 : 1); api++) {
                    const char *name = groups[g].names[c];
                    int ends[2];
                    if (pipe(ends) != 0) {
                        printf("%s %s: PIPE FAILED\n", name, serial ? "serial" : "concurrent");
                        continue;
                    }
                    fflush(stdout);
                    pid_t child = fork();
                    if (child == 0) {
                        close(ends[0]);
                        answers = fdopen(ends[1], "w");
                        if (answers)
                            setvbuf(answers, NULL, _IONBF, 0);
                        int code = scenario(name, serial, api, 50);
                        if (answers)
                            fflush(answers);
                        _exit(code);
                    }
                    close(ends[1]);
                    if (child < 0) {
                        close(ends[0]);
                        printf("%s %s: FORK FAILED\n", name, serial ? "serial" : "concurrent");
                        continue;
                    }
                    int status = 0;
                    waitpid(child, &status, 0);
                    /* What the child answered, read to the end of its pipe: a child that ended on a signal
                       has closed it, so this is empty for one, which is how "no answer" is told from an
                       answer. */
                    FILE *reader = fdopen(ends[0], "r");
                    char line[512];
                    if (reader) {
                        while (fgets(line, sizeof line, reader))
                            fputs(line, stdout);
                        fclose(reader);
                    }
                    close(ends[0]);
                    if (WIFSIGNALED(status))
                        printf("%s %s %s: CHILD ENDED ON SIGNAL %d (%s), no answer\n", name,
                               serial ? "serial" : "concurrent", api ? "shim" : "system",
                               WTERMSIG(status), strsignal(WTERMSIG(status)));
                    else if (!WIFEXITED(status) || WEXITSTATUS(status) != 0)
                        printf("%s %s %s: CHILD ENDED status=%d\n", name,
                               serial ? "serial" : "concurrent", api ? "shim" : "system",
                               WEXITSTATUS(status));
                }
            }
        }
    }
    return 0;
}