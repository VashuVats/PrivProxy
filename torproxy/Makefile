all:
	gcc torproxy.c -o torproxy
	gcc torproxylib.c -o torproxy.so -fPIC -shared  -ldl  -D_GNU_SOURCE

clean:
	rm -f torproxy torproxy.so


