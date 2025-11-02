#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <net/if_arp.h>
#include <stdint.h>
#include <time.h>
#include <fcntl.h>

typedef struct {
    unsigned char addr[6];
} Mac;

bool chmac(const char *iface, Mac mac) {
    struct ifreq ifr;
    int fd, ret;

    if (!iface || strlen(iface) == 0) {
        fprintf(stderr, "Error: Invalid interface name\n");
        return false;
    }

    fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) {
        perror("socket");
        return false;
    }

    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, iface, IFNAMSIZ-1);
    ifr.ifr_name[IFNAMSIZ-1] = '\0';

    // Check if interface exists
    if (ioctl(fd, SIOCGIFFLAGS, &ifr) < 0) {
        fprintf(stderr, "Error: Interface '%s' not found\n", iface);
        close(fd);
        return false;
    }

    // Bring interface down
    ifr.ifr_flags &= ~IFF_UP;
    if (ioctl(fd, SIOCSIFFLAGS, &ifr) < 0) {
        fprintf(stderr, "Warning: Failed to bring interface down\n");
    }

    // Set MAC address
    ifr.ifr_hwaddr.sa_family = ARPHRD_ETHER;
    memcpy(ifr.ifr_hwaddr.sa_data, mac.addr, 6);
    ret = ioctl(fd, SIOCSIFHWADDR, &ifr);
    
    if (ret < 0) {
        perror("ioctl SIOCSIFHWADDR");
        close(fd);
        return false;
    }

    // Bring interface up
    if (ioctl(fd, SIOCGIFFLAGS, &ifr) == 0) {
        ifr.ifr_flags |= IFF_UP;
        if (ioctl(fd, SIOCSIFFLAGS, &ifr) < 0) {
            fprintf(stderr, "Warning: Failed to bring interface up\n");
        }
    }

    close(fd);
    return true;
}

Mac generatemac(void) {
    Mac mac;
    int fd;
    ssize_t nread;

    // Try to use /dev/urandom for cryptographically secure randomness
    fd = open("/dev/urandom", O_RDONLY);
    if (fd >= 0) {
        nread = read(fd, mac.addr, 6);
        close(fd);
        
        if (nread == 6) {
            // Set locally administered, unicast
            mac.addr[0] &= 0xFE;  // Clear multicast bit
            mac.addr[0] |= 0x02;  // Set locally administered bit
            return mac;
        }
        fprintf(stderr, "Warning: Failed to read from /dev/urandom, falling back to rand()\n");
    } else {
        fprintf(stderr, "Warning: Cannot open /dev/urandom, falling back to rand()\n");
    }

    // Fallback to pseudo-random if /dev/urandom fails
    srand((unsigned int)(getpid() ^ time(NULL)));
    for (int i = 0; i < 6; i++) {
        mac.addr[i] = (unsigned char)(rand() % 256);
    }
    
    // Set locally administered, unicast
    mac.addr[0] &= 0xFE;  // Clear multicast bit
    mac.addr[0] |= 0x02;  // Set locally administered bit
    
    return mac;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s INTERFACE\n", argv[0]);
        fprintf(stderr, "Example: %s eth0\n", argv[0]);
        return 1;
    }

    // Check if running as root
    if (geteuid() != 0) {
        fprintf(stderr, "Error: This program must be run as root\n");
        fprintf(stderr, "Try: sudo %s %s\n", argv[0], argv[1]);
        return 1;
    }

    Mac mac = generatemac();

    printf("Attempting to change MAC address of %s...\n", argv[1]);
    
    if (chmac(argv[1], mac)) {
        printf("✓ Successfully changed MAC of %s to %02X:%02X:%02X:%02X:%02X:%02X\n",
               argv[1],
               mac.addr[0], mac.addr[1], mac.addr[2],
               mac.addr[3], mac.addr[4], mac.addr[5]);
        return 0;
    } else {
        fprintf(stderr, "✗ Failed to change MAC address of %s\n", argv[1]);
        return 1;
    }
}
