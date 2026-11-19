#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>

#include "protocol.h"

extern char **environ;

#define RAW(text) text, sizeof text - 1

struct helper {
    pid_t pid;
    int to;
    int from;
    struct rc_reader reader;
};

struct line {
    char *raw;
    size_t raw_length;
    int count;
    char *fields[RC_FIELDS_MOST];
    size_t lengths[RC_FIELDS_MOST];
    double at;
};

static const char *helper_path, *fixture_path, *state_path, *log_path;
static const char *scenario = "start";
static pid_t running;

static double now(void)
{
    struct timeval t;
    gettimeofday(&t, NULL);
    return (double)t.tv_sec + (double)t.tv_usec / 1e6;
}

static void need(int holds, const char *format, ...)
{
    if (holds)
        return;
    va_list arguments;
    va_start(arguments, format);
    printf("FAIL %s: ", scenario);
    vprintf(format, arguments);
    printf("\n");
    va_end(arguments);
    fflush(stdout);
    if (running > 0)
        kill(running, SIGKILL);
    exit(1);
}

static const char *shown(const char *bytes, size_t length)
{
    static char text[512];
    size_t wrote = rc_escape(bytes, length < 120 ? length : 120, text, sizeof text - 1, 1);
    text[wrote == (size_t)-1 ? 0 : wrote] = '\0';
    return text;
}

static int same(const struct line *line, int index, const char *bytes, size_t length)
{
    return index < line->count && line->lengths[index] == length && memcmp(line->fields[index], bytes, length) == 0;
}

static int word(const struct line *line, int index, const char *text)
{
    return same(line, index, text, strlen(text));
}

static void start(struct helper *helper, const char *const arguments[])
{
    int requests[2], replies[2];
    need(pipe(requests) == 0 && pipe(replies) == 0, "pipe: %s", strerror(errno));
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, requests[0], 0);
    posix_spawn_file_actions_adddup2(&actions, replies[1], 1);
    posix_spawn_file_actions_addopen(&actions, 2, log_path, O_WRONLY | O_CREAT | O_APPEND, 0600);
    posix_spawnattr_t attributes;
    posix_spawnattr_init(&attributes);
    posix_spawnattr_setflags(&attributes, POSIX_SPAWN_CLOEXEC_DEFAULT);
    char *argv[16];
    int count = 0;
    argv[count++] = (char *)helper_path;
    for (int i = 0; arguments[i]; i++)
        argv[count++] = (char *)arguments[i];
    argv[count] = NULL;
    int error = posix_spawn(&helper->pid, helper_path, &actions, &attributes, argv, environ);
    need(error == 0, "posix_spawn of %s: %s", helper_path, strerror(error));
    running = helper->pid;
    posix_spawn_file_actions_destroy(&actions);
    posix_spawnattr_destroy(&attributes);
    close(requests[0]);
    close(replies[1]);
    need(fcntl(requests[1], F_SETNOSIGPIPE, 1) == 0, "F_SETNOSIGPIPE: %s", strerror(errno));
    fcntl(requests[1], F_SETFL, fcntl(requests[1], F_GETFL) | O_NONBLOCK);
    helper->to = requests[1];
    helper->from = replies[0];
    memset(&helper->reader, 0, sizeof helper->reader);
    helper->reader.fd = helper->from;
}

static void begin(struct helper *helper, long idle_ms)
{
    static char idle[32];
    snprintf(idle, sizeof idle, "%ld", idle_ms);
    const char *with_idle[] = {fixture_path, RC_VERSION, "--state", state_path, "--idle-ms", idle, NULL};
    const char *plain[] = {fixture_path, RC_VERSION, "--state", state_path, NULL};
    start(helper, idle_ms ? with_idle : plain);
}

