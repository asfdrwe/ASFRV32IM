/*
Copyright 2018 Embedded Microprocessor Benchmark Consortium (EEMBC)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
/*BSD 3-Clause License
 *
 * Copyright (c) 2017, Christopher Celio
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * * Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 *
 *   * Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *       and/or other materials provided with the distribution.
 *
 *       * Neither the name of the copyright holder nor the names of its
 *         contributors may be used to endorse or promote products derived from
 *           this software without specific prior written permission.
 *
 *           THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *           AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *           IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 *           DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 *           FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 *           DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 *           SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 *           CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 *           OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 *           OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/*
 * Copyright (c) 2020 asfdrwe (asfdrwe@gmail.com)
 *
 * This code is based on 
 * https://github.com/eembc/coremark/blob/master/barebones/ee_printf.c
 * https://github.com/eembc/coremark/blob/master/barebones/core_portme.c
 * https://github.com/riscv-boom/riscv-coremark/blob/master/riscv64-baremetal/syscalls.c
 *
 */
#include <stddef.h>
#include <stdarg.h>
#include <inttypes.h>

#include "ee_lib.h"

#define ZEROPAD   (1 << 0) /* Pad with zero */
#define SIGN      (1 << 1) /* Unsigned/signed long */
#define PLUS      (1 << 2) /* Show plus */
#define SPACE     (1 << 3) /* Spacer */
#define LEFT      (1 << 4) /* Left justified */
#define HEX_PREP  (1 << 5) /* 0x */
#define UPPERCASE (1 << 6) /* 'ABCDEF' */

#define is_digit(c) ((c) >= '0' && (c) <= '9')

static char *    digits       = "0123456789abcdefghijklmnopqrstuvwxyz";
static char *    upper_digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

size_t strnlen(const char *s, size_t count)
{
    const char *sc;
    for (sc = s; *sc != '\0' && count--; ++sc)
        ;
    return sc - s;
}

static int
skip_atoi(const char **s)
{
    int i = 0;
    while (is_digit(**s))
        i = i * 10 + *((*s)++) - '0';
    return i;
}

static char *
number(char *str, long num, int base, int size, int precision, int type)
{
    char  c, sign, tmp[66];
    char *dig = digits;
    int   i;

    if (type & UPPERCASE)
        dig = upper_digits;
    if (type & LEFT)
        type &= ~ZEROPAD;
    if (base < 2 || base > 36)
        return 0;

    c    = (type & ZEROPAD) ? '0' : ' ';
    sign = 0;
    if (type & SIGN)
    {
        if (num < 0)
        {
            sign = '-';
            num  = -num;
            size--;
        }
        else if (type & PLUS)
        {
            sign = '+';
            size--;
        }
        else if (type & SPACE)
        {
            sign = ' ';
            size--;
        }
    }

    if (type & HEX_PREP)
    {
        if (base == 16)
            size -= 2;
        else if (base == 8)
            size--;
    }

    i = 0;

    if (num == 0)
        tmp[i++] = '0';
    else
    {
        while (num != 0)
        {
            tmp[i++] = dig[((unsigned long)num) % (unsigned)base];
            num      = ((unsigned long)num) / (unsigned)base;
        }
    }

    if (i > precision)
        precision = i;
    size -= precision;
    if (!(type & (ZEROPAD | LEFT)))
        while (size-- > 0)
            *str++ = ' ';
    if (sign)
        *str++ = sign;

    if (type & HEX_PREP)
    {
        if (base == 8)
            *str++ = '0';
        else if (base == 16)
        {
            *str++ = '0';
            *str++ = digits[33];
        }
    }

    if (!(type & LEFT))
        while (size-- > 0)
            *str++ = c;
    while (i < precision--)
        *str++ = '0';
    while (i-- > 0)
        *str++ = tmp[i];
    while (size-- > 0)
        *str++ = ' ';

    return str;
}

static char *
eaddr(char *str, unsigned char *addr, int size, int precision, int type)
{
    char  tmp[24];
    char *dig = digits;
    int   i, len;

    if (type & UPPERCASE)
        dig = upper_digits;
    len = 0;
    for (i = 0; i < 6; i++)
    {
        if (i != 0)
            tmp[len++] = ':';
        tmp[len++] = dig[addr[i] >> 4];
        tmp[len++] = dig[addr[i] & 0x0F];
    }

    if (!(type & LEFT))
        while (len < size--)
            *str++ = ' ';
    for (i = 0; i < len; ++i)
        *str++ = tmp[i];
    while (len < size--)
        *str++ = ' ';

    return str;
}

static char *
iaddr(char *str, unsigned char *addr, int size, int precision, int type)
{
    char tmp[24];
    int  i, n, len;

    len = 0;
    for (i = 0; i < 4; i++)
    {
        if (i != 0)
            tmp[len++] = '.';
        n = addr[i];

        if (n == 0)
            tmp[len++] = digits[0];
        else
        {
            if (n >= 100)
            {
                tmp[len++] = digits[n / 100];
                n          = n % 100;
                tmp[len++] = digits[n / 10];
                n          = n % 10;
            }
            else if (n >= 10)
            {
                tmp[len++] = digits[n / 10];
                n          = n % 10;
            }

            tmp[len++] = digits[n];
        }
    }

    if (!(type & LEFT))
        while (len < size--)
            *str++ = ' ';
    for (i = 0; i < len; ++i)
        *str++ = tmp[i];
    while (len < size--)
        *str++ = ' ';

    return str;
}

