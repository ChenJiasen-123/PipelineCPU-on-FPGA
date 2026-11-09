# 时钟约束
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

# 复位约束
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { rst }];

# UART 约束
set_property -dict { PACKAGE_PIN N5  IOSTANDARD LVCMOS33 } [get_ports { uart_rxd }];
set_property -dict { PACKAGE_PIN T4  IOSTANDARD LVCMOS33 } [get_ports { uart_txd }];

# 模式选择开关 (0=单周期CPU, 1=流水线CPU)
# 使用开发板上的拨码开关，请根据实际开发板修改引脚
set_property -dict { PACKAGE_PIN P5  IOSTANDARD LVCMOS33 } [get_ports { pipeline_mode }];

# 位选信号 (8个位，引脚不变)
set_property PACKAGE_PIN G2 [get_ports {p7_0[7]}]
set_property PACKAGE_PIN C2 [get_ports {p7_0[6]}]
set_property PACKAGE_PIN C1 [get_ports {p7_0[5]}]
set_property PACKAGE_PIN H1 [get_ports {p7_0[4]}]
set_property PACKAGE_PIN G1 [get_ports {p7_0[3]}]
set_property PACKAGE_PIN F1 [get_ports {p7_0[2]}]
set_property PACKAGE_PIN E1 [get_ports {p7_0[1]}]
set_property PACKAGE_PIN G6 [get_ports {p7_0[0]}]

# 段选信号组 1 (对应左边 4 位 DN0_K1-K4)
set_property PACKAGE_PIN B4 [get_ports {p7_1[7]}]
set_property PACKAGE_PIN A4 [get_ports {p7_1[6]}]
set_property PACKAGE_PIN A3 [get_ports {p7_1[5]}]
set_property PACKAGE_PIN B1 [get_ports {p7_1[4]}]
set_property PACKAGE_PIN A1 [get_ports {p7_1[3]}]
set_property PACKAGE_PIN B3 [get_ports {p7_1[2]}]
set_property PACKAGE_PIN B2 [get_ports {p7_1[1]}]
set_property PACKAGE_PIN D5 [get_ports {p7_1[0]}]

# 段选信号组 2 (对应右边 4 位 DN1_K1-K4) 
set_property PACKAGE_PIN D4 [get_ports {p7_2[7]}]
set_property PACKAGE_PIN E3 [get_ports {p7_2[6]}]
set_property PACKAGE_PIN D3 [get_ports {p7_2[5]}]
set_property PACKAGE_PIN F4 [get_ports {p7_2[4]}]
set_property PACKAGE_PIN F3 [get_ports {p7_2[3]}]
set_property PACKAGE_PIN E2 [get_ports {p7_2[2]}]
set_property PACKAGE_PIN D2 [get_ports {p7_2[1]}]
set_property PACKAGE_PIN H2 [get_ports {p7_2[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {p7_0[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {p7_1[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {p7_2[*]}]

# cpu_clk_raw 这个寄存器的输出是一个时钟信号
create_generated_clock -name cpu_clk [get_pins u_bufg_cpu_clk/I] -source [get_ports clk] -divide_by 10
