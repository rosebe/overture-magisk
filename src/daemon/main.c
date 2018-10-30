#include <stdio.h>
#include <unistd.h>
#include <malloc.h>

int main(int argc ,char **argv) {
	(void)argc;

	daemon(0 ,0);

	return execvp(argv[1] ,argv+1);
}
