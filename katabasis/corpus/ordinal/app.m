#import <Foundation/Foundation.h>
@interface MyStr : NSString @end
@implementation MyStr @end
@interface MyObj : NSObject @end
@implementation MyObj @end
int main(void){ return (int)[MyStr class] != 0; }
