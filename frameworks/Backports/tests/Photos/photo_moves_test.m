#import <Foundation/Foundation.h>
#import "RevenantPhotoMoves.h"
#import "check.h"

static uint64_t revenant_state = 0x2545F4914F6CDD1DULL;

static uint32_t revenant_random(uint32_t bound)
{
    revenant_state ^= revenant_state << 13;
    revenant_state ^= revenant_state >> 7;
    revenant_state ^= revenant_state << 17;
    return (uint32_t)(revenant_state % bound);
}

static NSUInteger revenant_moves_by_oracle(NSArray *before, NSArray *after)
{
    NSMutableArray *target = [NSMutableArray arrayWithArray:after];
    NSOrderedCollectionDifference *difference = [target differenceFromArray:before withOptions:NSOrderedCollectionDifferenceCalculationInferMoves];
    NSUInteger moves = 0;
    for (NSOrderedCollectionChange *change in difference) {
        if (change.changeType == NSCollectionChangeRemove && change.associatedIndex != NSNotFound)
            moves++;
    }
    return moves;
}

static NSUInteger revenant_moves_by_helper(NSArray *before, NSArray *after, BOOL *ordered)
{
    NSMutableDictionary *positions = [NSMutableDictionary dictionary];
    for (NSUInteger index = 0; index < before.count; index++)
        positions[before[index]] = @(index);
    size_t *from = malloc(sizeof(size_t) * (after.count + 1));
    size_t shared = 0;
    for (NSNumber *value in after) {
        NSNumber *position = positions[value];
        if (position)
            from[shared++] = position.unsignedIntegerValue;
    }
    unsigned char *stable = malloc(shared + 1);
    RevenantPhotoLongestIncreasingSubsequence(from, shared, stable);
    NSUInteger moves = 0;
    BOOL increasing = YES;
    BOOL seen = NO;
    size_t last = 0;
    for (size_t index = 0; index < shared; index++) {
        if (!stable[index]) {
            moves++;
            continue;
        }
        if (seen && from[index] <= last)
            increasing = NO;
        last = from[index];
        seen = YES;
    }
    *ordered = increasing;
    free(from);
    free(stable);
    return moves;
}

static NSArray *revenant_numbers(NSUInteger from, NSUInteger to)
{
    NSMutableArray *numbers = [NSMutableArray array];
    for (NSUInteger value = from; value < to; value++)
        [numbers addObject:@(value)];
    return numbers;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        NSArray *before = revenant_numbers(0, 4);
        NSArray *rotated = @[@1, @2, @3, @0];
        BOOL ordered = NO;
        NSUInteger moves = revenant_moves_by_helper(before, rotated, &ordered);
        NSUInteger expected = revenant_moves_by_oracle(before, rotated);
        revenant_check(expected == 1, "macOS reports one move for a rotated first item", [NSString stringWithFormat:@"%lu moves", (unsigned long)expected]);
        revenant_check(moves == expected + (revenant_negative ? 1 : 0), "helper counts the rotated first item as one move", [NSString stringWithFormat:@"%lu moves", (unsigned long)moves]);
        revenant_check(ordered, "the items that stay are in order", @"stable items out of order");

        size_t values[] = {1, 2, 3, 0};
        unsigned char stable[4] = {9, 9, 9, 9};
        RevenantPhotoLongestIncreasingSubsequence(values, 4, stable);
        revenant_check(stable[0] && stable[1] && stable[2] && !stable[3], "longest increasing subsequence keeps 1, 2, 3", @"wrong subsequence");

        NSArray *reversed = @[@2, @1, @0];
        moves = revenant_moves_by_helper(revenant_numbers(0, 3), reversed, &ordered);
        expected = revenant_moves_by_oracle(revenant_numbers(0, 3), reversed);
        revenant_check(moves == expected && expected == 2, "a reversed list of three moves two items", [NSString stringWithFormat:@"%lu moves, macOS %lu", (unsigned long)moves, (unsigned long)expected]);

        for (NSUInteger round = 0; round < 2000; round++) {
            NSUInteger beforeCount = revenant_random(11);
            NSMutableArray *after = [NSMutableArray array];
            for (NSUInteger value = 0; value < beforeCount; value++) {
                if (revenant_random(4) != 0)
                    [after addObject:@(value)];
            }
            NSUInteger added = revenant_random(3);
            for (NSUInteger value = 0; value < added; value++)
                [after insertObject:@(beforeCount + value) atIndex:revenant_random((uint32_t)after.count + 1)];
            if (revenant_random(2) == 0) {
                for (NSUInteger index = after.count; index > 1; index--)
                    [after exchangeObjectAtIndex:index - 1 withObjectAtIndex:revenant_random((uint32_t)index)];
            }
            NSArray *source = revenant_numbers(0, beforeCount);
            ordered = NO;
            moves = revenant_moves_by_helper(source, after, &ordered);
            expected = revenant_moves_by_oracle(source, after);
            revenant_check(moves == expected && ordered, "helper matches the macOS move count on a random change", [NSString stringWithFormat:@"round %lu: %lu moves, macOS %lu, ordered %d", (unsigned long)round, (unsigned long)moves, (unsigned long)expected, ordered]);
        }
    }
    return revenant_finish();
}
