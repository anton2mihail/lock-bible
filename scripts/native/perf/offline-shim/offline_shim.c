/*
 * L26 offline shim. Candidate per-simulator-device network block. Source only. Not run in a simulator.
 *
 * What it does: dyld interposes connect, connectx, sendto, sendmsg, and getaddrinfo. Each call fails
 * when the target is an IPv4 or IPv6 address (including loopback), or when a host name must be resolved.
 * Local (AF_UNIX) sockets, XPC, and Mach ports stay available.
 * It writes one line for each blocked call to the file named by OFFLINE_SHIM_LOG (if set).
 * It does not change any host network setting. It acts only in processes that load it.
 */
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <time.h>
#include <unistd.h>

#define SHIM_INTERPOSE(replacement, replacee) \
    __attribute__((used)) static struct { const void *new_fn; const void *old_fn; } \
    shim_interpose_##replacee __attribute__((section("__DATA,__interpose"))) = \
    { (const void *)(unsigned long)&replacement, (const void *)(unsigned long)&replacee }

static void shim_log(const char *function, const char *detail) {
    const char *path = getenv("OFFLINE_SHIM_LOG");
    if (!path || !*path) return;
    int fd = open(path, O_WRONLY | O_APPEND | O_CREAT, 0644);
    if (fd < 0) return;
    char line[512];
    struct timespec now;
    clock_gettime(CLOCK_REALTIME, &now);
    int length = snprintf(line, sizeof line, "%lld.%03ld pid=%d proc=%s event=%s %s\n",
                          (long long)now.tv_sec, now.tv_nsec / 1000000, (int)getpid(),
                          getprogname() ? getprogname() : "?", function, detail ? detail : "");
    if (length > 0) (void)write(fd, line, (size_t)(length < (int)sizeof line ? length : (int)sizeof line - 1));
    close(fd);
}

__attribute__((constructor)) static void shim_loaded(void) { shim_log("loaded", ""); }

static int is_internet(const struct sockaddr *address) {
    return address && (address->sa_family == AF_INET || address->sa_family == AF_INET6);
}

static void describe(const struct sockaddr *address, char *out, size_t size) {
    char text[INET6_ADDRSTRLEN] = "?";
    if (address->sa_family == AF_INET)
        inet_ntop(AF_INET, &((const struct sockaddr_in *)address)->sin_addr, text, sizeof text);
    else if (address->sa_family == AF_INET6)
        inet_ntop(AF_INET6, &((const struct sockaddr_in6 *)address)->sin6_addr, text, sizeof text);
    snprintf(out, size, "family=%d addr=%s", address->sa_family, text);
}

static int shim_connect(int fd, const struct sockaddr *address, socklen_t length) {
    if (is_internet(address)) {
        char detail[128]; describe(address, detail, sizeof detail);
        shim_log("connect-blocked", detail);
        errno = ENETUNREACH;
        return -1;
    }
    return connect(fd, address, length);
}

static int shim_connectx(int fd, const sa_endpoints_t *endpoints, sae_associd_t associd, unsigned int flags,
                         const struct iovec *iov, unsigned int iovcnt, size_t *len, sae_connid_t *connid) {
    if (endpoints && is_internet(endpoints->sae_dstaddr)) {
        char detail[128]; describe(endpoints->sae_dstaddr, detail, sizeof detail);
        shim_log("connectx-blocked", detail);
        errno = ENETUNREACH;
        return -1;
    }
    return connectx(fd, endpoints, associd, flags, iov, iovcnt, len, connid);
}

static ssize_t shim_sendto(int fd, const void *buffer, size_t length, int flags,
                           const struct sockaddr *address, socklen_t address_length) {
    if (is_internet(address)) {
        char detail[128]; describe(address, detail, sizeof detail);
        shim_log("sendto-blocked", detail);
        errno = ENETUNREACH;
        return -1;
    }
    return sendto(fd, buffer, length, flags, address, address_length);
}

static ssize_t shim_sendmsg(int fd, const struct msghdr *message, int flags) {
    if (message && message->msg_name && is_internet((const struct sockaddr *)message->msg_name)) {
        char detail[128]; describe((const struct sockaddr *)message->msg_name, detail, sizeof detail);
        shim_log("sendmsg-blocked", detail);
        errno = ENETUNREACH;
        return -1;
    }
    return sendmsg(fd, message, flags);
}

static int shim_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **result) {
    if (node && *node) {
        char detail[300];
        snprintf(detail, sizeof detail, "host=%.200s", node);
        shim_log("getaddrinfo-blocked", detail);
        if (result) *result = NULL;
        return EAI_NONAME;
    }
    return getaddrinfo(node, service, hints, result);
}

SHIM_INTERPOSE(shim_connect, connect);
SHIM_INTERPOSE(shim_connectx, connectx);
SHIM_INTERPOSE(shim_sendto, sendto);
SHIM_INTERPOSE(shim_sendmsg, sendmsg);
SHIM_INTERPOSE(shim_getaddrinfo, getaddrinfo);
