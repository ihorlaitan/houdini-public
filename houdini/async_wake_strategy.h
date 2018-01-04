//
//  async_wake_strategy.h
//  houdini
//
//  Created by Abraham Masri on 12/7/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#ifndef async_wake_strategy_h
#define async_wake_strategy_h

#include "strategy_control.h"

extern uint64_t kernel_base;
extern uint64_t kernel_task;
extern uint64_t kaslr_slide;


size_t kread(uint64_t where, void *p, size_t size);
uint64_t kread_uint64(uint64_t where);
uint32_t kread_uint32(uint64_t where);
size_t kwrite(uint64_t where, const void *p, size_t size);
size_t kwrite_uint64(uint64_t where, uint64_t value);
size_t kwrite_uint32(uint64_t where, uint32_t value);

uint64_t get_proc_with_pid(pid_t target_pid, int spawned);
kern_return_t async_wake_post_exploit ();
strategy async_wake_strategy();

#endif /* async_wake_strategy_h */
