#include <stddef.h>
#include <stdarg.h>

extern size_t strnlen(const char *s, size_t count);
extern size_t strlen(const char *s);
extern int strcmp(const char* s1, const char* s2);
extern char* strcpy(char* dest, const char* src);

extern unsigned int barebones_clock();
extern void uart_send_char(char c);
extern int debug_printf(const char *fmt, ...);
