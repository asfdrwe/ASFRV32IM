.globl _start

_start:
  li x1, 38233200
  li x2, 3200
  mul  x3, x1, x2
  mulh  x3, x1, x2
_loop:
  jal x0, _loop
