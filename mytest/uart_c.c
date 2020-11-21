#include "ee_lib.h"

void _main()
{
  uart_send_char('A');
  uart_send_char('\n');
  debug_printf("test\n");
  debug_printf("%d\n", barebones_clock());
  debug_printf("test2\n");
  debug_printf("%d\n", barebones_clock());

  return;
}
