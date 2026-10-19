#!/bin/sh
# accessibilitychart/mutants.sh - every mutant of the chart and data classes has to be told apart by
# the case of run.sh, and by the failure report run.sh prints.
#
# A differential that examines nothing says it passed, and a mutant that stops the build says nothing
# either. So each mutant here changes one line of the port's own source in a copy of it, rebuilds the
# case against that copy, and has to be held by one of exactly two of the case's verdicts:
#
#   * the comparison's own - a line of the two answers that do not match, *and* the whole diff that
#     run.sh prints when they do not. Both are required: the diff is a promise the first version of the
#     script could not keep, because `set -e` left it at the comparison, and a mutant that dies without
#     ever reaching the diff has not proved the report is reachable either. The suite fails if no mutant
#     dies that way.
#   * the once-only count of the inert contract - a port that wrote a line per call instead of one per
#     member. The graph's three members are the only inert rows in this group, and this is what holds
#     them.
#
# A mutant that survives, one that dies of a build error, and one that dies of anything else are all
# failures of the case, and the script exits on the count of each.
#
# The rules each mutant breaks, in the order the file applies them:
#   M3  setting a title leaves the attributed face of it behind
#   M1  a value built for a category answers 1 for its number, where the measured answer is 0
#   M2  a value built for a number answers an empty string for its category, where it answers nil
#   M4  the two-argument data point initialiser answers an empty array for its additional values,
#       where the measured answer is nil
#   M5  a copy of a chart carries the direction the original was set to, where the system's copy does not
#   M9  a chart's copy carries the frame the original was set to, like M5 for the other dropped field
#  M10  a numeric axis' copy carries the scale the original was set to, like M5 for the third
#   M6  a numeric axis answers a constant for every value its description provider is given
#   M7  the live audio graph holds an ivar, where the host's instance has none
#   M8  the categorical axis' order is the reverse of what it was given
#  M11  a chart's copy deep-copies its series instead of sharing the original's array
#  M12  a chart's copy copies its x axis instead of sharing it
#  M13  a point's copy copies its x value instead of sharing it
#  M14  a series' copy rebuilds the attributed name instead of sharing the original's string
#  M15  -setDataPoints: does nothing
#  M16  -setXValue: answers the very object it was given, where the system answers a copy of it
#  M17  the chart's -setSummary: does nothing, and no other mutant in this list touches a setter of a
#       string-typed property
#  M18  the say-once guard is gone, so the port writes a line for every call
#  M19  a copy of a chart drops the series, where the six vacuous probes made that invisible
#  M20  a copy of a chart drops the additional axes
#  M21  a copy of a chart drops the summary
#  M22  a copy of a numeric axis drops the gridline positions
#  M23  a copy of a point drops the additional values
#  M24  a copy of a point drops the y value
#
# M19 to M24 exist because six of the twenty-three share probes answered "both-nil": the case had set
# those six fields to nil before it made the copy, two nils compare equal, and a port that dropped the
# field entirely printed the same line as one that shared it. The case now sets each of the six before the
# copy, and each of these six mutants drops one, so each has to turn its own line red.

# Usage: sh tests/backports/host/accessibilitychart/mutants.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
package=$root/packages/a/apple-backports
sources=${ACCESSIBILITY_SRC:-$package/Accessibility}
work=${BUILD:-$(runs_folder charon-accessibilitychart-mutants)}
rm -rf "$work"
mkdir -p "$work"
survived=0
ran=0
killed_by_diff=0
killed_by_say_once=0
died_wrong=0

mutant() {
    # name, which occurrence of the line, the line, what it becomes
    name=$1
    nth=$2
    old=$3
    new=$4
    if [ -z "$nth" ]; then
        echo "mutant $name does not say which occurrence of its line it changes" >&2
        return 1
    fi
    dir="$work/$name"
    # The copy keeps the package's own shape, because the source reaches its header by a relative path
    # (../CharonSayOnce.h). A copy that did not would stop the build, and a mutant that dies of a build
    # error has told nobody anything - which is what the kill below insists on.
    mkdir -p "$dir/pkg/Accessibility"
    cp "$sources/CharonChartDescriptors.m" "$dir/pkg/Accessibility/"
    cp "$package/CharonSayOnce.h" "$dir/pkg/"
    MUTATE="$dir/pkg/Accessibility/CharonChartDescriptors.m" MUTATE_OLD="$old" MUTATE_NEW="$new" \
        MUTATE_NTH="$nth" python3 "$here/../common/mutate.py"
    ran=$((ran + 1))
    if ACCESSIBILITY_SRC="$dir/pkg/Accessibility" BUILD="$dir/build" sh "$here/run.sh" > "$dir/out.txt" 2>&1; then
        echo "MUTANT SURVIVED: $name"
        survived=$((survived + 1))
        return 0
    fi
    # The two verdicts, and which one caught it. The first needs the diff and not just the comparison's
    # line, because that is the report a reader reads.
    if grep -q 'the two answers do not match what this case declares' "$dir/out.txt" &&
       grep -qE '^(@@|--- |\+\+\+ )' "$dir/out.txt"; then
        killed_by_diff=$((killed_by_diff + 1))
        echo "killed by the diff: $name: $(grep -m1 -E 'UNDECLARED DIFFERENCE|DECLARED DIFFERENCE' "$dir/out.txt")"
        return 0
    fi
    if grep -q 'an inert member says so once' "$dir/out.txt"; then
        killed_by_say_once=$((killed_by_say_once + 1))
        echo "killed by the once-only count: $name: $(grep -m1 'an inert member says so once' "$dir/out.txt")"
        return 0
    fi
    echo "MUTANT DIED FOR THE WRONG REASON: $name"
    tail -5 "$dir/out.txt"
    died_wrong=$((died_wrong + 1))
}

