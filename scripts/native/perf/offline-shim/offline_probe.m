// L26 offline probe. Source only. Positive control for the offline shim.
// Usage: offline_probe raw HOST PORT   (BSD socket connect)
//        offline_probe url URL         (NSURLSession request, 5 second timeout)
// Prints REACHED or BLOCKED. Exit code 0 = REACHED, 3 = BLOCKED, 2 = usage error.
#import <Foundation/Foundation.h>
#include <arpa/inet.h>
#include <errno.h>
#include <sys/socket.h>
#include <unistd.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc >= 4 && strcmp(argv[1], "raw") == 0) {
            int fd = socket(AF_INET, SOCK_STREAM, 0);
            struct sockaddr_in address = {0};
            address.sin_family = AF_INET;
            address.sin_port = htons((uint16_t)atoi(argv[3]));
            inet_pton(AF_INET, argv[2], &address.sin_addr);
            int result = connect(fd, (struct sockaddr *)&address, sizeof address);
            int code = errno;
            close(fd);
            if (result == 0) { puts("REACHED raw"); return 0; }
            printf("BLOCKED raw errno=%d\n", code);
            return 3;
        }
        if (argc >= 3 && strcmp(argv[1], "url") == 0) {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@(argv[2])]];
            request.timeoutInterval = 5;
            dispatch_semaphore_t done = dispatch_semaphore_create(0);
            __block BOOL reached = NO;
            __block NSInteger errorCode = 0;
            [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
                if (e) errorCode = e.code; else reached = YES;
                dispatch_semaphore_signal(done);
            }] resume];
            dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
            if (reached) { puts("REACHED url"); return 0; }
            printf("BLOCKED url code=%ld\n", (long)errorCode);
            return 3;
        }
        fputs("usage: offline_probe raw HOST PORT | offline_probe url URL\n", stderr);
        return 2;
    }
}
