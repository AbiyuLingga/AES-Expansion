catch {quit -sim}
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vcom -93 aes128_keyexp_pkg.vhd
vcom -93 aes128_keyexp.vhd
vcom -93 tb_vectors_pkg.vhd
vcom -93 tb_aes128_keyexp.vhd
vsim -t 1ns work.tb_aes128_keyexp
view wave
add wave -hex sim:/tb_aes128_keyexp/key_in
add wave -hex sim:/tb_aes128_keyexp/round_key
add wave -hex sim:/tb_aes128_keyexp/round_index
add wave sim:/tb_aes128_keyexp/clk
add wave sim:/tb_aes128_keyexp/valid
add wave sim:/tb_aes128_keyexp/done
run -all
wave zoom full