# The same two lines are the title setter of the numeric axis, the categorical axis and the chart, so
# the mutant says which one it changes: the chart's, which is the third of them in the file.
mutant M3-title-faces 3 \
    '    _title = [title copy];
    _attributedTitle = title ? [[NSAttributedString alloc] initWithString:title] : nil;' \
    '    _title = [title copy];'

mutant M1-category-number 1 \
    '    AXDataPointValue *value = [[AXDataPointValue alloc] init];
    value->_category = [category copy];' \
    '    AXDataPointValue *value = [[AXDataPointValue alloc] init];
    value->_number = 1;
    value->_category = [category copy];'

mutant M2-number-category 1 \
    '    AXDataPointValue *value = [[AXDataPointValue alloc] init];
    value->_number = number;' \
    '    AXDataPointValue *value = [[AXDataPointValue alloc] init];
    value->_number = number;
    value->_category = @"";'

mutant M4-point-additional 1 \
    '    return [self initWithX:xValue y:yValue additionalValues:nil label:nil];' \
    '    return [self initWithX:xValue y:yValue additionalValues:@[] label:nil];'

# The three value-typed fields the system's own copy drops. Each mutant puts one back, and each has to
# turn that one case red - this is what pins the parity, where a declared difference could not: a port
# that started agreeing with the host would have passed a "the two agree" check.
mutant M5-chart-copy-direction 1 \
    '    copy->_additionalAxes = _additionalAxes;
    return copy;' \
    '    copy->_additionalAxes = _additionalAxes;
    copy->_contentDirection = _contentDirection;
    return copy;'

mutant M9-chart-copy-frame 1 \
    '    copy->_additionalAxes = _additionalAxes;
    return copy;' \
    '    copy->_additionalAxes = _additionalAxes;
    copy->_contentFrame = _contentFrame;
    return copy;'

# The numeric axis' copy and the categorical axis' copy end in the same two lines, so the mutant says
# which one it changes: the numeric one, the first of the two, which is the only one with a scale.
mutant M10-numeric-copy-scale 1 \
    '       gridlinePositions:_gridlinePositions valueDescriptionProvider:_valueDescriptionProvider];
    copy->_attributedTitle = _attributedTitle;
    return copy;' \
    '       gridlinePositions:_gridlinePositions valueDescriptionProvider:_valueDescriptionProvider];
    copy->_attributedTitle = _attributedTitle;
    copy->_scaleType = _scaleType;
    return copy;'

mutant M6-value-description 1 \
    '- (NSString *(^)(double))valueDescriptionProvider
{
    return _valueDescriptionProvider;
}' \
    '- (NSString *(^)(double))valueDescriptionProvider
{
    NSString *(^held)(double) = ^NSString *(double value) { return @"0"; };
    return held;
}'

mutant M7-graph-ivar 1 \
    '@implementation AXLiveAudioGraph

+ (void)start' \
    '@implementation AXLiveAudioGraph {
    int _held;
}

+ (void)start'

mutant M8-category-order 1 \
    '        _categoryOrder = [categoryOrder copy];' \
    '        _categoryOrder = [[categoryOrder reverseObjectEnumerator] allObjects];'

# The four shares, which are the rules the identity probe exists for. A port that handed back copies
# where the system hands back the very objects passes every value the case prints.
mutant M11-chart-copy-series-deep 1 \
    '    copy->_attributedTitle = _attributedTitle;
    copy->_additionalAxes = _additionalAxes;' \
    '    copy->_attributedTitle = _attributedTitle;
    copy->_series = [[NSArray alloc] initWithArray:_series copyItems:YES];
    copy->_additionalAxes = _additionalAxes;'

mutant M12-chart-copy-xaxis-deep 1 \
    '    copy->_attributedTitle = _attributedTitle;
    copy->_additionalAxes = _additionalAxes;' \
    '    copy->_attributedTitle = _attributedTitle;
    copy->_xAxis = (id<AXDataAxisDescriptor>)[(id)_xAxis copy];
    copy->_additionalAxes = _additionalAxes;'

