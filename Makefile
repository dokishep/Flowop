ASM=nasm
QEMU=qemu-system-i386

SRC_DIR=src
BUILD_DIR=build
OUT_DIR=out
APPS_DIR=userApps
FAT12_DIR=fat12

all: $(OUT_DIR)/flowop.img

$(BUILD_DIR)/boot.bin: $(SRC_DIR)/boot.asm
	@mkdir -p $(BUILD_DIR)
	$(ASM) -f bin $(SRC_DIR)/boot.asm -o $(BUILD_DIR)/boot.bin

$(BUILD_DIR)/kernel.bin: $(SRC_DIR)/kernel.asm $(SRC_DIR)/syscalls.asm
	@mkdir -p $(BUILD_DIR)
	$(ASM) -f bin -I$(SRC_DIR)/ $(SRC_DIR)/kernel.asm -o $(BUILD_DIR)/kernel.bin

# Track cmd_logic.asm as an intermediate compile safety dependency
$(BUILD_DIR)/command.bin: $(SRC_DIR)/command.asm $(SRC_DIR)/basic_map.asm $(SRC_DIR)/cmd_logic.asm
	@mkdir -p $(BUILD_DIR)
	$(ASM) -f bin -I$(SRC_DIR)/ $(SRC_DIR)/command.asm -o $(BUILD_DIR)/command.bin

$(OUT_DIR)/flowop.img: $(BUILD_DIR)/boot.bin $(BUILD_DIR)/kernel.bin $(BUILD_DIR)/command.bin
	@mkdir -p $(OUT_DIR)
	@mkdir -p fat12
	dd if=/dev/zero of=$(OUT_DIR)/flowop.img bs=512 count=2880 status=none
	mkfs.fat -F 12 -R 9 $(OUT_DIR)/flowop.img
	dd if=$(BUILD_DIR)/boot.bin of=$(OUT_DIR)/flowop.img bs=512 count=1 conv=notrunc status=none
	dd if=$(BUILD_DIR)/kernel.bin of=$(OUT_DIR)/flowop.img bs=512 seek=1 conv=notrunc status=none
	dd if=$(BUILD_DIR)/command.bin of=$(OUT_DIR)/flowop.img bs=512 seek=5 conv=notrunc status=none

run: $(OUT_DIR)/flowop.img
	$(QEMU) -fda $(OUT_DIR)/flowop.img

app:
	@mkdir -p $(APPS_DIR)
	@mkdir -p $(FAT12_DIR)
	$(ASM) -f bin $(APPS_DIR)/guess.asm -o $(FAT12_DIR)/guess.bin

clean:
	rm -rf $(BUILD_DIR) $(OUT_DIR) $(FAT12_DIR)/*.bin