#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

struct event {
    uint32_t sec;
    uint32_t usec;
    uint16_t type;
    uint16_t code;
    int32_t value;
};

int main(int argc, char **argv)
{
    int fd = open(argc > 1 ? argv[1] : "/dev/input/event0", O_RDONLY);
    if (fd < 0)
        return 1;
    setvbuf(stdout, NULL, _IONBF, 0);
    struct event ev;
    int x = -1, y = -1, down = 0;
    long start = 0;
    while (read(fd, &ev, sizeof ev) == sizeof ev) {
        long ms = (long)ev.sec * 1000L + ev.usec / 1000;
        if (ev.type == 3 && (ev.code == 0x35 || ev.code == 0x00))
            x = ev.value;
        else if (ev.type == 3 && (ev.code == 0x36 || ev.code == 0x01))
            y = ev.value;
        else if (ev.type == 1 && ev.code == 0x14a) {
            if (ev.value) {
                down = 1;
                start = ms;
            } else if (down) {
                down = 0;
                printf("%d %d %ld\n", x, y, ms - start);
            }
        }
    }
    return 0;
}