mutant M13-point-copy-xvalue-deep 1 \
    '    copy->_additionalValues = _additionalValues;
    [copy setLabel:_label];' \
    '    copy->_additionalValues = _additionalValues;
    copy->_xValue = [_xValue copy];
    [copy setLabel:_label];'

mutant M14-series-copy-attributed-deep 1 \
    '    copy->_attributedName = _attributedName;
    return copy;' \
    '    copy->_attributedName = [[NSAttributedString alloc] initWithString:_name];
    return copy;'

# Two setters, one deleted and one changed, which the case reaches only through its setter probes.
mutant M15-set-datapoints-noop 1 \
    '- (void)setDataPoints:(NSArray<AXDataPoint *> *)dataPoints
{
    _dataPoints = [dataPoints copy];
}' \
    '- (void)setDataPoints:(NSArray<AXDataPoint *> *)dataPoints
{
}'

mutant M16-set-xvalue-shares 1 \
    '- (void)setXValue:(AXDataPointValue *)xValue
{
    _xValue = [xValue copy];
}' \
    '- (void)setXValue:(AXDataPointValue *)xValue
{
    _xValue = xValue;
}'

mutant M17-set-summary-noop 1 \
    '- (void)setSummary:(NSString *)summary
{
    _summary = [summary copy];
}' \
    '- (void)setSummary:(NSString *)summary
{
}'

# The once-only guard, in the header every file of this library reaches. The graph is the only inert
# member in this group, and "says so once in the log" is the whole of what the status claims.
mkdir -p "$work/M18-say-once/pkg/Accessibility"
cp "$sources/CharonChartDescriptors.m" "$work/M18-say-once/pkg/Accessibility/"
cp "$package/CharonSayOnce.h" "$work/M18-say-once/pkg/"
# The copy, and never the tree's file: the first version of this pointed the mutator at
# packages/a/apple-backports/CharonSayOnce.h and edited it in place, which is the one thing a mutant
# must not do.
MUTATE="$work/M18-say-once/pkg/CharonSayOnce.h" MUTATE_OLD='    @synchronized (said) {
        if ([said containsObject:key])
            return;
        [said addObject:key];
    }' MUTATE_NEW='    @synchronized (said) {
        [said addObject:key];
    }' MUTATE_NTH=1 python3 "$here/../common/mutate.py"
ran=$((ran + 1))
if ACCESSIBILITY_SRC="$work/M18-say-once/pkg/Accessibility" BUILD="$work/M18-say-once/build" \
   sh "$here/run.sh" > "$work/M18-say-once/out.txt" 2>&1; then
    echo "MUTANT SURVIVED: M18-say-once"
    survived=$((survived + 1))
elif grep -q 'an inert member says so once' "$work/M18-say-once/out.txt"; then
    killed_by_say_once=$((killed_by_say_once + 1))
    echo "killed by the once-only count: M18-say-once: $(grep -m1 'an inert member says so once' "$work/M18-say-once/out.txt")"
else
    echo "MUTANT DIED FOR THE WRONG REASON: M18-say-once"
    tail -5 "$work/M18-say-once/out.txt"
    died_wrong=$((died_wrong + 1))
fi

# The six drops. Each one is a field the case's copy block now sets before it copies, so the copy has
# something to share and the probe has a question; before the case was fixed, each of these six was a
# no-op the comparison could not see.
mutant M19-chart-copy-series-drop 1 \
    '                                                                          series:_series];' \
    '                                                                          series:nil];'

mutant M20-chart-copy-axes-drop 1 \
    '    copy->_additionalAxes = _additionalAxes;' \
    '    copy->_additionalAxes = nil;'

mutant M21-chart-copy-summary-drop 1 \
    '                                                                           summary:_summary' \
    '                                                                           summary:nil'

mutant M22-numeric-copy-gridlines-drop 1 \
    '       gridlinePositions:_gridlinePositions valueDescriptionProvider:_valueDescriptionProvider];' \
    '       gridlinePositions:nil valueDescriptionProvider:_valueDescriptionProvider];'

mutant M23-point-copy-additional-drop 1 \
    '    copy->_additionalValues = _additionalValues;' \
    '    copy->_additionalValues = nil;'

mutant M24-point-copy-yvalue-drop 1 \
    '    AXDataPoint *copy = [[AXDataPoint allocWithZone:zone] initWithX:_xValue y:_yValue];' \
    '    AXDataPoint *copy = [[AXDataPoint allocWithZone:zone] initWithX:_xValue y:nil];'

echo "mutants run: $ran, killed by the diff: $killed_by_diff, killed by the once-only count: $killed_by_say_once, died for another reason: $died_wrong, survived: $survived"
# The diff is a promise the case makes on every failure, so the suite has to have exercised it at least
# once or it has not been shown to be kept.
[ "$survived" -eq 0 ] && [ "$died_wrong" -eq 0 ] && [ "$killed_by_diff" -gt 0 ] && [ "$killed_by_say_once" -gt 0 ] \
    && [ $((killed_by_diff + killed_by_say_once)) -eq "$ran" ]
