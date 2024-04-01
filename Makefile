hello_kernel:
	# Create the build directory.
	mkdir -p build build/hello_kernel

	# Compile the Kernel.
	# We need to compile with -ffreestanding because the standard library might not exist,
	# and startup may not necessarily be at 'main'. This is typical when compiling Kernels.
	gcc -ffreestanding -c src/hello_kernel/kernel.c -o build/hello_kernel/kernel.o
	# Link the Kernel.
	# We mark 0x1000 as the offset for all instructions, this will be the offset we'll use in the
	# bootloader when loading the Kernel in memory.
	ld -o build/hello_kernel/kernel.bin -Ttext 0x1000 build/hello_kernel/kernel.o --oformat binary

	# Assemble the bootloader.
	nasm src/hello_kernel/bootloader.asm -f bin -o build/hello_kernel/hello_kernel.img

	# Create the bootable image, put the bootloader first and the kernel second.
	rm build/hello_kernel/os.img || true
	dd if=build/hello_kernel/hello_kernel.img of=build/hello_kernel/os.img
	dd if=build/hello_kernel/kernel.bin of=build/hello_kernel/os.img oflag=append conv=notrunc bs=1G