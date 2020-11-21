OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;
  .text : { *(.text) }
  . = ALIGN(0x0100);
  .sbss : { *(.sbss) }
  .bss : { *(.bss) }
  .sdata : { *(.sdata) }
  .data : { *(.data) }
  _end = .;
}

