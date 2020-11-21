all: test1 test2 libeelib.a hello uart_inline uart_c str

test1: test1.S
	riscv64-unknown-elf-gcc -O0 -o test1 -fno-builtin -march=rv32g -mabi=ilp32 -nostdlib -nostartfiles -T link.ld test1.S
test2: test2.c
	riscv64-unknown-elf-gcc -O0 -o test2 -fno-builtin -march=rv32g -mabi=ilp32 -nostdlib -nostartfiles -T link.ld start.S test2.c

libeelib.a: ee_lib.c ee_lib.h
	riscv64-unknown-elf-gcc -c ee_lib.c -O2 -fno-builtin -march=rv32g -mabi=ilp32 -nostdlib -nostartfiles
	ar rcs libeelib.a ee_lib.o
hello: hello.c libeelib.a
	riscv64-unknown-elf-gcc -O2 -o hello -fno-builtin -march=rv32g -mabi=ilp32 -nostdlib -nostartfiles -T link.ld start.S hello.c libeelib.a
uart_inline: uart_inline.c libeelib.a
	riscv64-unknown-elf-gcc -O2 -o uart_inline -fno-builtin -march=rv32g -mabi=ilp32 -nostdlib -nostartfiles -T link.ld start.S uart_inline.c libeelib.a
uart_c: uart_c.c libeelib.a
	riscv64-unknown-elf-gcc -O2 -o uart_c -fno-builtin -march=rv32g -mabi=ilp32 -nostdlib -nostartfiles -T link.ld start.S uart_c.c libeelib.a
str: str.c libeelib.a
	riscv64-unknown-elf-gcc -O2 -o str -fno-builtin -march=rv32g -mabi=ilp32 -nostdlib -nostartfiles -T link.ld start.S str.c libeelib.a

clean:
	-rm -f test1 test2 libeelib.a hello uart_inline uart_c str ee_lib.o
