#!/bin/sh
# mutate.sh - the two functions the mutation campaign uses, and nothing else. It defines them and does
# not run them, so a test can source it without starting a campaign: mutation.sh runs its campaign on
# the spot, which is why a test that sourced it found no function to call.
#
# mutate FILE SITE [WANT_INS WANT_DEL] reads the anchor and the replacement from
# mutants/SITE.anchor and mutants/SITE.repl, so no shell ever parses them: an anchor of C source
# carries ) " and $x, and a heredoc is still a delimiter that a line of the text can end. Each mutant
# is two files a reader can look at. The default is one insertion and one deletion; a site whose
# replacement is a comment and a loop over a one-line comment anchor says 2 1.
mutate() {
    _file=$1; _site=$2; _want_ins=${3:-1}; _want_del=${4:-1}
    _dir=${MUTANTS_DIR:-$(dirname "$0")/mutants}
    _anchor_file="$_dir/$_site.anchor"; _repl_file="$_dir/$_site.repl"
    for _f in "$_anchor_file" "$_repl_file"; do
        if [ ! -f "$_f" ]; then
            echo "the mutant $_site has no $_f" >&2
            return 1
        fi
    done
    _copy="$work/$(basename "$_file").original"
    # the count and the substitution are the same question, so python answers both: a line-oriented
    # grep -f counts matching LINES, and a three-line anchor then reads as three occurrences in a file
    # that holds it once
    if ! python3 - "$_file" "$_copy" "$_anchor_file" "$_repl_file" "$_site" <<'PYEOF'
import sys
path, copy, anchor_path, repl_path = sys.argv[1:5]
# exactly one trailing newline is the file's, not the text's
anchor = open(anchor_path).read()
repl = open(repl_path).read()
if anchor.endswith('\n'): anchor = anchor[:-1]
if repl.endswith('\n'): repl = repl[:-1]
text = open(path).read()
n = text.count(anchor)
if n != 1:
    sys.stderr.write('the anchor of %s occurs %d times in %s, and a mutation needs exactly one:\n'
                     % (sys.argv[5], n, path))
    sys.stderr.write(''.join('  %s\n' % l for l in anchor.split('\n')))
    sys.exit(1)
open(copy, 'w').write(text)
open(path, 'w').write(text.replace(anchor, repl, 1))
PYEOF
    then
        return 1
    fi
    _ins=$(diff "$_copy" "$_file" | grep -c '^>')
    _del=$(diff "$_copy" "$_file" | grep -c '^<')
    if [ "$_ins" -ne "$_want_ins" ] || [ "$_del" -ne "$_want_del" ]; then
        printf 'the mutation of %s changed %s insertion(s) and %s deletion(s) of %s, and it must change %s and %s\n' \
            "$_site" "$_ins" "$_del" "$_file" "$_want_ins" "$_want_del" >&2
        printf '  the file is put back, so a refusal leaves nothing mutated\n' >&2
        cp "$_copy" "$_file"
        return 1
    fi
    printf 'mutated: %s: %s insertion(+), %s deletion(-)\n' "$_file" "$_ins" "$_del"
}
restore() { git show "HEAD:$kernel" > "$kernel"; }
