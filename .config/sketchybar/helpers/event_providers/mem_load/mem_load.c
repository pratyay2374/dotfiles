#include "mem.h"
#include "../sketchybar.h"

int main(int argc, char** argv) {
  float update_freq;
  if (argc < 3 || (sscanf(argv[2], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<event-name>\" \"<event_freq>\"\n", argv[0]);
    exit(1);
  }

  alarm(0);
  struct mem mem;
  mem_init(&mem);

  // Register the event in sketchybar
  char event_message[512];
  snprintf(event_message, 512, "--add event '%s'", argv[1]);
  sketchybar(event_message);

  char trigger_message[512];
  for (;;) {
    mem_update(&mem);

    snprintf(trigger_message,
             512,
             "--trigger '%s' pressure='%d'",
             argv[1],
             mem.pressure);

    sketchybar(trigger_message);

    usleep(update_freq * 1000000);
  }
  return 0;
}
