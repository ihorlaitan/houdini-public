#ifndef task_ports_h
#define task_ports_h

#include <mach/mach.h>

mach_port_t find_task_port_for_path(char* path);

pid_t find_pid_for_path(char *);

mach_port_t
find_task_port_for_pid(pid_t pid);

struct task_port_list_entry* get_task_ports(mach_port_t task_port);

void
refresh_task_ports_list(mach_port_t task_port);

void
drop_all_task_ports();

#endif
