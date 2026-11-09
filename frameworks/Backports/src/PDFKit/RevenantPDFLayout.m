#import "RevenantPDFLayout.h"

@implementation RevenantPDFLayout {
    NSUInteger _count;
    CGSize *_sizes;
    CGRect *_frames;
    NSUInteger *_rowStarts;
    NSUInteger *_rowOfPage;
    NSUInteger _rowCount;
    RevenantPDFLayoutMode _mode;
    RevenantPDFLayoutDirection _direction;
    BOOL _displaysPageBreaks;
    BOOL _displaysAsBook;
    BOOL _rightToLeft;
    RevenantPDFInsets _margins;
    CGSize _contentSize;
}

- (instancetype)initWithPageSizes:(const CGSize *)sizes
                            count:(NSUInteger)count
                      displayMode:(RevenantPDFLayoutMode)mode
                        direction:(RevenantPDFLayoutDirection)direction
               displaysPageBreaks:(BOOL)displaysPageBreaks
                          margins:(RevenantPDFInsets)margins
                   displaysAsBook:(BOOL)displaysAsBook
                      rightToLeft:(BOOL)rightToLeft
{
    self = [super init];
    if (self == nil)
        return nil;
    _count = count;
    _mode = mode;
    _direction = direction;
    _displaysPageBreaks = displaysPageBreaks;
    _margins = margins;
    _displaysAsBook = displaysAsBook;
    _rightToLeft = rightToLeft;
    _sizes = calloc(count + 1, sizeof(CGSize));
    _frames = calloc(count + 1, sizeof(CGRect));
    _rowStarts = calloc(count + 2, sizeof(NSUInteger));
    _rowOfPage = calloc(count + 1, sizeof(NSUInteger));
    if (count > 0)
        memcpy(_sizes, sizes, count * sizeof(CGSize));
    BOOL twoUp = mode == RevenantPDFLayoutTwoUp || mode == RevenantPDFLayoutTwoUpContinuous;
    NSUInteger page = 0;
    if (twoUp && displaysAsBook && count > 0) {
        _rowStarts[_rowCount++] = 0;
        page = 1;
    }
    while (page < count) {
        _rowStarts[_rowCount++] = page;
        page += (twoUp && page + 1 < count) ? 2 : 1;
    }
    _rowStarts[_rowCount] = count;
    for (NSUInteger row = 0; row < _rowCount; row++) {
        for (NSUInteger index = _rowStarts[row]; index < _rowStarts[row + 1]; index++)
            _rowOfPage[index] = row;
    }
    for (NSUInteger index = 0; index < count; index++)
        _frames[index] = CGRectNull;
    return self;
}

- (void)dealloc
{
    free(_sizes);
    free(_frames);
    free(_rowStarts);
    free(_rowOfPage);
}

- (NSUInteger)pageCount
{
    return _count;
}

- (CGSize)contentSize
{
    return _contentSize;
}

- (BOOL)continuous
{
    return _mode == RevenantPDFLayoutSinglePageContinuous || _mode == RevenantPDFLayoutTwoUpContinuous;
}

- (BOOL)vertical
{
    return _direction == RevenantPDFLayoutVertical;
}

- (RevenantPDFInsets)padding
{
    return _displaysPageBreaks ? _margins : (RevenantPDFInsets){0, 0, 0, 0};
}

- (CGFloat)pageGap
{
    return _displaysPageBreaks ? _margins.left + _margins.right : 0;
}

- (CGFloat)rowGap
{
    if (!_displaysPageBreaks)
        return 0;
    return [self vertical] ? _margins.top + _margins.bottom : _margins.left + _margins.right;
}

- (NSRange)rowsConsidered:(NSUInteger)currentPage
{
    if (_count == 0)
        return NSMakeRange(0, 0);
    if ([self continuous])
        return NSMakeRange(0, _rowCount);
    return NSMakeRange(_rowOfPage[MIN(currentPage, _count - 1)], 1);
}

- (CGSize)extentOfRow:(NSUInteger)row scale:(CGFloat)scale
{
    CGFloat width = 0;
    CGFloat height = 0;
    NSUInteger first = _rowStarts[row];
    NSUInteger last = _rowStarts[row + 1];
    for (NSUInteger index = first; index < last; index++) {
        width += _sizes[index].width * scale;
        height = MAX(height, _sizes[index].height * scale);
    }
    if (last > first)
        width += [self pageGap] * (last - first - 1);
    return CGSizeMake(width, height);
}

