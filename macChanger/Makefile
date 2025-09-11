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


/*
The structure of a MAC address is divided into two parts:

Organizationally Unique Identifier (OUI): The first 24 bits (00:1A:2B in the example) represent the manufacturer of the NIC.
Network Interface Controller (NIC) Specific: The last 24 bits (3C:4D:5E) are unique to the device within the manufacturer’s range.

ioctl(4, SIOCSIFHWADDR, {ifr_name="ens192", ifr_hwaddr={sa_family=ARPHRD_ETHER, sa_data=00:0c:29:9f:80:dd}}) = 0
https://linux.die.net/man/2/ioctl
*/