#import <Foundation/Foundation.h>

@interface SessionHarness : NSObject
@property (nonatomic) Class sessionClass;
@property (nonatomic) Class configurationClass;
@property (nonatomic, copy) NSString *base;
@property (nonatomic, copy) NSString *tag;
@property (nonatomic) NSTimeInterval patience;
@property (nonatomic, copy) NSString *prefix;
- (Class)classNamed:(NSString *)name;
@end

typedef NSArray *(*SessionScenario)(SessionHarness *harness);

typedef struct {
    const char *name;
    SessionScenario run;
} SessionScenarioEntry;

extern const SessionScenarioEntry session_scenarios[];
extern const size_t session_scenario_count;

NSDictionary *session_expected_transcripts(void);
NSString *session_transcript_text(NSArray *transcript);
NSArray *session_normalize_host_system(NSArray *transcript);
NSUInteger session_off_queue_count(void);