- (void)layoutAtScale:(CGFloat)scale currentPage:(NSUInteger)currentPage crossExtent:(CGFloat)crossExtent
{
    for (NSUInteger index = 0; index < _count; index++)
        _frames[index] = CGRectNull;
    NSRange rows = [self rowsConsidered:currentPage];
    RevenantPDFInsets padding = [self padding];
    CGFloat rowGap = [self rowGap];
    CGFloat pageGap = [self pageGap];
    BOOL vertical = [self vertical];
    CGFloat mainTotal = 0;
    CGFloat crossMaximum = 0;
    for (NSUInteger row = rows.location; row < NSMaxRange(rows); row++) {
        CGSize extent = [self extentOfRow:row scale:scale];
        mainTotal += vertical ? extent.height : extent.width;
        crossMaximum = MAX(crossMaximum, vertical ? extent.width : extent.height);
    }
    if (rows.length > 1)
        mainTotal += rowGap * (rows.length - 1);
    CGSize content;
    if (vertical) {
        content = CGSizeMake(MAX(crossMaximum + padding.left + padding.right, crossExtent), mainTotal + padding.top + padding.bottom);
    } else {
        content = CGSizeMake(mainTotal + padding.left + padding.right, MAX(crossMaximum + padding.top + padding.bottom, crossExtent));
    }
    CGFloat main = vertical ? padding.top : padding.left;
    for (NSUInteger step = 0; step < rows.length; step++) {
        NSUInteger row = (!vertical && _rightToLeft) ? NSMaxRange(rows) - 1 - step : rows.location + step;
        CGSize extent = [self extentOfRow:row scale:scale];
        NSUInteger first = _rowStarts[row];
        NSUInteger last = _rowStarts[row + 1];
        CGFloat x = vertical ? (content.width - extent.width) / 2 : main;
        CGFloat top = vertical ? main : (content.height - extent.height) / 2;
        for (NSUInteger offset = 0; offset < last - first; offset++) {
            NSUInteger index = _rightToLeft ? last - 1 - offset : first + offset;
            CGSize size = CGSizeMake(_sizes[index].width * scale, _sizes[index].height * scale);
            _frames[index] = CGRectMake(x, top + (extent.height - size.height) / 2, size.width, size.height);
            x += size.width + pageGap;
        }
        main += (vertical ? extent.height : extent.width) + rowGap;
    }
    _contentSize = content;
}

- (CGFloat)fitScaleForViewSize:(CGSize)viewSize currentPage:(NSUInteger)currentPage
{
    NSRange rows = [self rowsConsidered:currentPage];
    RevenantPDFInsets padding = [self padding];
    CGFloat availableWidth = viewSize.width - padding.left - padding.right;
    CGFloat availableHeight = viewSize.height - padding.top - padding.bottom;
    BOOL vertical = [self vertical];
    BOOL continuous = [self continuous];
    CGFloat best = INFINITY;
    CGFloat tallest = 0;
    for (NSUInteger row = rows.location; row < NSMaxRange(rows); row++) {
        NSUInteger first = _rowStarts[row];
        NSUInteger last = _rowStarts[row + 1];
        CGFloat width = 0;
        for (NSUInteger index = first; index < last; index++) {
            width += _sizes[index].width;
            tallest = MAX(tallest, _sizes[index].height);
        }
        CGFloat gaps = last > first ? [self pageGap] * (last - first - 1) : 0;
        if ((vertical || !continuous) && width > 0)
            best = MIN(best, (availableWidth - gaps) / width);
    }
    if ((!vertical || !continuous) && tallest > 0)
        best = MIN(best, availableHeight / tallest);
    return (isfinite(best) && best > 0) ? best : 1;
}

- (CGRect)frameOfPageAtIndex:(NSUInteger)index
{
    return index < _count ? _frames[index] : CGRectNull;
}

- (NSIndexSet *)pagesIntersectingRect:(CGRect)rect
{
    NSMutableIndexSet *found = [NSMutableIndexSet indexSet];
    for (NSUInteger index = 0; index < _count; index++) {
        if (!CGRectIsNull(_frames[index]) && CGRectIntersectsRect(_frames[index], rect))
            [found addIndex:index];
    }
    return found;
}

- (NSUInteger)pageNearestToPoint:(CGPoint)point
{
    NSUInteger best = NSNotFound;
    CGFloat bestDistance = INFINITY;
    for (NSUInteger index = 0; index < _count; index++) {
        CGRect frame = _frames[index];
        if (CGRectIsNull(frame))
            continue;
        CGFloat dx = MAX(MAX(CGRectGetMinX(frame) - point.x, point.x - CGRectGetMaxX(frame)), 0);
        CGFloat dy = MAX(MAX(CGRectGetMinY(frame) - point.y, point.y - CGRectGetMaxY(frame)), 0);
        CGFloat distance = dx * dx + dy * dy;
        if (distance < bestDistance) {
            bestDistance = distance;
            best = index;
        }
    }
    return best;
}

- (NSRange)pagesSharingRowWithPageAtIndex:(NSUInteger)index
{
    if (index >= _count)
        return NSMakeRange(NSNotFound, 0);
    NSUInteger row = _rowOfPage[index];
    return NSMakeRange(_rowStarts[row], _rowStarts[row + 1] - _rowStarts[row]);
}

- (NSUInteger)firstPageOfRowAfterPageAtIndex:(NSUInteger)index
{
    if (index >= _count)
        return NSNotFound;
    NSUInteger row = _rowOfPage[index];
    return row + 1 < _rowCount ? _rowStarts[row + 1] : NSNotFound;
}

- (NSUInteger)firstPageOfRowBeforePageAtIndex:(NSUInteger)index
{
    if (index >= _count)
        return NSNotFound;
    NSUInteger row = _rowOfPage[index];
    return row > 0 ? _rowStarts[row - 1] : NSNotFound;
}

@end
