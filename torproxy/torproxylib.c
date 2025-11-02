#include "torproxy.h"

// Helper function to check if address is a hostname (not an IP)
static int is_hostname(const struct sockaddr_in *addr) {
    // If the address is in the private/local range, it's likely resolved
    // For SOCKS4a, we want to send hostnames to Tor for DNS resolution
    // This is a simplified check - in practice, we'd need to track original hostnames
    return 0; // For now, always use IP (SOCKS4)
}

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
    req *r = NULL;
    res *rp;
    char buf[512];
    int success;
    size_t req_len;

    // Original connect() pointer
    int (*real_connect)(int, const struct sockaddr*, socklen_t);
    real_connect = dlsym(RTLD_NEXT, "connect");
    if (!real_connect) {
        fprintf(stderr, "[-] Failed to load original connect(): %s\n", dlerror());
        errno = ENOSYS;
        return -1;
    }

    // Only intercept IPv4 TCP connections
    if (sock2->sa_family != AF_INET) {
        return real_connect(s2, sock2, addrlen);
    }

    // Extract target info
    struct sockaddr_in *target = (struct sockaddr_in *)sock2;
    char ip_str[INET_ADDRSTRLEN];
    if (!inet_ntop(AF_INET, &(target->sin_addr), ip_str, sizeof(ip_str))) {
        perror("inet_ntop");
        return -1;
    }
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
    
    if (proxy_addr.sin_addr.s_addr == INADDR_NONE) {
        fprintf(stderr, "[-] Invalid proxy address: %s\n", PROXY);
        close(s);
        errno = EINVAL;
        return -1;
    }

    if (real_connect(s, (struct sockaddr *)&proxy_addr, sizeof(proxy_addr)) < 0) {
        perror("connect proxy");
        close(s);
        return -1;
    }

    printf("[+] Connected to Tor proxy %s:%d\n", PROXY, PROXYPORT);

    // Use SOCKS4 with IP address
    // Note: For true SOCKS4a with hostname resolution, we'd need to intercept
    // getaddrinfo/gethostbyname and preserve the original hostname
    printf("[+] Using SOCKS4 (IP = %s, Port = %d)\n", ip_str, target_port);
    r = request_with_ip(ip_str, target_port);
    if (!r) {
        fprintf(stderr, "[-] Failed to create SOCKS request\n");
        close(s);
        errno = ENOMEM;
        return -1;
    }

    // Send request
    req_len = reqSize;

    ssize_t written = write(s, r, req_len);
    if (written < 0) {
        perror("write");
        free(r);
        close(s);
        return -1;
    }
    if ((size_t)written != req_len) {
        fprintf(stderr, "[-] Incomplete write to proxy: %zd/%zu bytes\n", written, req_len);
        free(r);
        close(s);
        errno = EIO;
        return -1;
    }

    // Read response
    memset(buf, 0, sizeof(buf));
    ssize_t nread = read(s, buf, sizeof(res));
    if (nread < (ssize_t)sizeof(res)) {
        if (nread < 0) {
            perror("read");
        } else {
            fprintf(stderr, "[-] Incomplete response from proxy: %zd bytes\n", nread);
        }
        free(r);
        close(s);
        return -1;
    }

    rp = (res *)buf;
    success = (rp->cmd == 90);

    if (!success) {
        const char *error_msg;
        switch (rp->cmd) {
            case 91: error_msg = "Request rejected or failed"; break;
            case 92: error_msg = "Request rejected: SOCKS server cannot connect to identd"; break;
            case 93: error_msg = "Request rejected: client and identd report different user-ids"; break;
            default: error_msg = "Unknown error"; break;
        }
        fprintf(stderr, "[-] Proxy connection failed (code %d): %s\n", rp->cmd, error_msg);
        free(r);
        close(s);
        errno = ECONNREFUSED;
        return -1;
    }

    printf("[+] Proxy connection established via Tor\n");

    // Replace original socket with proxy socket
    if (dup2(s, s2) < 0) {
        perror("dup2");
        free(r);
        close(s);
        return -1;
    }
    
    close(s);
    free(r);

    return 0;
}
