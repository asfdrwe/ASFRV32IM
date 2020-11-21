void _main()
{
  int *i = (int*)0xfff0;
  unsigned char c;

  c = 'a';
  asm volatile ("sb %0, (%1)" : : "r"(c), "r"(i) );
  c = 'b';
  asm volatile ("sb %0, (%1)" : : "r"(c), "r"(i) );
  c = 'c';
  asm volatile ("sb %0, (%1)" : : "r"(c), "r"(i) );
  c = '\n';
  asm volatile ("sb %0, (%1)" : : "r"(c), "r"(i) );

  return;
}
