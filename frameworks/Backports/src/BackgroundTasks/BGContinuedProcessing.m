#import <BackgroundTasks/BackgroundTasks.h>
#import "RevenantBackgroundTasks.h"

@implementation BGContinuedProcessingTaskRequest {
    NSString *_title;
    NSString *_subtitle;
    BGContinuedProcessingTaskRequestSubmissionStrategy _strategy;
    BGContinuedProcessingTaskRequestResources _requiredResources;
}

- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title subtitle:(NSString *)subtitle
{
    if ((self = [super initRevenantWithIdentifier:identifier])) {
        _title = [title copy];
        _subtitle = [subtitle copy];
        _strategy = BGContinuedProcessingTaskRequestSubmissionStrategyQueue;
        _requiredResources = BGContinuedProcessingTaskRequestResourcesDefault;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    BGContinuedProcessingTaskRequest *copy = [super copyWithZone:zone];
    copy->_title = [_title copy];
    copy->_subtitle = [_subtitle copy];
    copy->_strategy = _strategy;
    copy->_requiredResources = _requiredResources;
    return copy;
}

@end

@implementation BGContinuedProcessingTask {
    NSString *_title;
    NSString *_subtitle;
    NSProgress *_progress;
}

- (NSProgress *)progress
{
    if (!_progress) {
        _progress = [NSProgress progressWithTotalUnitCount:0];
    }
    return _progress;
}

- (void)updateTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    _title = [title copy];
    _subtitle = [subtitle copy];
}

@end
