#import "RevenantWebFind.h"

static NSString *const RevenantFindObject = @"(function(){"
    "var state = {marks: [], index: -1, generation: 0, done: true};"
    "function skipped(node) {"
    "  for (var p = node.parentNode; p; p = p.parentNode) {"
    "    var name = p.nodeName;"
    "    if (name === 'SCRIPT' || name === 'STYLE' || name === 'NOSCRIPT' || name === 'TEXTAREA' || name === 'INPUT' || name === 'SELECT') return true;"
    "    if (p.isContentEditable) return true;"
    "  }"
    "  return false;"
    "}"
    "function unmark() {"
    "  state.generation++;"
    "  for (var i = 0; i < state.marks.length; i++) {"
    "    var span = state.marks[i], parent = span.parentNode;"
    "    if (!parent) continue;"
    "    while (span.firstChild) parent.insertBefore(span.firstChild, span);"
    "    parent.removeChild(span);"
    "    parent.normalize();"
    "  }"
    "  state.marks = [];"
    "  state.index = -1;"
    "  state.done = true;"
    "  return 0;"
    "}"
    "function mark(node, needle) {"
    "  var text = node.nodeValue.toLowerCase(), at = text.indexOf(needle), offset = 0, current = node;"
    "  while (at >= 0) {"
    "    var target = current.splitText(at - offset), rest = target.splitText(needle.length);"
    "    var span = document.createElement('span');"
    "    span.style.backgroundColor = 'yellow';"
    "    target.parentNode.insertBefore(span, target);"
    "    span.appendChild(target);"
    "    state.marks.push(span);"
    "    current = rest;"
    "    offset = at + needle.length;"
    "    at = text.indexOf(needle, offset);"
    "  }"
    "}"
    "function search(query) {"
    "  unmark();"
    "  var generation = state.generation, needle = query ? String(query).toLowerCase() : '';"
    "  if (!needle || !document.body) return 0;"
    "  var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false), nodes = [], node;"
    "  while ((node = walker.nextNode())) {"
    "    if (!skipped(node)) nodes.push(node);"
    "  }"
    "  state.done = false;"
    "  var next = 0;"
    "  function batch() {"
    "    if (generation !== state.generation) return;"
    "    var end = Math.min(next + 200, nodes.length);"
    "    for (; next < end; next++) mark(nodes[next], needle);"
    "    if (next < nodes.length) setTimeout(batch, 0); else state.done = true;"
    "  }"
    "  setTimeout(batch, 0);"
    "  return 0;"
    "}"
    "function poll() {"
    "  return state.marks.length + ' ' + (state.done ? 1 : 0);"
    "}"
    "function step(direction, obstruction) {"
    "  var count = state.marks.length;"
    "  if (!count) return -1;"
    "  var next = 0;"
    "  if (state.index >= 0) {"
    "    state.marks[state.index].style.backgroundColor = 'yellow';"
    "    next = direction > 0 ? (state.index + 1) % count : (state.index + count - 1) % count;"
    "  }"
    "  state.index = next;"
    "  var span = state.marks[next];"
    "  span.style.backgroundColor = 'orange';"
    "  var rect = span.getBoundingClientRect(), visible = window.innerHeight - obstruction;"
    "  if (rect.top < 0 || rect.bottom > visible) {"
    "    window.scrollTo(0, window.pageYOffset + rect.top + rect.height / 2 - visible / 2);"
    "  }"
    "  return next;"
    "}"
    "return {"
    "  search: search,"
    "  step: step,"
    "  poll: poll,"
    "  clear: unmark"
    "};"
    "})()";

static NSString *RevenantFindLiteral(NSString *string)
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[string ?: @""] options:0 error:NULL];
    NSString *array = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [array substringWithRange:NSMakeRange(1, array.length - 2)];
}

@interface UIFindSession (RevenantWebSession)
- (CGFloat)revenant_bottomObstruction;
- (void)revenant_didChangeResults;
@end

@implementation RevenantWebFindSession {
@private
    RevenantWebEvaluator _evaluate;
    NSString *_query;
    UITextSearchOptions *_options;
    NSInteger _resultCount;
    NSInteger _highlightedIndex;
    NSTimer *_timer;
    BOOL _searching;
    BOOL _stepPending;
    UITextStorageDirection _stepDirection;
}

- (instancetype)initWithEvaluator:(RevenantWebEvaluator)evaluator
{
    if ((self = [super init])) {
        _evaluate = [evaluator copy];
        _highlightedIndex = NSNotFound;
    }
    return self;
}

- (NSString *)revenant_call:(NSString *)method argument:(NSString *)argument
{
    NSString *script = [NSString stringWithFormat:@"(function(){if(!window.revenantFind){window.revenantFind=%@;}return window.revenantFind.%@(%@);})()", RevenantFindObject, method, argument];
    return _evaluate ? _evaluate(script) : nil;
}

- (NSInteger)resultCount
{
    return _resultCount;
}

- (NSInteger)highlightedResultIndex
{
    return _highlightedIndex;
}

- (void)performSearchWithQuery:(NSString *)query options:(UITextSearchOptions *)options
{
    [self revenant_stopPolling];
    _query = [query copy];
    _options = options;
    _resultCount = 0;
    _highlightedIndex = NSNotFound;
    _stepPending = NO;
    _searching = YES;
    [self revenant_call:@"search" argument:RevenantFindLiteral(_query ?: @"")];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(revenant_poll) userInfo:nil repeats:YES];
}

- (void)revenant_poll
{
    NSArray *parts = [[self revenant_call:@"poll" argument:@""] componentsSeparatedByString:@" "];
    if (parts.count != 2) {
        _searching = NO;
        [self revenant_stopPolling];
        return;
    }
    NSInteger count = [parts[0] integerValue];
    if (count != _resultCount) {
        _resultCount = count;
        [self revenant_didChangeResults];
    }
    if (![parts[1] boolValue])
        return;
    [self revenant_stopPolling];
    _searching = NO;
    if (_stepPending) {
        _stepPending = NO;
        [self revenant_step:_stepDirection];
    }
    [self revenant_didChangeResults];
}

- (void)highlightNextResultInDirection:(UITextStorageDirection)direction
{
    if (_searching) {
        _stepPending = YES;
        _stepDirection = direction;
        return;
    }
    [self revenant_step:direction];
}

- (void)revenant_step:(UITextStorageDirection)direction
{
    if (!_resultCount)
        return;
    NSString *argument = [NSString stringWithFormat:@"%d,%f", direction == UITextStorageDirectionBackward ? -1 : 1, self.revenant_bottomObstruction];
    _highlightedIndex = [[self revenant_call:@"step" argument:argument] integerValue];
}

- (void)invalidateFoundResults
{
    [self performSearchWithQuery:_query options:_options];
}

- (void)revenant_clearHighlight
{
    [self revenant_stopPolling];
    _searching = NO;
    _stepPending = NO;
    [self revenant_call:@"clear" argument:@""];
    _resultCount = 0;
    _highlightedIndex = NSNotFound;
}

- (void)revenant_stopPolling
{
    [_timer invalidate];
    _timer = nil;
}

@end
