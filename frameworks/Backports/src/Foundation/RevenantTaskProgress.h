#import <Foundation/Foundation.h>

NSProgress *revenant_task_progress_create(id task);
void revenant_task_progress_apply(NSProgress *progress, int64_t sent, int64_t received, int64_t expectedToSend, int64_t expectedToReceive, BOOL complete);
