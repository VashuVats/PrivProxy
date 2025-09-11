#include "torproxy.h"



req *request(const char *dstip , const int dstport) {
    req *r = malloc(reqSize);
    if (!r) {
        perror("malloc");
        exit(1);
    }

    r->ver = 4;                     // SOCKS4 version
    r->cmd = 1;                     // CONNECT command
    r->dstport = htons(dstport);    // convert port to network byte order
    r->dstip = inet_addr(dstip);    // convert IP string to 32-bit
    memset(r->userid, 0, 8);        // clear userid
    strncpy((char*)r->userid, USERNAME, 8);

    return r;
}


