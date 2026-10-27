#import "RevenantWebFind.h"

static NSString *const RevenantFindObject = @"(function(){"
    "var state = {marks: [], index: -1};"
    "function skipped(node) {"
    "  for (var p = node.parentNode; p; p = p.parentNode) {"
    "    var name = p.nodeName;"
    "    if (name === 'SCRIPT' || name === 'STYLE' || name === 'NOSCRIPT' || name === 'TEXTAREA' || name === 'INPUT' || name === 'SELECT') return true;"
    "    if (p.isContentEditable) return true;"
    "  }"
    "  return false;"
    "}"
    "function unmark() {"
    "  for (var i = 0; i < state.marks.length; i++) {"
    "    var span = state.marks[i], parent = span.parentNode;"
    "    if (!parent) continue;"
    "    while (span.firstChild) parent.insertBefore(span.firstChild, span);"
    "    parent.removeChild(span);"
    "    parent.normalize();"
    "  }"
    "  state.marks = [];"
    "  state.index = -1;"
    "  return 0;"
    "}"
    "function search(query) {"
    "  unmark();"
    "  if (!query || !document.body) return 0;"
    "  var needle = query.toLowerCase(), walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false), nodes = [], node;"
    "  while ((node = walker.nextNode())) nodes.push(node);"
    "  for (var i = 0; i < nodes.length; i++) {"
    "    node = nodes[i];"
    "    if (skipped(node)) continue;"
    "    var text = node.nodeValue.toLowerCase(), at = text.indexOf(needle), offset = 0, current = node;"
    "    while (at >= 0) {"
    "      var target = current.splitText(at - offset), rest = target.splitText(needle.length);"
    "      var span = document.createElement('span');"
    "      span.style.backgroundColor = 'yellow';"
    "      target.parentNode.insertBefore(span, target);"
    "      span.appendChild(target);"
    "      state.marks.push(span);"
    "      current = rest;"
    "      offset = at + needle.length;"
    "      at = text.indexOf(needle, offset);"
    "    }"
    "  }"
    "  return state.marks.length;"
    "}"
    "function step(direction) {"
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
    "  var top = span.getBoundingClientRect().top + window.pageYOffset;"
    "  window.scrollTo(0, top - window.innerHeight / 2);"
    "  return next;"
    "}"
    "return {"
    "  search: search,"
    "  step: step,"
    "  clear: unmark"
    "};"
    "})()";

static NSString *RevenantFindLiteral(NSString *string)
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[string ?: @""] options:0 error:NULL];
    NSString *array = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [array substringWithRange:NSMakeRange(1, array.length - 2)];
}

@implementation RevenantWebFindSession {
@private
    RevenantWebEvaluator _evaluate;
    NSString *_query;
    UITextSearchOptions *_options;
    NSInteger _resultCount;
    NSInteger _highlightedIndex;
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
    _query = [query copy];
    _options = options;
    _resultCount = [[self revenant_call:@"search" argument:RevenantFindLiteral(_query ?: @"")] integerValue];
    _highlightedIndex = NSNotFound;
}

- (void)highlightNextResultInDirection:(UITextStorageDirection)direction
{
    if (!_resultCount)
        return;
    NSString *step = direction == UITextStorageDirectionBackward ? @"-1" : @"1";
    _highlightedIndex = [[self revenant_call:@"step" argument:step] integerValue];
}

- (void)invalidateFoundResults
{
    [self performSearchWithQuery:_query options:_options];
}

- (void)revenant_clearHighlight
{
    [self revenant_call:@"clear" argument:@""];
    _resultCount = 0;
    _highlightedIndex = NSNotFound;
}

@end
