// Host probe: what MIDIEventListAdd returns and takes as curPacket, and what it leaves in the list when the words do not fit
// (the scenario is eventlistadd.h, which differential.m runs against the library). Buffers only: no MIDI object is made.
#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
#include <string.h>

#include "eventlistadd.h"

int main(void)
{
    eventlistadd_run(stdout);
    return 0;
}
