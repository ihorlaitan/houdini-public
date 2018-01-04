//
//  strategy_control.h
//  houdini
//
//  Created by Abraham Masri on 12/7/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//


#ifndef strategy_control_h
#define strategy_control_h

typedef struct strategy_s {
    
    // called to start the exploit
    kern_return_t (*strategy_start) ();

    // called after strategy_start (for any post-exploitation stuff)
    kern_return_t (*strategy_post_exploit) ();
    
    void (*strategy_mkdir) (char *path);
    void (*strategy_rename) (const char *old, const char *new);
    void (*strategy_unlink) (char *path);
    
    int (*strategy_chown) (const char *path, uid_t owner, gid_t group);
    int (*strategy_chmod) (const char *path, mode_t mode);
    
    int (*strategy_open) (const char *path, int oflags, mode_t mode);
    
    void (*strategy_kill) (pid_t pid, int sig);
    
    void (*strategy_reboot) ();
    
    void (*strategy_posix_spawn) (char *path);
    pid_t (*strategy_pid_for_name) (char *name);
    
    
} strategy;


kern_return_t set_exploit_strategy();

#endif /* strategy_control_h */
