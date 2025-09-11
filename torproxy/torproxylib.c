#include "torproxy.h"

// SOCKS4 request (IP only)
req *request_with_ip(const char *ip, uint16_t port) {
    req *r = malloc(reqSize);
    if (!r) {
        perror("malloc");
        exit(1);
    }

    r->ver = 4;                     // SOCKS4
    r->cmd = 1;                     // CONNECT
    r->dstport = htons(port);
    r->dstip = inet_addr(ip);       // convert IP to 32-bit

    memset(r->userid, 0, sizeof(r->userid));
    strncpy((char*)r->userid, USERNAME, sizeof(r->userid) - 1);

    return r;
}

// SOCKS4a request (hostname instead of IP)
req *request_with_hostname(const char *hostname, uint16_t port) {
    size_t hostlen = strlen(hostname);
    size_t total_size = sizeof(req) + hostlen + 1;

    req *r = malloc(total_size);
    if (!r) {
        perror("malloc");
        exit(1);
    }

    r->ver = 4;                     // SOCKS4a
    r->cmd = 1;                     // CONNECT
    r->dstport = htons(port);

    // SOCKS4a magic: set dstip = 0.0.0.1
    r->dstip = htonl(1);

    memset(r->userid, 0, sizeof(r->userid));
    strncpy((char*)r->userid, USERNAME, sizeof(r->userid) - 1);

    // Append hostname after userid
    char *hostname_field = (char*)(r + 1);
    strcpy(hostname_field, hostname);

    return r;
}

// Intercept connect() call
int connect(int s2, const struct sockaddr *sock2, socklen_t addrlen) {
    int s;
    struct sockaddr_in proxy_addr;
    req *r;
    res *rp;
    char buf[512];
    int success;

    // Original connect() pointer
    int (*real_connect)(int, const struct sockaddr*, socklen_t);
    real_connect = dlsym(RTLD_NEXT, "connect");

    // Extract target info
    struct sockaddr_in *target = (struct sockaddr_in *)sock2;
    char ip_str[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &(target->sin_addr), ip_str, sizeof(ip_str));
    uint16_t target_port = ntohs(target->sin_port);

    // Create socket to Tor proxy
    s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) {
        perror("socket");
        return -1;
    }

    memset(&proxy_addr, 0, sizeof(proxy_addr));
    proxy_addr.sin_family = AF_INET;
    proxy_addr.sin_port = htons(PROXYPORT);
    proxy_addr.sin_addr.s_addr = inet_addr(PROXY);

    if (real_connect(s, (struct sockaddr *)&proxy_addr, sizeof(proxy_addr)) < 0) {
        perror("connect proxy");
        close(s);
        return -1;
    }

    printf("[+] Connected to Tor proxy %s:%d\n", PROXY, PROXYPORT);

    // Decide: IP or hostname? Here we always send IP (SOCKS4).
    // Note: ip_str holds dotted-quad from target->sin_addr
    printf("[+] Using SOCKS4 (IP = %s)\n", ip_str);
    r = request_with_ip(ip_str, target_port);

    // Send request
    size_t req_len = reqSize;

    if (write(s, r, req_len) < 0) {
        perror("write");
        free(r);
        close(s);
        return -1;
    }

    // Read response
    memset(buf, 0, sizeof(buf));
    if (read(s, buf, sizeof(res)) < 1) {
        perror("read");
        free(r);
        close(s);
        return -1;
    }

    rp = (res *)buf;
    success = (rp->cmd == 90);

    if (!success) {
        fprintf(stderr, "[-] Proxy connection failed, error code: %d\n", rp->cmd);
        free(r);
        close(s);
        return -1;
    }

    printf("[+] Proxy connection established via Tor\n");

    // Replace original socket with proxy socket
    dup2(s, s2);
    free(r);

    return 0;
}
