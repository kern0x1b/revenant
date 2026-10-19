#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>
#import <objc/runtime.h>

static NSString *show(id value)
{
    return value ? [NSString stringWithFormat:@"%@", value] : @"nil";
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    int which = argc > 1 ? atoi(argv[1]) : -1;

    switch (which) {
    case 1: {
        SFSpeechURLRecognitionRequest *request = [[SFSpeechURLRecognitionRequest alloc] initWithURL:[NSURL fileURLWithPath:@"/nonexistent/recording.wav"]];
        printf("class=%s\n", class_getName([request class]));
        printf("URL=%s\n", show([request.URL absoluteString]).UTF8String);
        printf("taskHint=%ld\n", (long)request.taskHint);
        printf("shouldReportPartialResults=%d\n", request.shouldReportPartialResults);
        printf("contextualStrings=%s\n", show(request.contextualStrings).UTF8String);
        printf("interactionIdentifier=%s\n", show(request.interactionIdentifier).UTF8String);
        break;
    }
    case 2: {
        SFSpeechAudioBufferRecognitionRequest *request = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
        printf("class=%s\n", class_getName([request class]));
        printf("taskHint=%ld\n", (long)request.taskHint);
        printf("shouldReportPartialResults=%d\n", request.shouldReportPartialResults);
        printf("contextualStrings=%s\n", show(request.contextualStrings).UTF8String);
        AVAudioFormat *format = request.nativeAudioFormat;
        printf("nativeAudioFormat sampleRate=%.0f channels=%u commonFormat=%ld interleaved=%d\n", format.sampleRate,
               (unsigned)format.channelCount, (long)format.commonFormat, format.isInterleaved);
        break;
    }
    case 3: {
        SFTranscription *transcription = [[SFTranscription alloc] init];
        printf("class=%s\n", class_getName([transcription class]));
        printf("formattedString=%s\n", show(transcription.formattedString).UTF8String);
        printf("segments=%s\n", show(transcription.segments).UTF8String);
        break;
    }
    case 4: {
        SFTranscriptionSegment *segment = [[SFTranscriptionSegment alloc] init];
        printf("class=%s\n", class_getName([segment class]));
        printf("substring=%s\n", show(segment.substring).UTF8String);
        printf("substringRange=%s\n", NSStringFromRange(segment.substringRange).UTF8String);
        printf("timestamp=%.1f duration=%.1f confidence=%.1f\n", segment.timestamp, segment.duration, segment.confidence);
        printf("alternativeSubstrings=%s\n", show(segment.alternativeSubstrings).UTF8String);
        break;
    }
    case 5: {
        SFTranscription *transcription = [[SFTranscription alloc] init];
        NSError *error = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:transcription requiringSecureCoding:YES error:&error];
        printf("archive error=%s\n", error ? "yes" : "none");
        printf("archive length>0=%d\n", archive.length > 0);
        SFTranscription *back = archive ? [NSKeyedUnarchiver unarchivedObjectOfClass:[SFTranscription class] fromData:archive error:&error] : nil;
        printf("unarchive error=%s\n", error ? "yes" : "none");
        printf("unarchived class=%s\n", back ? class_getName([back class]) : "nil");
        printf("unarchived formattedString=%s\n", show(back.formattedString).UTF8String);
        break;
    }
    case 6: {
        SFTranscriptionSegment *segment = [[SFTranscriptionSegment alloc] init];
        SFTranscriptionSegment *copy = [segment copy];
        printf("copy class=%s\n", class_getName([copy class]));
        printf("copy substringRange=%s\n", NSStringFromRange(copy.substringRange).UTF8String);
        printf("copy confidence=%.1f\n", copy.confidence);
        break;
    }
    case 7: {
        SFSpeechRecognitionResult *result = [[SFSpeechRecognitionResult alloc] init];
        printf("final=%d\n", result.isFinal);
        printf("transcriptions=%s\n", show(result.transcriptions).UTF8String);
        printf("bestTranscription=%s\n", show(result.bestTranscription).UTF8String);
        break;
    }
    case 8: {
        printf("authorizationStatus=%ld\n", (long)[SFSpeechRecognizer authorizationStatus]);
        break;
    }
    case 9: {
        NSSet *identifiers = [[SFSpeechRecognizer supportedLocales] valueForKey:@"localeIdentifier"];
        printf("tlh-US supported=%d\n", [identifiers containsObject:@"tlh-US"]);
        break;
    }
    case 10: {
        SFSpeechRecognizer *recognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"tlh_US"]];
        printf("tlh-US recognizer=%s\n", recognizer ? "non-nil" : "nil");
        break;
    }
    case 12: {
        __block int calls = 0, onMain = 0;
        __block long seen = -1;
        [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
            __atomic_fetch_add(&calls, 1, __ATOMIC_SEQ_CST);
            seen = (long)status;
            onMain = [NSThread isMainThread];
        }];
        printf("returned from requestAuthorization\n");
        sleep(2);
        printf("handler calls=%d status=%ld main=%d\n", __atomic_load_n(&calls, __ATOMIC_SEQ_CST), seen, onMain);
        printf("status after=%ld\n", (long)[SFSpeechRecognizer authorizationStatus]);
        break;
    }
    case 13: {
        SFSpeechRecognitionTask *task = [[SFSpeechRecognitionTask alloc] init];
        printf("class=%s\n", class_getName([task class]));
        printf("finishing=%d cancelled=%d\n", task.finishing, task.cancelled);
        break;
    }
    case 14: {
        printf("SFSpeechErrorDomain=%s\n", show(SFSpeechErrorDomain).UTF8String);
        break;
    }
    }
    return 0;
}
