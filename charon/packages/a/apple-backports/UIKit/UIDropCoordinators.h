#import <UIKit/UIKit.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>

@interface CharonCollectionDropItem : NSObject <UICollectionViewDropItem>
@property (nonatomic, strong) UIDragItem *item;
@property (nonatomic, strong) NSIndexPath *source;
@property (nonatomic, assign) CGSize size;
@end

@interface CharonTableDropItem : NSObject <UITableViewDropItem>
@property (nonatomic, strong) UIDragItem *item;
@property (nonatomic, strong) NSIndexPath *source;
@property (nonatomic, assign) CGSize size;
@end

@interface CharonCollectionPlaceholderContext : NSObject <UICollectionViewDropPlaceholderContext>
- (instancetype)initWithPlaceholder:(UICollectionViewDropPlaceholder *)placeholder
                                item:(UIDragItem *)item
                              inView:(UICollectionView *)collectionView;
@end

@interface CharonTablePlaceholderContext : NSObject <UITableViewDropPlaceholderContext>
- (instancetype)initWithPlaceholder:(UITableViewDropPlaceholder *)placeholder
                                item:(UIDragItem *)item
                              inView:(UITableView *)tableView;
@end

@interface CharonCollectionDropCoordinator : NSObject <UICollectionViewDropCoordinator>
@property (nonatomic, strong) NSArray<id<UICollectionViewDropItem>> *dropItems;
@property (nonatomic, strong) NSIndexPath *destination;
@property (nonatomic, strong) UICollectionViewDropProposal *dropProposal;
@property (nonatomic, strong) id<UIDropSession> dropSession;
@property (nonatomic, weak) UICollectionView *collectionView;
- (instancetype)initWithView:(UICollectionView *)view
                        items:(NSArray *)items
                  destination:(NSIndexPath *)destination
                    proposal:(UICollectionViewDropProposal *)proposal
                     session:(id<UIDropSession>)session;
@end

@interface CharonTableDropCoordinator : NSObject <UITableViewDropCoordinator>
@property (nonatomic, strong) NSArray<id<UITableViewDropItem>> *dropItems;
@property (nonatomic, strong) NSIndexPath *destination;
@property (nonatomic, strong) UITableViewDropProposal *dropProposal;
@property (nonatomic, strong) id<UIDropSession> dropSession;
@property (nonatomic, weak) UITableView *tableView;
- (instancetype)initWithView:(UITableView *)view
                        items:(NSArray *)items
                  destination:(NSIndexPath *)destination
                    proposal:(UITableViewDropProposal *)proposal
                     session:(id<UIDropSession>)session;
@end