static int get(struct helper *helper, int wait_ms, struct line *line, size_t *left)
{
    char *raw = NULL;
    size_t length = 0;
    int kind = rc_read_line(&helper->reader, wait_ms, &raw, &length);
    if (left)
        *left = length;
    need(kind != RC_LONG && kind != RC_BROKEN, "an answer longer than a line of the protocol, or the answer pipe cannot be read");
    if (kind != RC_LINE)
        return kind;
    need(!memmem(raw, length, "forged", 6) && !memmem(raw, length, "standard output", 15), "a line the library printed reached the answer pipe: %s", shown(raw, length));
    memset(line, 0, sizeof *line);
    line->at = now();
    line->raw = malloc(length + 1);
    memcpy(line->raw, raw, length + 1);
    line->raw_length = length;
    char *copy = malloc(length + 1);
    memcpy(copy, raw, length + 1);
    line->count = rc_split(copy, length, line->fields, line->lengths);
    int shaped = line->count <= RC_FIELDS_MOST;
    for (int i = 0; shaped && i < line->count; i++) {
        line->lengths[i] = rc_unescape(line->fields[i], line->lengths[i]);
        shaped = line->lengths[i] != (size_t)-1;
    }
    shaped = shaped && ((word(line, 0, "ready") && line->count == 4) || (word(line, 0, "failed") && line->count == 3) || (word(line, 0, "rejected") && line->count == 3) ||
                        (word(line, 0, "token") && line->count == 4 && word(line, 2, "ok")) || (word(line, 0, "token") && line->count == 7 && word(line, 2, "error")));
    need(shaped, "a line that is not of the protocol reached the answer pipe: %s", shown(raw, length));
    return RC_LINE;
}

static struct line *one(struct helper *helper, int wait_ms, const char *what)
{
    static struct line lines[512];
    static int used;
    struct line *line = &lines[used++ % 512];
    int kind = get(helper, wait_ms, line, NULL);
    need(kind != RC_END, "the answer pipe ended where %s was due", what);
    need(kind == RC_LINE, "nothing came in %d ms where %s was due", wait_ms, what);
    return line;
}

static void quiet(struct helper *helper, int ms)
{
    struct line line;
    int kind = get(helper, ms, &line, NULL);
    need(kind != RC_LINE, "a line came when none was due: %s", kind == RC_LINE ? shown(line.raw, line.raw_length) : "");
    need(kind == RC_WAIT, "the answer pipe ended when the helper was to stay");
}

static int finish(struct helper *helper, int wait_ms)
{
    double until = now() + wait_ms / 1000.0;
    int status = 0;
    for (;;) {
        pid_t done = waitpid(helper->pid, &status, WNOHANG);
        if (done == helper->pid) {
            running = 0;
            break;
        }
        need(now() < until, "the helper did not end in %d ms", wait_ms);
        usleep(5000);
    }
    if (helper->to >= 0)
        close(helper->to);
    if (helper->from >= 0)
        close(helper->from);
    return status;
}

static void ended(struct helper *helper, int wait_ms, int code)
{
    struct line line;
    int kind = get(helper, wait_ms, &line, NULL);
    need(kind != RC_LINE, "a line came where the end of the answer pipe was due: %s", kind == RC_LINE ? shown(line.raw, line.raw_length) : "");
    need(kind == RC_END, "the helper did not end: its answer pipe was still open after %d ms", wait_ms);
    int status = finish(helper, 2000);
    need(WIFEXITED(status) && WEXITSTATUS(status) == code, "the helper ended with status 0x%x, not with exit %d", status, code);
}

static void put(struct helper *helper, const char *bytes, size_t length)
{
    double until = now() + 5;
    while (length) {
        ssize_t wrote = write(helper->to, bytes, length);
        if (wrote > 0) {
            bytes += wrote;
            length -= (size_t)wrote;
            continue;
        }
        need(wrote < 0 && (errno == EAGAIN || errno == EINTR), "a write to the helper failed: %s", strerror(errno));
        need(now() < until, "the helper stopped reading its requests: a write did not finish in 5 s");
        struct pollfd waited = {helper->to, POLLOUT, 0};
        poll(&waited, 1, 100);
    }
}

static void ask(struct helper *helper, const char *id, const char *key, const char *action, long ms)
{
    static char line[RC_LINE_MOST + 64];
    char allowed[32];
    snprintf(allowed, sizeof allowed, "%ld", ms);
    struct rc_field fields[] = {{"token", 5}, {id, strlen(id)}, {key, strlen(key)}, {action, strlen(action)}, {allowed, strlen(allowed)}};
    size_t length = rc_build(line, sizeof line, fields, 5, 0);
    need(length != (size_t)-1, "a request of the check does not fit");
    put(helper, line, length);
}

static struct line *ready(struct helper *helper)
{
    struct line *line = one(helper, 10000, "the ready line");
    need(word(line, 0, "ready"), "the first line is not ready: %s", shown(line->raw, line->raw_length));
    return line;
}

static void quit(struct helper *helper)
{
    put(helper, RAW("quit\n"));
    ended(helper, 2000, 0);
}

