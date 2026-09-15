#if !defined(DCFLIGHT_DEVELOPMENT_RELOAD) || DCFLIGHT_DEVELOPMENT_RELOAD != 1
#error "Reload loader is development-only; never compile it into release applications"
#endif
#ifndef DCFLIGHT_RELOAD_LOADER_H
#define DCFLIGHT_RELOAD_LOADER_H
#include <pthread.h>
#include <stddef.h>
typedef struct {
    pthread_mutex_t mutex;
    void *handle;
    const char *abi;
    const char *const *names;
    size_t count;
    void **functions;
    unsigned generation;
} dcflight_reload;
int dcflight_reload_init(dcflight_reload *, const char *, const char *const *, size_t);
/* All calls must hold the mutex, including lookup. Functions may not retain pointers,
   spawn tasks or reenter the loader. The caller owns persistent state. */
int dcflight_reload_swap(dcflight_reload *, const char *absolute_path);
void dcflight_reload_destroy(dcflight_reload *);
#endif
