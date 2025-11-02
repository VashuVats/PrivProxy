#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <dlfcn.h>
#include <netdb.h>
#include <errno.h>
// ---------------------------
// Proxy settings
// ---------------------------
#define PROXY      "127.0.0.1"
// Default Tor SOCKS port is 9050
#define PROXYPORT   9050
#define reqSize sizeof(struct proxy_request)
#define resSize sizeof(struct proxy_response)
#define USERNAME   "torproxy"

// ---------------------------
// Fixed-width integer types
// ---------------------------
typedef unsigned char  int8;
typedef unsigned short int16;
typedef unsigned int   int32;

// ---------------------------
// SOCKS4 request struct
// ---------------------------
struct proxy_request {
    int8 ver;       // version (SOCKS4 = 4)
    int8 cmd;       // command (1 = CONNECT)
    int16 dstport;  // destination port (network byte order)
    int32 dstip;    // destination IP (network byte order)
    unsigned char userid[8]; // userid (max 8 chars)
};
typedef struct proxy_request req;

// ---------------------------
// SOCKS4 response struct
// ---------------------------
struct proxy_response {
    int8 ver;   // null byte (always 0 in SOCKS4)
    int8 cmd;   // result (90 = success, 91+ = fail)
    int16 port; // echoed port (ignored)
    int32 ip;   // echoed IP (ignored)
};
typedef struct proxy_response res;
// ---------------------------
// Function prototypes
// ---------------------------
int connect(int, const struct sockaddr*, socklen_t);

req *request_with_ip(const char *ip, uint16_t port);
req *request_with_hostname(const char *hostname, uint16_t port);
