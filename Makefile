ASM=nasm
QEMU=qemu-system-i386

# Directory Definitions
SRC_DIR=src
BUILD_DIR=build
OUT_DIR=out

all: $(OUT_DIR)/flowop.img

# Compile Bootloader to build/
$(BUILD_DIR)/boot.bin: $(SRC_DIR)/boot.asm
	@mkdir -p $(BUILD_DIR)
	$(ASM) -f bin $(SRC_DIR)/boot.asm -o $(BUILD_DIR)/boot.bin

# Compile Kernel to build/ (includes syscalls via -I flag)
$(BUILD_DIR)/kernel.bin: $(SRC_DIR)/kernel.asm $(SRC_DIR)/syscalls.asm
	@mkdir -p $(BUILD_DIR)
	$(ASM) -f bin -I$(SRC_DIR)/ $(SRC_DIR)/kernel.asm -o $(BUILD_DIR)/kernel.bin

# Compile Command to build/
$(BUILD_DIR)/command.bin: $(SRC_DIR)/command.asm
	@mkdir -p $(BUILD_DIR)
	$(ASM) -f bin $(SRC_DIR)/command.asm -o $(BUILD_DIR)/command.bin

# Build the final floppy image into out/ using dd
$(OUT_DIR)/flowop.img: $(BUILD_DIR)/boot.bin $(BUILD_DIR)/kernel.bin $(BUILD_DIR)/command.bin
	@mkdir -p $(OUT_DIR)
	# 1. Create a blank 1.44MB floppy image filled with zeros
	dd if=/dev/zero of=$(OUT_DIR)/flowop.img bs=512 count=2880 status=none
	# 2. Write bootloader to Sector 1 (seek=0)
	dd if=$(BUILD_DIR)/boot.bin of=$(OUT_DIR)/flowop.img bs=512 count=1 conv=notrunc status=none
	# 3. Write Kernel to Sector 2 (seek=1)
	dd if=$(BUILD_DIR)/kernel.bin of=$(OUT_DIR)/flowop.img bs=512 seek=1 conv=notrunc status=none
	# 4. Write User Command to Sector 4 (seek=3)
	dd if=$(BUILD_DIR)/command.bin of=$(OUT_DIR)/flowop.img bs=512 seek=3 conv=notrunc status=none

run: $(OUT_DIR)/flowop.img
	$(QEMU) -fda $(OUT_DIR)/flowop.img

clean:
	rm -rf $(BUILD_DIR) $(OUT_DIR)