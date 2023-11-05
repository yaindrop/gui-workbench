//
//  SharedMemory.swift
//  CaptureSample
//
//  Created by Yaindrop on 2023/11/5.
//  Copyright © 2023 Apple. All rights reserved.
//

import Darwin
import Foundation
import OSLog

class SharedMemory {
    
    // Define constants for shared memory and semaphore
    private let SHM_NAME = "/shm_screen_capture"
    private let SEM_NAME = "/sem_screen_capture"
    private let SHM_SIZE = 1 << 26 // Size of shared memory in bytes
    
    private var shmFd: Int32 = -1
    private var shmPtr: UnsafeMutableRawPointer? = nil
    private var sem: UnsafeMutablePointer<sem_t>?
    
    init() {
        closeSharedMemory();
        setupSharedMemory()
    }
    
    deinit {
        closeSharedMemory()
    }
    
    private func setupSharedMemory() {
        // Create shared memory
        shmFd = shm_open_wrapper(SHM_NAME, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        if shmFd == -1 {
            print("Failed to create shared memory. Reason: \(String(cString: strerror(errno)))")
            return
        }
        
        // Create semaphore
        sem = sem_open(SEM_NAME, O_CREAT, S_IRUSR | S_IWUSR, 1)
        if sem == SEM_FAILED {
            print("Failed to create semaphore. Reason: \(String(cString: strerror(errno)))")
            return
        }
        
        if ftruncate(shmFd, off_t(SHM_SIZE)) == -1 {
            print("Failed to set shared memory size. Reason: \(String(cString: strerror(errno)))")
            return
        }
        
        // Map shared memory
        shmPtr = mmap(nil, SHM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, shmFd, 0)
        if shmPtr == MAP_FAILED {
            print("Failed to map shared memory. Reason: \(String(cString: strerror(errno)))")
            return
        }
    }
    
    private func closeSharedMemory() {
        // Unmap shared memory
        if let ptr = shmPtr {
            if munmap(ptr, SHM_SIZE) == -1 {
                print("Failed to unmap shared memory. Reason: \(String(cString: strerror(errno)))")
            }
        }
        
        if shmFd == -1 {
            shmFd = shm_open_wrapper(SHM_NAME, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        }
        // Close shared memory descriptor
        if shmFd != -1 {
            close(shmFd)
            if shm_unlink(SHM_NAME) == -1 {
                print("Failed to unlink shared memory. Reason: \(String(cString: strerror(errno)))")
            }
        }
        
        if sem == nil {
            sem = sem_open(SEM_NAME, O_CREAT, S_IRUSR | S_IWUSR, 1)
        }
        // Close semaphore
        if let s = sem {
            if sem_close(s) == -1 {
                print("Failed to close semaphore. Reason: \(String(cString: strerror(errno)))")
            }
            if sem_unlink(SEM_NAME) == -1 {
                print("Failed to unlink semaphore. Reason: \(String(cString: strerror(errno)))")
            }
        }
    }
    
    public func sendData(_ data: Data) {
        guard let ptr = shmPtr, data.count <= SHM_SIZE else {
            print("Invalid shared memory or data size exceeds shared memory size \(data.count)")
            return
        }
        
        // Lock semaphore
        if sem_wait(sem) == -1 {
            print("Failed to lock semaphore. Reason: \(String(cString: strerror(errno)))")
            return
        }
        
        // Copy data to shared memory
        data.copyBytes(to: ptr.assumingMemoryBound(to: UInt8.self), count: data.count)
        
        // Unlock semaphore
        if sem_post(sem) == -1 {
            print("Failed to unlock semaphore. Reason: \(String(cString: strerror(errno)))")
        }
    }
}
