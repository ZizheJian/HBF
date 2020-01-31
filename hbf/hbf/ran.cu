#include <iostream>
#include <cstdio>

int main()
{
	freopen("hbf.txt", "w", stdout);
	srand(time(null));
	int n = 1000;
	int m = ((rand() * rand()) % 900000) * rand()) % 900000;
	m = m + 1000;
	printf("%d %d\n", n, m);
	for (int i = 1;i <= m;i++)
	{
		printf("%d %d %d\n", rand() % n + 1, rand() % n + 1, rand() % 100 + 1);
	}
	fclose(stdout);
}