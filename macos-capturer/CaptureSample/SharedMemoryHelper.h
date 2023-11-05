//
//  SharedMemoryHelper.h
//  CaptureSample
//
//  Created by Yaindrop on 2023/10/29.
//  Copyright © 2023 Apple. All rights reserved.
//

#ifndef SharedMemoryHelper_h
#define SharedMemoryHelper_h

int shm_open_wrapper(const char *name, int oflag, mode_t mode);

#endif /* SharedMemoryHelper_h */