static void is_ok(const struct line *line, const char *id, const char *token, size_t length)
{
    need(word(line, 0, "token") && word(line, 1, id) && word(line, 2, "ok"), "the answer to %s is not a token: %s", id, shown(line->raw, line->raw_length));
    need(same(line, 3, token, length), "the token of %s is not what the library gave: %s", id, shown(line->fields[3], line->lengths[3]));
}

static void is_error(const struct line *line, const char *id, const char *name, const char *domain, const char *code, const char *text)
{
    need(word(line, 0, "token") && word(line, 1, id) && word(line, 2, "error") && word(line, 3, name), "the answer to %s is not the error %s: %s", id, name,
         shown(line->raw, line->raw_length));
    need((!domain || word(line, 4, domain)) && (!code || word(line, 5, code)) && (!text || word(line, 6, text)), "the error of %s does not carry the domain, code and text it was given: %s", id,
         shown(line->raw, line->raw_length));
}

static void is_rejected(const struct line *line, const char *name)
{
    need(word(line, 0, "rejected") && word(line, 1, name), "a line was not rejected as %s: %s", name, shown(line->raw, line->raw_length));
    for (size_t i = 0; i < line->raw_length; i++)
        need((unsigned char)line->raw[i] < 0x80, "a rejected line carries a byte that is not ASCII");
}

static struct line *answered(struct line **lines, int count, const char *id)
{
    struct line *found = NULL;
    int times = 0;
    for (int i = 0; i < count; i++) {
        if (word(lines[i], 0, "token") && word(lines[i], 1, id)) {
            found = lines[i];
            times++;
        }
    }
    need(times == 1, "the id %s was answered %d times", id, times);
    return found;
}

static int rejections(struct line **lines, int count, const char *name)
{
    int times = 0;
    for (int i = 0; i < count; i++) {
        if (word(lines[i], 0, "rejected") && word(lines[i], 1, name)) {
            is_rejected(lines[i], name);
            times++;
        }
    }
    return times;
}

static void scenario_ready(void)
{
    static struct helper helper;
    double began = now();
    begin(&helper, 0);
    struct line *line = ready(&helper);
    need(word(line, 1, RC_VERSION), "ready names a version that is not %s", RC_VERSION);
    need(line->lengths[2] == 32 && strspn(line->fields[2], "0123456789abcdef") == 32, "ready does not carry the UUID of the library: %s", shown(line->fields[2], line->lengths[2]));
    need(rc_number(line->fields[3], line->lengths[3], 600000) > 0 || word(line, 3, "0"), "ready does not carry the milliseconds of the load");
    need(now() - began < 10, "ready took more than 10 s");
    quiet(&helper, 200);
    quit(&helper);
}

static void refused(const char *const arguments[], const char *name)
{
    static struct helper helper;
    start(&helper, arguments);
    struct line *line = one(&helper, 10000, "the failed line");
    need(word(line, 0, "failed") && word(line, 1, name) && line->lengths[2] > 0, "the helper did not say failed %s: %s", name, shown(line->raw, line->raw_length));
    ended(&helper, 2000, 3);
}

static void scenario_failed(void)
{
    static char missing[1024];
    snprintf(missing, sizeof missing, "%s/no-such-library.dylib", state_path);
    refused((const char *[]){missing, RC_VERSION, "--state", state_path, NULL}, "LOAD_FAILED");
    refused((const char *[]){fixture_path, "2", "--state", state_path, NULL}, "VERSION");
    refused((const char *[]){"/usr/lib/libz.dylib", RC_VERSION, "--state", state_path, NULL}, "NO_CLASSES");
    refused((const char *[]){fixture_path, RC_VERSION, NULL}, "NO_IDENTITY");
    refused((const char *[]){NULL}, "USAGE");
    refused((const char *[]){fixture_path, RC_VERSION, "--state", state_path, "--loud", NULL}, "USAGE");
    refused((const char *[]){fixture_path, RC_VERSION, "--state", state_path, "--idle-ms", "soon", NULL}, "USAGE");
}

