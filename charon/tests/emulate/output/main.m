// A run's program output, measured. The known line is what the host greps for, in the file the run's
// verdict names, so a run that reports the program's output and a run that loses it are told apart by
// the file and not by the verdict.
//
// Nothing here flushes. That is the point of the hang mode: a program's stdio is block buffered once it
// is a file, so a line it wrote and never flushed is still in the buffer when the deadline ends it with
// SIGKILL, and the only thing that can have put it in the file is the runner spawning the program
// unbuffered (NSUnbufferedIO=YES, which the runner sets). The end mode needs no flush either: returning
// from main flushes, so it passes whichever runner is in use and tells the two apart from the hang mode.
// stderr is unbuffered by default, so its line is the control: it lands whichever runner is in use, and
// its landing says the file was captured at all.
#import <Foundation/Foundation.h>
#import <unistd.h>

static void said(const char* stream, int index) {
    if (strcmp(stream, "stdout") == 0) {
        fprintf(stdout, "charon-emulate-output: %s line %d reached the host\n", stream, index);
    } else {
        fprintf(stderr, "charon-emulate-output: %s line %d reached the host\n", stream, index);
    }
}

int main(int argc, char** argv) {
    said("stdout", 1);
    said("stderr", 1);
    // Asked to outlive the deadline: a program killed with SIGKILL flushes no buffer, so what it printed
    // before is what the host must still have, and with a buffered spawn there is nothing.
    if (argc > 1 && strcmp(argv[1], "--hang") == 0) {
        sleep(1);
        said("stdout", 2);
        for (;;) {
            sleep(1);
        }
    }
    return 0;
}
