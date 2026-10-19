#!/bin/bash
# emu-loop.sh PREFIX: run octests in iLEmu; on a crash skip the crashing test and resume after it, until the runner finishes
cd "$(dirname "$0")/.."
P=${1:-ocl}; ST=${STAGE:-combine/out-ios/stage}; cp ${SKIPLIST:-combine/xct-skip-ios.txt} $ST/xct-skip.txt; rm -f $ST/xct-resume.txt
for i in $(seq 1 40); do
  n=$P$i; rm -rf runs.noindex/$n
  start=$(date +%s); ALARM=${ALARM:-1500} ./run-emu.sh $n $ST octests >/dev/null 2>&1
  L=runs.noindex/$n/log; grep -E "^Test Case|error: |^Executed" $L | sed 's/\[[a-z-]*\].*//' > runs.noindex/$n/tests.txt
  echo "$n: $(( $(date +%s) - start ))s passed=$(grep -c "' passed" $L) failed=$(grep -c "' failed" $L)"
  if grep -q "^Executed" $L; then grep "^Executed" $L; break; fi
  last=$(grep -o "Test Case '[^']*' started" $L | tail -1 | sed "s/Test Case '//; s/' started//")
  [ -z "$last" ] && { echo "no test started; stop"; break; }
  echo "  crash in $last: $(grep '\[cpu\] fatal' $L | head -1 | cut -c1-120)"
  echo "$last" >> $ST/xct-skip.txt; echo "$last" > $ST/xct-resume.txt
  rm -f runs.noindex/$n/log.gz; gzip -f $L
done