static void scenario_token(void)
{
    static struct helper helper;
    begin(&helper, 0);
    ready(&helper);
    ask(&helper, "a1", "ok-key", "login", 5000);
    is_ok(one(&helper, 3000, "the token of a1"), "a1", RAW("tok[ok-key][login]"));
    ask(&helper, "a2", "ok-key", "signup", 5000);
    is_ok(one(&helper, 3000, "the token of a2"), "a2", RAW("tok[ok-key][signup]"));
    ask(&helper, "a3", "ok-key", "auth.sendCode", 5000);
    is_ok(one(&helper, 3000, "the token of a3"), "a3", RAW("tok[ok-key][custom auth.sendCode]"));
    ask(&helper, "a4", "ok-second", "login", 5000);
    ask(&helper, "a5", "ok-second", "signup", 5000);
    struct line *both[2] = {one(&helper, 3000, "the first of two tokens"), one(&helper, 3000, "the second of two tokens")};
    is_ok(answered(both, 2, "a4"), "a4", RAW("tok[ok-second][login]"));
    is_ok(answered(both, 2, "a5"), "a5", RAW("tok[ok-second][signup]"));
    quiet(&helper, 100);
    quit(&helper);
}

static void scenario_errors(void)
{
    static struct helper helper;
    begin(&helper, 0);
    ready(&helper);
    ask(&helper, "e1", "refused-key", "login", 5000);
    is_error(one(&helper, 3000, "the error of e1"), "e1", "EXECUTE_FAILED", "com.google.recaptcha", "2", "Invalid Site Key.");
    ask(&helper, "e2", "nofetch-key", "login", 5000);
    is_error(one(&helper, 3000, "the error of e2"), "e2", "FETCH_FAILED", "com.google.recaptcha", "3", "Network Error.");
    ask(&helper, "e3", "weird-key", "login", 5000);
    is_error(one(&helper, 3000, "the error of e3"), "e3", "EXECUTE_FAILED", "do\tmain", "-7", "a\tb\nc 100% \xc3\xa9\xe2\x82\xac");
    ask(&helper, "e4", "nil-key", "login", 5000);
    is_error(one(&helper, 3000, "the error of e4"), "e4", "EXECUTE_FAILED", "rchelper", "0", NULL);
    const char *slow[] = {"stuck-key", "never-key", "never-key"};
    const char *ids[] = {"e5", "e6", "e7"};
    for (int i = 0; i < 3; i++) {
        double asked = now();
        ask(&helper, ids[i], slow[i], "login", 300);
        struct line *line = one(&helper, 3000, "the deadline of the request");
        is_error(line, ids[i], "TIMEOUT", "rchelper", "0", NULL);
        need(line->at - asked > 0.25 && line->at - asked < 1.5, "TIMEOUT of %s came %.0f ms after the request, and 300 were allowed", ids[i], (line->at - asked) * 1000);
    }
    ask(&helper, "e8", "ok-key", "login", 5000);
    is_ok(one(&helper, 3000, "the token of e8"), "e8", RAW("tok[ok-key][login]"));
    quit(&helper);
}

static void scenario_unknown(void)
{
    static struct helper helper;
    begin(&helper, 0);
    ready(&helper);
    put(&helper, RAW("hello\tworld\n"));
    put(&helper, RAW("\n"));
    put(&helper, RAW("quit\tnow\n"));
    put(&helper, RAW("TOKEN\tx\tok-key\tlogin\t100\n"));
    put(&helper, RAW("ready\t1\n"));
    put(&helper, RAW(" token\tx\tok-key\tlogin\t100\n"));
    put(&helper, RAW("token \tx\tok-key\tlogin\t100\n"));
    put(&helper, RAW("\xff\xfe\0garbage\n"));
    for (int i = 0; i < 8; i++)
        is_rejected(one(&helper, 3000, "a rejection of an unknown line"), "UNKNOWN_LINE");
    ask(&helper, "u1", "ok-key", "login", 5000);
    is_ok(one(&helper, 3000, "the token of u1"), "u1", RAW("tok[ok-key][login]"));
    quit(&helper);
}

