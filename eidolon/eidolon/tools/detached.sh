#!/bin/sh
# detached.sh: run a command in its own session so a tool call ending does not take it down.
#
#     detached.sh <log> <command> [args...]
#
# Prints the child's pid. The child's output goes to <log>, appended. The child is a fork that calls setsid and then
# execs the command, so it outlives the shell that started it; the parent exits at once. perl is used for the fork
# because the shell has no way to detach a process without a trailing `&`, and the Lua sandbox cannot start one.
log=$1
shift
exec perl -MPOSIX=setsid -e '
    my $log = shift @ARGV;
    my $pid = fork();
    die "fork: $!" unless defined $pid;
    if ($pid) {
        print "$pid\n";
        exit 0;
    }
    setsid();
    open(STDIN, "<", "/dev/null");
    open(STDOUT, ">>", $log) or die "open $log: $!";
    open(STDERR, ">&", \*STDOUT) or die "dup: $!";
    exec { $ARGV[0] } @ARGV or die "exec $ARGV[0]: $!";
' "$log" "$@"
