#include <dlfcn.h>
#include <stdint.h>

struct hid_device_info;

struct hid_device_info *hid_get_device_info(void *dev) {
    struct hid_device_info *(*real)(void *) = dlsym(RTLD_NEXT, "hid_get_device_info");
    struct hid_device_info *info = real(dev);
    /* hidapi sometimes returns a small invalid pointer instead of NULL */
    if ((uintptr_t)info < 0x1000)
        return (void *)0;
    return info;
}
