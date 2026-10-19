#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static int gEvents;

static void visit(void *context, MIDITimeStamp timeStamp, MIDIUniversalMessage message) {
    const unsigned char *b = (const unsigned char *)&message;
    gEvents++;
    if (gEvents > 8) return;
    printf("    event %d: type %X group %u ts=%llu unknown.words=", gEvents, (unsigned)message.type,
           (unsigned)message.group, (unsigned long long)timeStamp);
    for (int i = 0; i < 4; i++) printf("%s%08X", i ? " " : "", (unsigned)message.unknown.words[i]);
    printf(" raw-bytes=");
    for (size_t i = 0; i < sizeof(message); i++) printf("%02X", b[i]);
    printf("\n");
}

static void run(UInt32 type, int count) {
    Byte buf[256];
    memset(buf, 0, sizeof(buf));
    MIDIEventList *list = (MIDIEventList *)buf;
    UInt32 words[4] = {(type << 28) | 0x0ABCDEFu, 0x00000000u, 0x10F80000u, 0x20903C7Fu};
    MIDIEventPacket *p = MIDIEventListInit(list, kMIDIProtocol_2_0);
    MIDIEventPacket *q = MIDIEventListAdd(list, sizeof(buf), p, 42, count, words);
    printf("type %X, packet of %d words, in:", (unsigned)type, count);
    for (int i = 0; i < count; i++) printf(" %08X", (unsigned)words[i]);
    printf(" (MIDIEventListAdd %s)\n", q ? "ok" : "NULL");
    gEvents = 0;
    MIDIEventListForEachEvent(list, visit, NULL);
    printf("  visitor events for type %X: %d%s\n", (unsigned)type, gEvents, gEvents > 8 ? " (only first 8 printed)" : "");
}

static void run_forked(UInt32 type, int count) {
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        run(type, count);
        fflush(stdout);
        _exit(0);
    }
    int status = 0;
    waitpid(pid, &status, 0);
    if (WIFSIGNALED(status)) printf("  child for type %X, %d word(s): killed by signal %d\n", (unsigned)type, count, WTERMSIG(status));
    else printf("  child for type %X, %d word(s): exited %d\n", (unsigned)type, count, WEXITSTATUS(status));
}

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    const UInt32 types[] = {0x6, 0x7, 0x8, 0x9, 0xA, 0xB, 0xC, 0xE};
    const size_t n = sizeof(types) / sizeof(types[0]);
    printf("== four-word packets (type word, NOOP, system clock, channel note on), in process\n");
    for (size_t i = 0; i < n; i++) run(types[i], 4);
    printf("== one-word packets (type word only), each in a child process\n");
    for (size_t i = 0; i < n; i++) run_forked(types[i], 1);
    return 0;
}
