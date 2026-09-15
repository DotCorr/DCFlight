#include "loader.h"
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

int dcflight_reload_init(dcflight_reload *r, const char *abi, const char *const *names, size_t count) {
    memset(r, 0, sizeof(*r));
    r->functions = calloc(count, sizeof(void *));
    if (!r->functions) return 1;
    if (pthread_mutex_init(&r->mutex, NULL)) { free(r->functions); return 1; }
    r->abi = abi; r->names = names; r->count = count;
    return 0;
}
int dcflight_reload_swap(dcflight_reload *r, const char *path) {
    if (!path || path[0] != '/') return 1;
    /* Only compiler-produced, locally verified libraries are admissible. dlopen
       can execute initializers: this function is NOT an untrusted plugin sandbox. */
    void *candidate = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!candidate) return 2;
    const char *abi = (const char *)dlsym(candidate, "dcflight_reload_abi");
    if (!abi || strcmp(abi, r->abi)) { dlclose(candidate); return 3; }
    void **next = calloc(r->count, sizeof(void *));
    if (!next) { dlclose(candidate); return 4; }
    for (size_t i = 0; i < r->count; i++) {
        next[i] = dlsym(candidate, r->names[i]);
        if (!next[i]) { free(next); dlclose(candidate); return 5; }
    }
    pthread_mutex_lock(&r->mutex);
    void *old = r->handle;
    memcpy(r->functions, next, r->count * sizeof(void *));
    r->handle = candidate; r->generation++;
    /* Waiting for the mutex establishes no in-flight calls through this loader. */
    if (old) dlclose(old);
    pthread_mutex_unlock(&r->mutex);
    free(next);
    return 0;
}
void dcflight_reload_destroy(dcflight_reload *r) {
    pthread_mutex_lock(&r->mutex);
    if (r->handle) dlclose(r->handle);
    r->handle = NULL;
    free(r->functions);
    pthread_mutex_unlock(&r->mutex);
    pthread_mutex_destroy(&r->mutex);
}