static void scenario_pending(void)
{
    static struct helper helper;
    begin(&helper, 0);
    ready(&helper);
    double asked = now();
    ask(&helper, "p1", "stuck-key", "login", 900);
    ask(&helper, "p2", "ok-key", "login", 5000);
    ask(&helper, "p1", "ok-key", "login", 5000);
    ask(&helper, "p3", "slow-key", "login", 300);
    ask(&helper, "p4", "twice-key", "login", 5000);
    static struct line read[5];
    struct line *lines[5];
    int came = 0;
    while (came < 5 && get(&helper, 2000, &read[came], NULL) == RC_LINE) {
        lines[came] = &read[came];
        came++;
    }
    need(rejections(lines, came, "DUPLICATE_ID") == 1, "the second request with a pending id was not rejected");
    need(came == 5, "%d lines came where five were due while a request was pending", came);
    is_ok(answered(lines, 5, "p2"), "p2", RAW("tok[ok-key][login]"));
    is_ok(answered(lines, 5, "p4"), "p4", RAW("tok[twice-key][login]"));
    is_error(answered(lines, 5, "p3"), "p3", "TIMEOUT", "rchelper", "0", NULL);
    struct line *late = answered(lines, 5, "p1");
    is_error(late, "p1", "TIMEOUT", "rchelper", "0", NULL);
    need(late->at - asked > 0.7, "the pending request was answered %.0f ms after it was sent, and it had 900", (late->at - asked) * 1000);
    need(answered(lines, 5, "p2")->at < late->at, "the request sent second was not answered while the first was pending");
    quiet(&helper, 700);
    ask(&helper, "p1", "ok-key", "signup", 5000);
    is_ok(one(&helper, 3000, "the token of an id used again"), "p1", RAW("tok[ok-key][signup]"));
    quit(&helper);
}

static void forget(void)
{
    close(open(log_path, O_WRONLY | O_CREAT | O_TRUNC, 0600));
}

static const char *written(void)
{
    static char log[262144];
    int fd = open(log_path, O_RDONLY);
    ssize_t got = fd < 0 ? -1 : read(fd, log, sizeof log - 1);
    need(got > 0, "the file of descriptor 2 is empty or cannot be read");
    close(fd);
    log[got] = '\0';
    return log;
}

static int times(const char *text, const char *piece)
{
    int found = 0;
    for (const char *at = strstr(text, piece); at; at = strstr(at + 1, piece))
        found++;
    return found;
}

static void scenario_quitclose(void)
{
    static struct helper helper;
    enum { HELPERS = 20 };
    forget();
    for (int i = 0; i < HELPERS; i++) {
        begin(&helper, 0);
        ready(&helper);
        put(&helper, RAW("quit\n"));
        close(helper.to);
        helper.to = -1;
        ended(&helper, 2000, 0);
    }
    const char *log = written();
    int left = times(log, "rchelper: quit: state=") + times(log, "rchelper: the app closed the request pipe: state=");
    need(times(log, "rchelper: ready: state=") == HELPERS, "the file of descriptor 2 does not hold one ready line for each of %d helpers", (int)HELPERS);
    need(left == HELPERS, "%d helpers that were sent quit and lost their request pipe at once wrote %d lines of leaving: a helper left twice", (int)HELPERS, left);
}

static void scenario_closed(void)
{
    static struct helper helper;
    forget();
    begin(&helper, 0);
    ready(&helper);
    ask(&helper, "s1", "store-key", "login", 5000);
    is_ok(one(&helper, 3000, "the token of s1"), "s1", RAW("tok[store-key][login]"));
    ask(&helper, "c1", "stuck-key", "login", 60000);
    usleep(100000);
    close(helper.to);
    helper.to = -1;
    ended(&helper, 1000, 0);
    const char *left = strstr(written(), "rchelper: the app closed the request pipe: state=");
    need(left != NULL, "a helper whose request pipe ended did not write its line of leaving to descriptor 2");
    const char *own = strstr(left, " cookies own=1, ");
    need(own != NULL && own < strchr(left, '\n'), "the cookie the library set is not in the cookie store of the helper's own: its line of leaving does not say cookies own=1");
    const char *given = getenv("CFFIXED_USER_HOME");
    need(given != NULL && given[0] == '/', "the driver was not given a home folder in CFFIXED_USER_HOME");
    char file[2048];
    snprintf(file, sizeof file, "%s/home/Library/Caches/rcec/ovk", state_path);
    need(access(file, R_OK) == 0, "the file the library wrote in its caches folder is not in the helper's own home: there is no %s", file);
    snprintf(file, sizeof file, "%s/Library/Caches/rcec", given);
    need(access(file, F_OK) != 0, "the library wrote in %s, in the home the helper was given and outside its own state", file);
    begin(&helper, 0);
    ready(&helper);
    close(helper.from);
    helper.from = -1;
    ask(&helper, "c2", "ok-key", "login", 5000);
    int status = finish(&helper, 2000);
    need(WIFEXITED(status) && WEXITSTATUS(status) == 0, "a helper whose answer pipe was closed ended with status 0x%x, not with exit 0", status);
}

