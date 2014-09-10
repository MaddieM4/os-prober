#define _GNU_SOURCE
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <sched.h>

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "Usage: newns PROGRAM [ARGUMENTS ...]\n");
        exit(1);
    }

    // We are not targeting any systems old enough not to support
    // unshare(CLONE_NEWNS). Require it to continue.
    if (unshare(CLONE_NEWNS) < 0 && errno != ENOSYS) {
        perror("unshare failed (needed to prevent side effects, see man unshare)");
        _exit(1);
    }
    setenv("OS_PROBER_NEWNS", "1", 1);
    execvp(argv[1], argv + 1);

    perror("execvp failed");
    _exit(127);
}
