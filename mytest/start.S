.globl _start

_start:
  li sp, 0xff00
  jal _main
_loop:
  jal _loop
