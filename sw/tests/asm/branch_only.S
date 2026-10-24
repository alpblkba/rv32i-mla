# The taken path stores 2 at 0x104 and the fall through path stores 1, and the word loaded into x4 is stored at 0x108 so the test can check it on its own.
.section .text
.globl _start

_start:
    addi x1, x0, 5
    addi x2, x0, 7
    add  x3, x1, x2
    sw   x3, 0x100(x0)
    lw   x4, 0x100(x0)
    sw   x4, 0x108(x0)
    addi x5, x0, 1
    beq  x3, x4, pass
    sw   x5, 0x104(x0)
    jal  x0, done

pass:
    addi x5, x0, 2
    sw   x5, 0x104(x0)

done:
    ecall

loop:
    jal  x0, loop
