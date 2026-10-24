/* Linker script for the vendored rv32ui tests: code and data from 0x0, tohost alone in the last word of the 8 KiB BRAM. */
OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x0;
  .text : { *(.text.init) *(.text*) }
  .data : { *(.data*) *(.sdata*) *(.rodata*) *(.srodata*) *(.bss*) *(.sbss*) }
  ASSERT(. <= 0x1ffc, "test image reaches tohost at 0x1ffc")
  . = 0x1ffc;
  .tohost : { *(.tohost) }
  ASSERT(tohost == 0x1ffc, "tohost is not at 0x1ffc")
}
