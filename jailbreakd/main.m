#include <stdio.h>
#include <dlfcn.h>
#include <sys/stat.h>
#include <mach/mach.h>

#include "task_ports.h"
#include "remote_call.h"
#include "remote_ports.h"
#include "remote_memory.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <UIKit/UIKit.h>

int main(int argc, char** argv) {

    
    
    while (1) {
        sleep(2);
        NSLog(@"hello from jailbreakd!");
    }
    
    
    return 0;
    
    refresh_task_ports_list();

    extern mach_port_t launchd_port;
    extern mach_port_t houdini_port;
    
    if (launchd_port == MACH_PORT_NULL) {
        return 0;
    }
    
    mach_port_t old_houdini_port = MACH_PORT_NULL;
    
    sleep(5);
    while(1) {
        sleep(5);
        
        refresh_task_ports_list();

        if (houdini_port == MACH_PORT_NULL) {  // user did not open Houdini yet
            
            printf("[INFO]: Houdini is not open yet..\n");
            continue;
            
            
        } else {
            
            if(houdini_port == old_houdini_port) { // we already gave this port the priv task
                printf("[INFO]: already gave it the port\n");
                continue;
                
            } else
            {
                
                printf("[INFO]: will give Houdini the port..\n");
                
                // get the address of the ps_control global variable in the debugserver:
                uint64_t remote_privileged_task_port = call_remote(houdini_port, dlsym, 2,
                                                                   REMOTE_LITERAL(RTLD_DEFAULT),
                                                                   REMOTE_CSTRING("passed_priv_port"));
                
                if (remote_privileged_task_port == 0) {
                    printf("failed to resolve the address of remote_privileged_task_port in the target\n");
                    continue;
                }
                
                // push that port to the debugserver:
                mach_port_t remote_privileged_task_port_name = push_local_port(houdini_port, launchd_port, MACH_MSG_TYPE_MOVE_SEND);
                if (remote_privileged_task_port_name == MACH_PORT_NULL) {
                    printf("failed to push privileged_task_port port to the target\n");
                    continue;
                }
                
                
                // write the name into the target's priviliged_task_port variable so it knows its name for the port:
                remote_write(houdini_port, remote_privileged_task_port, (uint64_t)&remote_privileged_task_port_name, sizeof(remote_privileged_task_port_name));
                printf("[INFO]: done giving port to process\n");
                
                old_houdini_port = houdini_port;

            }
            
        }
        

    }
    
  return 0;
}