static void scenario_killed(void)
{
    static struct helper helper;
    struct line line;
    size_t left = 0;
    begin(&helper, 0);
    ready(&helper);
    ask(&helper, "k1", "stuck-key", "login", 60000);
    usleep(100000);
    kill(helper.pid, SIGKILL);
    need(get(&helper, 1000, &line, &left) == RC_END, "the answer pipe of a killed helper did not end in a second");
    int status = finish(&helper, 2000);
    need(WIFSIGNALED(status) && WTERMSIG(status) == SIGKILL, "a killed helper is not reported as killed: status 0x%x", status);
    begin(&helper, 0);
    ready(&helper);
    for (int i = 0; i < 3; i++)
        ask(&helper, i == 0 ? "b1" : i == 1 ? "b2" : "b3", "big60000", "login", 60000);
    usleep(500000);
    kill(helper.pid, SIGKILL);
    int whole = 0, kind;
    while ((kind = get(&helper, 1000, &line, &left)) == RC_LINE) {
        need(word(&line, 0, "token") && word(&line, 2, "ok") && line.lengths[3] == 60000, "a line of a killed helper is not a whole answer");
        whole++;
    }
    need(kind == RC_END, "the answer pipe of a killed helper did not end in a second");
    need(whole < 3 && left > 0, "the helper was not stopped in the middle of a line (%d whole lines, %lu bytes after them): the case was not made", whole, (unsigned long)left);
    finish(&helper, 2000);
    begin(&helper, 0);
    ready(&helper);
    ask(&helper, "k2", "ok-key", "login", 5000);
    is_ok(one(&helper, 3000, "the token of the helper started after the killed one"), "k2", RAW("tok[ok-key][login]"));
    quit(&helper);
}

static void scenario_long(void)
{
    static struct helper helper;
    static char action[RC_LINE_MOST + 16], token[RC_LINE_MOST + 64], raw[300002];
    begin(&helper, 0);
    ready(&helper);
    memset(action, 'a', 60000);
    action[60000] = '\0';
    int length = snprintf(token, sizeof token, "tok[ok-key][custom %s]", action);
    ask(&helper, "l0", "ok-key", action, 5000);
    is_ok(one(&helper, 3000, "the token of a long request"), "l0", token, (size_t)length);
    const char *ids[] = {"l1", "l2", "l3", "l4", "l5", "l6"};
    for (int i = 0; i < 6; i++)
        ask(&helper, ids[i], "ok-key", action, 20000);
    struct line *lines[6];
    for (int i = 0; i < 6; i++)
        lines[i] = one(&helper, 5000, "one of six long answers");
    for (int i = 0; i < 6; i++)
        is_ok(answered(lines, 6, ids[i]), ids[i], token, (size_t)length);
    memset(action, 'a', 65514);
    action[65514] = '\0';
    ask(&helper, "l7", "ok-key", action, 5000);
    is_error(one(&helper, 3000, "the answer to a request of exactly one line"), "l7", "EXECUTE_FAILED", "rchelper", "0", NULL);
    action[65514] = 'a';
    action[65515] = '\0';
    ask(&helper, "l8", "ok-key", action, 5000);
    is_rejected(one(&helper, 3000, "the rejection of a line one byte too long"), "LINE_TOO_LONG");
    memset(raw, 'x', 300000);
    raw[300000] = '\n';
    put(&helper, raw, 300001);
    struct line *rejected = one(&helper, 3000, "the rejection of a line of 300000 bytes");
    is_rejected(rejected, "LINE_TOO_LONG");
    need(rejected->lengths[2] > 6 && memcmp(rejected->fields[2], "300001", 6) == 0, "the rejection does not say how long the line was: %s", shown(rejected->raw, rejected->raw_length));
    ask(&helper, "l9", "ok-key", "login", 5000);
    is_ok(one(&helper, 3000, "the token after the long lines"), "l9", RAW("tok[ok-key][login]"));
    quit(&helper);
}

struct garbage {
    const char *bytes;
    size_t length;
    const char *id;
    const char *token;
    size_t token_length;
};

