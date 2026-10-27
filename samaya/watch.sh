#!/bin/sh
# Noctalia 5.3 buffers at most 64 KiB without a newline. Transport a full
# Samaya frame as smaller lines, then reassemble before decoding in Luau.
# This command is fixed: no titles, URLs, settings or action IDs enter a shell.
samaya status --watch | LC_ALL=C awk '
{
    if (length($0) > 262144) {
        print "!oversized"
        fflush()
        next
    }
    print "B"
    for (i = 1; i <= length($0); i += 8192)
        print "C" substr($0, i, 8192)
    print "E"
    fflush()
}'
printf '!exit\n'
