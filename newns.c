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

	/* This is best-effort; if the kernel is too old (Linux << 2.6.16),
	 * or indeed if the kernel isn't Linux so we don't have
	 * unshare(CLONE_NEWNS), don't worry about it.
	 */
#ifdef __linux__
	if (unshare(CLONE_NEWNS) < 0 && errno != ENOSYS)
		perror("unshare failed");
		/* ... but continue anyway */
#endif /* __linux__ */
	setenv("OS_PROBER_NEWNS", "1", 1);
	execvp(argv[1], argv + 1);

	perror("execvp failed");
	_exit(127);
}
