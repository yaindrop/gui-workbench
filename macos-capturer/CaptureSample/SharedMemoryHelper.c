//
//  SharedMemoryHelper.c
//  CaptureSample
//
//  Created by Yaindrop on 2023/10/29.
//  Copyright © 2023 Apple. All rights reserved.
//

#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>

int shm_open_wrapper(const char *name, int oflag, mode_t mode) {
    return shm_open(name, oflag, mode);
}
