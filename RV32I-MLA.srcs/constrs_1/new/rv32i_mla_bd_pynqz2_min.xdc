# ============================================================
# RV32I-MLA (PYNQ-Z2) minimal constraints
# keeping ONLY what exists as top-level ports in rv32i_mla_bd_wrapper.
#
# Current plan:
#   - 4 user LEDs for demo/debug
# ============================================================

# ----------------------------
# LEDs (PYNQ-Z2)
# ----------------------------
# port name assumed: led_0[3:0]
# PYNQ-Z2 user LEDs:
#   LED0: R14
#   LED1: P14
#   LED2: N16
#   LED3: M14

set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports {led_0[0]}]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports {led_0[1]}]
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports {led_0[2]}]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports {led_0[3]}]

set_property DRIVE 8   [get_ports {led_0[*]}]
set_property SLEW SLOW [get_ports {led_0[*]}]

# ============================================================
# clck constraints
# using PS FCLK_CLK0; no external create_clock needed here.
