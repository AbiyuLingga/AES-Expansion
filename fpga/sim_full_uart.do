# Run from fpga folder; ModelSim-Altera VHDL-93 compatible.
catch {quit -sim}
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vcom -93 aes128_keyexp_pkg.vhd
vcom -93 aes128_keyexp.vhd
vcom -93 uart_tx_8n1.vhd
vcom -93 uart_rx_8n1.vhd
vcom -93 uart_key_parser.vhd
vcom -93 aes_uart_dump.vhd
vcom -93 aes_de1_fixed.vhd
vcom -93 tb_vectors_pkg.vhd
vcom -93 tb_full_uart.vhd
vsim -t 1ns work.tb_full_uart
view wave
add wave sim:/tb_full_uart/clk
add wave sim:/tb_full_uart/uart_rx
add wave sim:/tb_full_uart/uart_tx
add wave sim:/tb_full_uart/led0
add wave sim:/tb_full_uart/passed
add wave sim:/tb_full_uart/dut/phase
add wave -hex sim:/tb_full_uart/dut/active_key
add wave -hex sim:/tb_full_uart/dut/core_key
add wave -hex sim:/tb_full_uart/dut/core_round
run 6 ms
wave zoom full
