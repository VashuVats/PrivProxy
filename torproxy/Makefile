all: torproxy.so

torproxy.so: torproxylib.c torproxy.h
	gcc torproxylib.c -o torproxy.so -fPIC -shared -ldl -D_GNU_SOURCE -Wall

clean:
	rm -f torproxy.so *.o


