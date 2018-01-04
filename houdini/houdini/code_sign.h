//
//  code_sign.h
//  nsxpc2pc
//
//  Created by Abraham Masri on 11/21/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#ifndef code_sign_h
#define code_sign_h

#include <sys/types.h>

/* code signing attributes of a process */
#define	CS_VALID		0x0001	/* dynamically valid */
#define	CS_HARD			0x0100	/* don't load invalid pages */
#define	CS_KILL			0x0200	/* kill process if it becomes invalid */
#define CS_EXEC_SET_HARD	0x1000	/* set CS_HARD on any exec'ed process */
#define CS_EXEC_SET_KILL	0x2000	/* set CS_KILL on any exec'ed process */
#define CS_KILLED		0x10000	/* was killed by kernel for invalidity */
#define CS_RESTRICT		0x20000 /* tell dyld to treat restricted */

/* csops  operations */
#define	CS_OPS_STATUS		0	/* return status */
#define	CS_OPS_MARKINVALID	1	/* invalidate process */
#define	CS_OPS_MARKHARD		2	/* set HARD flag */
#define	CS_OPS_MARKKILL		3	/* set KILL flag (sticky) */
#define	CS_OPS_PIDPATH		4	/* get executable's pathname */
#define	CS_OPS_CDHASH		5	/* get code directory hash */
#define CS_OPS_PIDOFFSET	6	/* get offset of active Mach-o slice */
#define CS_OPS_ENTITLEMENTS_BLOB 7	/* get entitlements blob */
#define CS_OPS_MARKRESTRICT	8	/* set RESTRICT flag (sticky) */

/* code sign operations */
int csops(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize);


#endif /* code_sign_h */
