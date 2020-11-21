#include "ee_lib.h"

void _main()
{
  char str1[] = "hello";
  char str2[] = "world!";
  char str3[256];

  debug_printf("%d: %s \n", strlen(str1), str1);
  debug_printf("%d: %s \n", strlen(str2), str2);
  strcpy(str3, str1);
  debug_printf("%d: %s \n", strlen(str3), str3);
  debug_printf("%d: %s \n", strnlen(str3, 2), str3);
  debug_printf("%d\n", strcmp(str1, str3));
  debug_printf("%d\n", strcmp(str2, str3));

  return;
}