static void scenario_garbage(void)
{
    static struct helper helper;
    static char overlong[128];
    snprintf(overlong, sizeof overlong, "token\t%s\tok-key\tlogin\t100\n", "iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii");
    const struct garbage bad_ids[] = {
        {RAW("token\t\tok-key\tlogin\t100\n")}, {RAW("token\tbad id\tok-key\tlogin\t100\n")}, {RAW("token\t%41\tok-key\tlogin\t100\n")},
        {overlong, strlen(overlong)},           {RAW("token\tid\xd0\xb9\tok-key\tlogin\t100\n")},  {RAW("token\n")},
    };
    const struct garbage bad_requests[] = {
        {RAW("token\tg1\n"), "g1"},
        {RAW("token\tg2\tok-key\tlogin\n"), "g2"},
        {RAW("token\tg3\tok-key\tlogin\t100\textra\n"), "g3"},
        {RAW("token\tg4\t\tlogin\t100\n"), "g4"},
        {RAW("token\tg5\tok-key\t\t100\n"), "g5"},
        {RAW("token\tg6\tok-key\tlogin\t\n"), "g6"},
        {RAW("token\tg7\tok-key\tlogin\tabc\n"), "g7"},
        {RAW("token\tg8\tok-key\tlogin\t-5\n"), "g8"},
        {RAW("token\tg9\tok-key\tlogin\t0\n"), "g9"},
        {RAW("token\tg10\tok-key\tlogin\t120001\n"), "g10"},
        {RAW("token\tg11\tok-key\tlogin\t99999999999999999999\n"), "g11"},
        {RAW("token\tg12\tok-key\tlogin\t12 \n"), "g12"},
        {RAW("token\tg13\tok-key\tlogin\t5000\r\n"), "g13"},
        {RAW("token\tg14\tok%\tlogin\t100\n"), "g14"},
        {RAW("token\tg15\tok%4\tlogin\t100\n"), "g15"},
        {RAW("token\tg16\tok%zz\tlogin\t100\n"), "g16"},
        {RAW("token\tg17\tok%00\tlogin\t100\n"), "g17"},
        {RAW("token\tg18\tok-key\tlog%\t100\n"), "g18"},
        {RAW("token\tg19\tok\xff\xfe\tlogin\t100\n"), "g19"},
        {RAW("token\tg20\tok%FF\tlogin\t100\n"), "g20"},
        {RAW("token\tg21\tok-key\tlog\xc0\xafin\t100\n"), "g21"},
        {RAW("token\tg22\tok-key\tlog\xed\xa0\x80\t100\n"), "g22"},
        {RAW("token\tg23\tok-key\tlog\xe2\x82\t100\n"), "g23"},
        {RAW("token\tg24\tok\0key\tlogin\t100\n"), "g24"},
        {RAW("token\tg25\tok-key\tlogin\t+100\n"), "g25"},
        {RAW("token\tg26\tok-key\tlogin\t1e3\n"), "g26"},
        {RAW("token\tg27\ta\tb\tc\td\te\tf\tg\n"), "g27"},
        {RAW("token\tg28\tok-key\tlog%G1\t100\n"), "g28"},
    };
    const struct garbage good[] = {
        {RAW("token\th1\tok%09tab%0Anl%25pct\tlogin\t5000\n"), "h1", RAW("tok[ok\ttab\nnl%pct][login]")},
        {RAW("token\th2\tok-key\t\xd0\xb4%09%0a%25\xe2\x82\xac\xf0\x9f\x98\x80\t5000\n"), "h2", RAW("tok[ok-key][custom \xd0\xb4\t\n%\xe2\x82\xac\xf0\x9f\x98\x80]")},
        {RAW("token\th3\tok key with spaces\tx y\t120000\n"), "h3", RAW("tok[ok key with spaces][custom x y]")},
        {RAW("token\th4\tok%7F%01\tlogin\t5000\n"), "h4", RAW("tok[ok\x7f\x01][login]")},
    };
    enum { BAD_IDS = sizeof bad_ids / sizeof bad_ids[0], BAD_REQUESTS = sizeof bad_requests / sizeof bad_requests[0], GOOD = sizeof good / sizeof good[0], ALL = BAD_IDS + BAD_REQUESTS + GOOD };
    begin(&helper, 0);
    ready(&helper);
    for (int i = 0; i < BAD_IDS; i++)
        put(&helper, bad_ids[i].bytes, bad_ids[i].length);
    for (int i = 0; i < BAD_REQUESTS; i++)
        put(&helper, bad_requests[i].bytes, bad_requests[i].length);
    for (int i = 0; i < GOOD; i++)
        put(&helper, good[i].bytes, good[i].length);
    struct line *lines[ALL];
    for (int i = 0; i < ALL; i++)
        lines[i] = one(&helper, 3000, "an answer to a line of garbage");
    need(rejections(lines, ALL, "BAD_ID") == BAD_IDS, "%d lines with a wrong id were sent and %d were rejected as BAD_ID", (int)BAD_IDS, rejections(lines, ALL, "BAD_ID"));
    for (int i = 0; i < BAD_REQUESTS; i++)
        is_error(answered(lines, ALL, bad_requests[i].id), bad_requests[i].id, "BAD_REQUEST", "rchelper", "0", NULL);
    for (int i = 0; i < GOOD; i++)
        is_ok(answered(lines, ALL, good[i].id), good[i].id, good[i].token, good[i].token_length);
    quiet(&helper, 200);
    ask(&helper, "h9", "ok-key", "login", 5000);
    is_ok(one(&helper, 3000, "the token after the garbage"), "h9", RAW("tok[ok-key][login]"));
    quit(&helper);
}