static int
ee_vsprintf(char *buf, const char *fmt, va_list args)
{
    int           len;
    unsigned long num;
    int           i, base;
    char *        str;
    char *        s;

    int flags; // Flags to number()

    int field_width; // Width of output field
    int precision;   // Min. # of digits for integers; max number of chars for
                     // from string
    int qualifier;   // 'h', 'l', or 'L' for integer fields

    for (str = buf; *fmt; fmt++)
    {
        if (*fmt != '%')
        {
            *str++ = *fmt;
            continue;
        }

        // Process flags
        flags = 0;
    repeat:
        fmt++; // This also skips first '%'
        switch (*fmt)
        {
            case '-':
                flags |= LEFT;
                goto repeat;
            case '+':
                flags |= PLUS;
                goto repeat;
            case ' ':
                flags |= SPACE;
                goto repeat;
            case '#':
                flags |= HEX_PREP;
                goto repeat;
            case '0':
                flags |= ZEROPAD;
                goto repeat;
        }

        // Get field width
        field_width = -1;
        if (is_digit(*fmt))
            field_width = skip_atoi(&fmt);
        else if (*fmt == '*')
        {
            fmt++;
            field_width = va_arg(args, int);
            if (field_width < 0)
            {
                field_width = -field_width;
                flags |= LEFT;
            }
        }

        // Get the precision
        precision = -1;
        if (*fmt == '.')
        {
            ++fmt;
            if (is_digit(*fmt))
                precision = skip_atoi(&fmt);
            else if (*fmt == '*')
            {
                ++fmt;
                precision = va_arg(args, int);
            }
            if (precision < 0)
                precision = 0;
        }

        // Get the conversion qualifier
        qualifier = -1;
        if (*fmt == 'l' || *fmt == 'L')
        {
            qualifier = *fmt;
            fmt++;
        }

        // Default base
        base = 10;

        switch (*fmt)
        {
            case 'c':
                if (!(flags & LEFT))
                    while (--field_width > 0)
                        *str++ = ' ';
                *str++ = (unsigned char)va_arg(args, int);
                while (--field_width > 0)
                    *str++ = ' ';
                continue;

            case 's':
                s = va_arg(args, char *);
                if (!s)
                    s = "<NULL>";
                len = strnlen(s, precision);
                if (!(flags & LEFT))
                    while (len < field_width--)
                        *str++ = ' ';
                for (i = 0; i < len; ++i)
                    *str++ = *s++;
                while (len < field_width--)
                    *str++ = ' ';
                continue;

            case 'p':
                if (field_width == -1)
                {
                    field_width = 2 * sizeof(void *);
                    flags |= ZEROPAD;
                }
                str = number(str,
                             (unsigned long)va_arg(args, void *),
                             16,
                             field_width,
                             precision,
                             flags);
                continue;

            case 'A':
                flags |= UPPERCASE;

            case 'a':
                if (qualifier == 'l')
                    str = eaddr(str,
                                va_arg(args, unsigned char *),
                                field_width,
                                precision,
                                flags);
                else
                    str = iaddr(str,
                                va_arg(args, unsigned char *),
                                field_width,
                                precision,
                                flags);
                continue;

            // Integer number formats - set up the flags and "break"
            case 'o':
                base = 8;
                break;

            case 'X':
                flags |= UPPERCASE;

            case 'x':
                base = 16;
                break;

            case 'd':
            case 'i':
                flags |= SIGN;

            case 'u':
                break;

            default:
                if (*fmt != '%')
                    *str++ = '%';
                if (*fmt)
                    *str++ = *fmt;
                else
                    --fmt;
                continue;
        }

        if (qualifier == 'l')
            num = va_arg(args, unsigned long);
        else if (flags & SIGN)
            num = va_arg(args, int);
        else
            num = va_arg(args, unsigned int);

        str = number(str, num, base, field_width, precision, flags);
    }

    *str = '\0';
    return str - buf;
}

size_t strlen(const char *s)
{
  const char *p = s;
  while (*p)
    p++;
  return p - s;
}

int strcmp(const char* s1, const char* s2)
{
  unsigned char c1, c2;

  do {
    c1 = *s1++;
    c2 = *s2++;
  } while (c1 != 0 && c1 == c2);

  return c1 - c2;
}

char* strcpy(char* dest, const char* src)
{
  char* d = dest;
  while ((*d++ = *src++))
    ;
  return dest;
}

unsigned int barebones_clock()
{
  int *i = (int*)0xfff4; // COUNTER ADDRESS
  unsigned int r;
  asm volatile ("lw %0, (%1)" : "=r"(r) : "r"(i) );
  return r;
}

void
uart_send_char(char c)
{
  char *c1 = (char*)0xfff0; // UART DATA ADDRESS
  char *c2 = (char*)0xfff1; // UART FLAG ADDRESS

  while (*c2 != 1) {} // loop unless UART FLAG = 1
  *c1 = c;
}

int
debug_printf(const char *fmt, ...)
{
    char    buf[256], *p;
    va_list args;
    int     n = 0;

    va_start(args, fmt);
    ee_vsprintf(buf, fmt, args);
    va_end(args);
    p = buf;
    while (*p)
    {
        uart_send_char(*p);
        n++;
        p++;
    }

    return n;
}
