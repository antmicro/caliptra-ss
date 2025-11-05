# Connect QSPI signals
set_property    PACKAGE_PIN AW24        [get_ports spi_rtl_ss_io]
set_property    PACKAGE_PIN BD23        [get_ports spi_rtl_sck_io]
set_property    PACKAGE_PIN AV22        [get_ports spi_rtl_io0_io]
set_property    PACKAGE_PIN AU21        [get_ports spi_rtl_io1_io]
set_property    PACKAGE_PIN BC25        [get_ports spi_rtl_io2_io]
set_property    PACKAGE_PIN BC22        [get_ports spi_rtl_io3_io]

# Set IOSTANDARD
set_property IOSTANDARD LVCMOS15        [get_ports spi_rtl_ss_io]
set_property IOSTANDARD LVCMOS15        [get_ports spi_rtl_sck_io]
set_property IOSTANDARD LVCMOS15        [get_ports spi_rtl_io0_io]
set_property IOSTANDARD LVCMOS15        [get_ports spi_rtl_io1_io]
set_property IOSTANDARD LVCMOS15        [get_ports spi_rtl_io2_io]
set_property IOSTANDARD LVCMOS15        [get_ports spi_rtl_io3_io]
