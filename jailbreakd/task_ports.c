#include <stdio.h>
#include <stdlib.h>

#include <mach/mach.h>

#include "task_ports.h"

#include "remote_call.h"
#include "remote_memory.h"
#include "remote_ports.h"

mach_port_t privileged_task_port = MACH_PORT_NULL;

mach_port_t launchd_port = MACH_PORT_NULL;
mach_port_t houdini_port = MACH_PORT_NULL;

// not in iOS SDK:
extern int proc_pidpath(int pid, void * buffer, uint32_t buffersize);

// use processor_set_tasks to get all the task ports which the given task port can see:
void get_task_ports(mach_port_t task_port) {
    kern_return_t err;

    // get the remote host port:
    mach_port_t remote_host_port_name = MACH_PORT_NULL;
    err = (int) call_remote(task_port, task_get_special_port, 3, REMOTE_LITERAL(0x103), REMOTE_LITERAL(TASK_HOST_PORT), REMOTE_OUT_BUFFER(&remote_host_port_name, sizeof(remote_host_port_name)) );

  
    // get the default processor set port:
    mach_port_t remote_default_processor_set_port_name = MACH_PORT_NULL;
    err = (int) call_remote(task_port, processor_set_default, 2, REMOTE_LITERAL(remote_host_port_name), REMOTE_OUT_BUFFER(&remote_default_processor_set_port_name, sizeof(remote_default_processor_set_port_name)) );

    // get the priv port:
    mach_port_t ps_control = MACH_PORT_NULL;
    err = (int) call_remote(task_port, host_processor_set_priv, 3, REMOTE_LITERAL(remote_host_port_name), REMOTE_LITERAL(remote_default_processor_set_port_name), REMOTE_OUT_BUFFER(&ps_control, sizeof(ps_control)));

    // get the processor set tasks
    mach_port_t* task_ports = NULL;
    mach_msg_type_number_t task_portsCnt = 0;
    err = (int) call_remote(task_port, processor_set_tasks, 3, REMOTE_LITERAL(ps_control), REMOTE_OUT_BUFFER(&task_ports, sizeof(task_ports)), REMOTE_OUT_BUFFER(&task_portsCnt, sizeof(task_portsCnt)));

    // get those port names:
    // (should also vm_deallocate the remote buffer)
    mach_port_t* actual_task_port_names = malloc(task_portsCnt*sizeof(mach_port_t));
    remote_read_overwrite(task_port, (uint64_t)task_ports, (uint64_t)actual_task_port_names, task_portsCnt*sizeof(mach_port_t));

    // allocate a remote buffer to get the proc paths:
    uint64_t remote_path_buffer_size = 1024;
    uint64_t remote_path_buffer = remote_alloc(task_port, remote_path_buffer_size);

    char* local_path_buffer = malloc(remote_path_buffer_size);

    // pull the send rights into this processes
    struct task_port_list_entry* port_list_head = NULL;
  
    // reset houdini's port
    houdini_port = MACH_PORT_NULL;
    
    for (int i = 0; i < task_portsCnt; i++){

        // stop when we have houdini's port
        if(houdini_port != MACH_PORT_NULL) {
            break;
        }

        mach_port_t remote_name = actual_task_port_names[i];
        mach_port_t local_name = pull_remote_port(task_port, remote_name, MACH_MSG_TYPE_COPY_SEND);
        actual_task_port_names[i] = local_name;

        pid_t task_pid = 0;
        err = pid_for_task(local_name, &task_pid);
        if (err != KERN_SUCCESS)
            continue;

        err = (int) call_remote(task_port, proc_pidpath, 3, REMOTE_LITERAL(task_pid), REMOTE_LITERAL(remote_path_buffer), REMOTE_LITERAL(remote_path_buffer_size));
        if (err == 0)
            continue;

        // copy the remote buffer back here:
        remote_read_overwrite(task_port, remote_path_buffer, (uint64_t)local_path_buffer, remote_path_buffer_size);


//        printf("[XXX]: found %s\n", local_path_buffer);
        if(strstr(local_path_buffer, "houdini")) {
            houdini_port = local_name;

        }


        // we need launchd's port once
        if(strstr(local_path_buffer, "launchd")) {
                launchd_port = local_name;
        }
      
    }
  
    free(actual_task_port_names);
    free(local_path_buffer);
}

void refresh_task_ports_list() {
    
  while(privileged_task_port == MACH_PORT_NULL) {;}
  get_task_ports(privileged_task_port);
}
