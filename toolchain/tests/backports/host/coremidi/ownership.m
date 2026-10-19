#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

#import "RevenantCoreMIDI.h"

static int gCompletions = 0;

OSStatus revenant_test_MIDISendSysex(MIDISysexSendRequest *request)
{
    request->completionProc(request);
    return noErr;
}

static void completed(MIDISysexSendRequestUMP *request)
{
    gCompletions++;
    free(request->words);
    free(request);
}

OSStatus MIDISendUMPSysex(MIDISysexSendRequestUMP *umpRequest);

int main(void)
{
    MIDISysexSendRequestUMP *request = calloc(1, sizeof(*request));
    request->words = calloc(2, sizeof(UInt32));
    request->words[0] = 0x30030102u;
    request->words[1] = 0x03000000u;
    request->wordsToSend = 2;
    request->destination = 1;
    request->completionProc = completed;
    OSStatus status = MIDISendUMPSysex(request);
    int ok = status == noErr && gCompletions == 1;
    printf("ownership: status %d, completions %d, %s\n", (int)status, gCompletions, ok ? "ok" : "FAIL");
    return ok ? 0 : 1;
}
