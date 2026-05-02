#include <sys/sysctl.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdio.h>

struct mem {
  // Memory pressure: 0 = no pressure, 100 = critical
  // Derived from kern.memorystatus_level (available memory %)
  int pressure;
};

static inline void mem_init(struct mem* mem) {
  mem->pressure = 0;
}

static inline void mem_update(struct mem* mem) {
  int level = 0;
  size_t size = sizeof(level);

  // kern.memorystatus_level: 0-100, where 100 = plenty of memory available
  if (sysctlbyname("kern.memorystatus_level", &level, &size, NULL, 0) != 0) {
    printf("Error: Could not read kern.memorystatus_level.\n");
    return;
  }

  // Invert: pressure = how stressed memory is (100 = critical, 0 = fine)
  mem->pressure = 100 - level;
}
