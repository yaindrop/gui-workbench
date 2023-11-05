from posix_ipc import ExistentialError, Semaphore, SharedMemory
import mmap
import cv2
import numpy as np
import asyncio
import datetime


class SharedMemoryInterface:
    def __init__(self, shm_name, sem_name, shm_size):
        self.shm_name = shm_name
        self.sem_name = sem_name
        self.shm_size = shm_size
        self.semaphore = None
        self.shared_memory = None
        self.mapfile = None
        self.initialize_resources()

    def initialize_resources(self):
        try:
            self.shared_memory = SharedMemory(self.shm_name)
            self.semaphore = Semaphore(self.sem_name)
            self.mapfile = mmap.mmap(self.shared_memory.fd, self.shm_size)
        except ExistentialError as e:
            print(f"Error initializing resources: {e}")
            raise

    async def read_data(self, size, loop):
        if not self.semaphore or not self.mapfile:
            return
        data = None
        try:
            await loop.run_in_executor(None, self.semaphore.acquire)
            print("acquire", datetime.datetime.now())
            self.mapfile.seek(0)
            data = self.mapfile.read(size)
        finally:
            loop.call_soon_threadsafe(self.semaphore.release)
        print("return data", datetime.datetime.now())
        return data

    def close_resources(self):
        if self.mapfile:
            self.mapfile.close()
        if self.shared_memory:
            self.shared_memory.close_fd()
        if self.semaphore:
            self.semaphore.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close_resources()


SHM_NAME = "/shm_screen_capture"
SEM_NAME = "/sem_screen_capture"
SHM_SIZE = 1 << 26
WIDTH = 5120
HEIGHT = 2880


async def poll_shm(shm_interface, width, height, loop):
    frame_size = width * height * 4  # BGRA
    while True:
        raw_data = await shm_interface.read_data(frame_size, loop)
        if raw_data is None:
            break
        np_data = np.frombuffer(raw_data, dtype=np.uint8)
        image = np_data.reshape((height, width, 4))
        cv2.imshow('rgba', image)
        if cv2.waitKey(1) & 0xff == ord('q'):
            break
        await asyncio.sleep(0)  # Yield control back to the event loop


async def display_image_from_shared_memory(shm_name, sem_name, shm_size, width, height):
    loop = asyncio.get_running_loop()
    with SharedMemoryInterface(shm_name, sem_name, shm_size) as shm_interface:
        await poll_shm(shm_interface, width, height, loop)
    cv2.destroyAllWindows()


if __name__ == "__main__":
    asyncio.run(display_image_from_shared_memory(
        SHM_NAME, SEM_NAME, SHM_SIZE, WIDTH, HEIGHT))
