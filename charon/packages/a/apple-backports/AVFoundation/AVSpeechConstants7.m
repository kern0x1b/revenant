#import <AVFAudio/AVSpeechSynthesis.h>

// The three speech-rate constants, each a float. They are not strings: the header declares them
// `const float`, so the port defines them with that type, and a caller reads them as numbers. Each value
// is one a machine read, not one typed from the header - the host's own AVFAudio printed them in
// tests/backports/host/avf-speech/checks.m compares them with the host's own, and the iOS 7.0 shared cache holds
// the same three (facts/AVFoundation/AVSpeech.md).
const float AVSpeechUtteranceMinimumSpeechRate = 0.0f;
const float AVSpeechUtteranceMaximumSpeechRate = 1.0f;
const float AVSpeechUtteranceDefaultSpeechRate = 0.5f;
