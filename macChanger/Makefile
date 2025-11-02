CC = gcc
CFLAGS = -O3 -Wall -std=c2x

all: macChange

macChange: macChange.o
	$(CC) $(CFLAGS) $^ -o $@

macChange.o: macChange.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f macChange *.o

.PHONY: all clean