static void scenario_idle(void)
{
    static struct helper helper;
    struct line line;
    begin(&helper, 600);
    double since = ready(&helper)->at;
    int kind = get(&helper, 3000, &line, NULL);
    need(kind == RC_END, "the helper did not end after its idle time: its answer pipe was still open 3 s after ready, and the idle time was 600 ms");
    need(now() - since > 0.4, "the helper ended %.0f ms after ready, before its idle time of 600 ms", (now() - since) * 1000);
    int status = finish(&helper, 2000);
    need(WIFEXITED(status) && WEXITSTATUS(status) == 0, "an idle helper ended with status 0x%x, not with exit 0", status);
    begin(&helper, 600);
    ready(&helper);
    ask(&helper, "i1", "stuck-key", "login", 1500);
    quiet(&helper, 1100);
    struct line *late = one(&helper, 2000, "the deadline of the request");
    is_error(late, "i1", "TIMEOUT", "rchelper", "0", NULL);
    kind = get(&helper, 3000, &line, NULL);
    need(kind == RC_END, "the helper did not end after its idle time: its answer pipe was still open 3 s after its last answer");
    need(now() - late->at > 0.4, "the helper ended %.0f ms after its last answer, before its idle time of 600 ms", (now() - late->at) * 1000);
    status = finish(&helper, 2000);
    need(WIFEXITED(status) && WEXITSTATUS(status) == 0, "an idle helper ended with status 0x%x, not with exit 0", status);
}

static void scenario_noise(void)
{
    static struct helper helper;
    forget();
    begin(&helper, 0);
    ready(&helper);
    ask(&helper, "n1", "noisy-key", "login", 5000);
    is_ok(one(&helper, 3000, "the token of n1"), "n1", RAW("tok[noisy-key][login]"));
    quiet(&helper, 200);
    quit(&helper);
    const char *log = written();
    const char *wanted[] = {"forged-load", "forged-execute", "ready\t1\tforged", "a line of the SDK on standard output", "a line on standard error from execute", "a line of NSLog", "rchelper: ready: state=", "rchelper: quit: state="};
    for (size_t i = 0; i < sizeof wanted / sizeof wanted[0]; i++)
        need(strstr(log, wanted[i]) != NULL, "the file of descriptor 2 does not hold what the library printed: no '%s' in it", shown(wanted[i], strlen(wanted[i])));
}

int main(int argc, char **argv)
{
    static const struct {
        const char *name;
        void (*run)(void);
    } scenarios[] = {{"ready", scenario_ready},     {"failed", scenario_failed}, {"token", scenario_token}, {"errors", scenario_errors},   {"unknown", scenario_unknown}, {"pending", scenario_pending},
                     {"closed", scenario_closed},   {"killed", scenario_killed}, {"long", scenario_long},   {"garbage", scenario_garbage}, {"idle", scenario_idle},       {"noise", scenario_noise},
                     {"quitclose", scenario_quitclose}};
    if (argc < 5) {
        fprintf(stderr, "usage: driver HELPER LIBRARY STATE LOG [SCENARIO]\n");
        return 2;
    }
    helper_path = argv[1];
    fixture_path = argv[2];
    state_path = argv[3];
    log_path = argv[4];
    int ran = 0;
    for (size_t i = 0; i < sizeof scenarios / sizeof scenarios[0]; i++) {
        if (argc > 5 && strcmp(argv[5], scenarios[i].name) != 0)
            continue;
        scenario = scenarios[i].name;
        double began = now();
        scenarios[i].run();
        printf("passed %s in %.2f s\n", scenario, now() - began);
        fflush(stdout);
        ran++;
    }
    need(ran > 0, "no scenario of that name");
    printf("ok: %d scenarios\n", ran);
    return 0;
}
