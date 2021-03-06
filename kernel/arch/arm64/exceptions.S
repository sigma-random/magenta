// Copyright 2016 The Fuchsia Authors
// Copyright (c) 2014 Travis Geiselbrecht
//
// Use of this source code is governed by a MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT

#include <asm.h>
#include <arch/asm_macros.h>
#include <arch/arm64.h>

.section .text.boot.vectab,"ax",@progbits
.align 12

#define lr x30
#define regsave_long_offset (30 * 8)
#define regsave_short_offset (20 * 8)

.macro regsave_long
sub  sp, sp, #32
push x28, x29
push x26, x27
push x24, x25
push x22, x23
push x20, x21
push x18, x19
push x16, x17
push x14, x15
push x12, x13
push x10, x11
push x8, x9
push x6, x7
push x4, x5
push x2, x3
push x0, x1
mrs  x0, sp_el0
mrs  x1, elr_el1
mrs  x2, spsr_el1
stp  lr, x0, [sp, #regsave_long_offset]
stp  x1, x2, [sp, #regsave_long_offset + 16]
.endm

.macro regsave_short
sub  sp, sp, #32
push x18, xzr
push x16, x17
push x14, x15
push x12, x13
push x10, x11
push x8, x9
push x6, x7
push x4, x5
push x2, x3
push x0, x1
mrs  x0, sp_el0
mrs  x1, elr_el1
mrs  x2, spsr_el1
stp  lr, x0, [sp, #regsave_short_offset]
stp  x1, x2, [sp, #regsave_short_offset + 16]
.endm

.macro regrestore_long
ldp  lr, x0, [sp, #regsave_long_offset]
ldp  x1, x2, [sp, #regsave_long_offset + 16]
msr  sp_el0, x0
msr  elr_el1, x1
msr  spsr_el1, x2
pop x0, x1
pop x2, x3
pop x4, x5
pop x6, x7
pop x8, x9
pop x10, x11
pop x12, x13
pop x14, x15
pop x16, x17
pop x18, x19
pop x20, x21
pop x22, x23
pop x24, x25
pop x26, x27
pop x28, x29
add sp, sp, #32
.endm

.macro regrestore_short
ldp  lr, x0, [sp, #regsave_short_offset]
ldp  x1, x2, [sp, #regsave_short_offset + 16]
msr  sp_el0, x0
msr  elr_el1, x1
msr  spsr_el1, x2
pop x0, x1
pop x2, x3
pop x4, x5
pop x6, x7
pop x8, x9
pop x10, x11
pop x12, x13
pop x14, x15
pop x16, x17
pop x18, xzr
add sp, sp, #32
.endm

.macro invalid_exception, which
    regsave_long
    mov x1, #\which
    mov x0, sp
    bl  arm64_invalid_exception
    b   .
.endm

.macro irq_exception, exception_flags
    regsave_short
    msr daifclr, #1 /* reenable fiqs once elr and spsr have been saved */
    mov x0, sp
    mov x1, \exception_flags
    bl  arm64_irq
    msr daifset, #1 /* disable fiqs to protect elr and spsr restore */
    b   arm64_exc_shared_restore_short
.endm

.macro sync_exception, exception_flags
    regsave_long
    mov x0, sp
    mov x1, \exception_flags
    bl  arm64_sync_exception
    b  arm64_exc_shared_restore_long
.endm

FUNCTION(arm64_exception_base)

/* exceptions from current EL, using SP0 */
LOCAL_FUNCTION(arm64_sync_exc_current_el_SP0)
    invalid_exception 0
END(arm64_sync_exc_current_el_SP0)

.org 0x080
LOCAL_FUNCTION(arm64_irq_current_el_SP0)
    invalid_exception 1
END(arm64_irq_current_el_SP0)

.org 0x100
LOCAL_FUNCTION(arm64_fiq_current_el_SP0)
    invalid_exception 2
END(arm64_fiq_current_el_SP0)

.org 0x180
LOCAL_FUNCTION(arm64_err_exc_current_el_SP0)
    invalid_exception 3
END(arm64_err_exc_current_el_SP0)

/* exceptions from current EL, using SPx */
.org 0x200
LOCAL_FUNCTION(arm64_sync_exc_current_el_SPx)
    sync_exception #0 /* same EL, arm64 */
END(arm64_sync_exc_current_el_SPx)

.org 0x280
LOCAL_FUNCTION(arm64_irq_current_el_SPx)
    irq_exception #0 /* same EL, arm64 */
END(arm64_irq_current_el_SPx)

.org 0x300
LOCAL_FUNCTION(arm64_fiq_current_el_SPx)
    regsave_short
    mov x0, sp
    bl  platform_fiq
    b  arm64_exc_shared_restore_short
END(arm64_fiq_current_el_SPx)

.org 0x380
LOCAL_FUNCTION(arm64_err_exc_current_el_SPx)
    invalid_exception 0x13
END(arm64_err_exc_current_el_SPx)

/* exceptions from lower EL, running arm64 */
.org 0x400
LOCAL_FUNCTION(arm64_sync_exc_lower_el_64)
    sync_exception #(ARM64_EXCEPTION_FLAG_LOWER_EL)
END(arm64_sync_exc_lower_el_64)

.org 0x480
LOCAL_FUNCTION(arm64_irq_lower_el_64)
    irq_exception #(ARM64_EXCEPTION_FLAG_LOWER_EL)
END(arm64_irq_lower_el_64)

.org 0x500
LOCAL_FUNCTION(arm64_fiq_lower_el_64)
    regsave_short
    mov x0, sp
    bl  platform_fiq
    b  arm64_exc_shared_restore_short
END(arm64_fiq_lower_el_64)

.org 0x580
LOCAL_FUNCTION(arm64_err_exc_lower_el_64)
    invalid_exception 0x23
END(arm64_err_exc_lower_el_64)

/* exceptions from lower EL, running arm32 */
.org 0x600
LOCAL_FUNCTION(arm64_sync_exc_lower_el_32)
    sync_exception #(ARM64_EXCEPTION_FLAG_LOWER_EL|ARM64_EXCEPTION_FLAG_ARM32)
END(arm64_sync_exc_lower_el_32)

.org 0x680
LOCAL_FUNCTION(arm64_irq_lower_el_32)
    irq_exception #(ARM64_EXCEPTION_FLAG_LOWER_EL|ARM64_EXCEPTION_FLAG_ARM32)
END(arm64_irq_lower_el_32)

.org 0x700
LOCAL_FUNCTION(arm64_fiq_lower_el_32)
    regsave_short
    mov x0, sp
    bl  platform_fiq
    b  arm64_exc_shared_restore_short
END(arm64_fiq_lower_el_32)

.org 0x780
LOCAL_FUNCTION(arm64_err_exc_lower_el_32)
    invalid_exception 0x33
END(arm64_err_exc_lower_el_32)

LOCAL_FUNCTION(arm64_exc_shared_restore_long)
    regrestore_long
    eret
END(arm64_exc_shared_restore_long)

LOCAL_FUNCTION(arm64_exc_shared_restore_short)
    regrestore_short
    eret
END(arm64_exc_shared_restore_short)
