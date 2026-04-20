//********************************************************************************
// SPDX-License-Identifier: Apache-2.0
//
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//********************************************************************************
//
// Test: mci_sram_axi_jtag_access_collision
//
// Creates AXI and DMI access collision and checks that correct NMI fires.
//
//********************************************************************************
#include <stdint.h>

#include "soc_address_map.h"
#include "printf.h"
#include "riscv_hw_if.h"
#include "soc_ifc.h"
#include "mci.h"
#include "caliptra_ss_lib.h"

volatile char* stdout = (char *)SOC_MCI_TOP_MCI_REG_DEBUG_OUT;
#ifdef CPT_VERBOSITY
    enum printf_verbosity verbosity_g = CPT_VERBOSITY;
#else
    enum printf_verbosity verbosity_g = LOW;
#endif

void nmi_handler(void);

void nmi_handler(void) {
    VPRINTF(LOW, "*** Entering NMI Handler ***\n");

    uint32_t fatal = lsu_read_32(SOC_MCI_TOP_MCI_REG_HW_ERROR_FATAL);
    if (!(fatal & MCI_REG_INTERNAL_HW_ERROR_FATAL_MASK_MASK_MCU_SRAM_DMI_AXI_COLLISION_MASK)) {
        handle_error("Unexpected NMI: HW_ERROR_FATAL=0x%08x, expected MCU_SRAM_DMI_AXI_COLLISION\n", fatal);
    }

    // Clear the fatal error.
    lsu_write_32(SOC_MCI_TOP_MCI_REG_HW_ERROR_FATAL, MCI_REG_INTERNAL_HW_ERROR_FATAL_MASK_MASK_MCU_SRAM_DMI_AXI_COLLISION_MASK);
    if (lsu_read_32(SOC_MCI_TOP_MCI_REG_HW_ERROR_FATAL) & MCI_REG_INTERNAL_HW_ERROR_FATAL_MASK_MASK_MCU_SRAM_DMI_AXI_COLLISION_MASK) {
        handle_error("Unable to clear MCU SRAM DMI AXI COLLISION fatal error\n");
    }
    SEND_STDOUT_CTRL(CMD_MCI_SRAM_DMI_ACCESS_DIS);

    VPRINTF(LOW, "INFO: MCU SRAM DMI AXI COLLISION error raised and cleared as expected\n");
    SEND_STDOUT_CTRL(TB_CMD_TEST_PASS);
}

void main(void) {
    VPRINTF(LOW, "=================\nMCU mci_sram_axi_jtag_access_collision\n=================\n\n");

    // Register NMI handler so the CPU can catch the fatal ECC error.
    lsu_write_32(SOC_MCI_TOP_MCI_REG_MCU_NMI_VECTOR, (uint32_t)(nmi_handler));

    // Unmask the AXI COLLISION uncorrectable fatal interrupt.
    uint32_t mask = lsu_read_32(SOC_MCI_TOP_MCI_REG_INTERNAL_HW_ERROR_FATAL_MASK);
    mask |= MCI_REG_INTERNAL_HW_ERROR_FATAL_MASK_MASK_MCU_SRAM_DMI_AXI_COLLISION_MASK;
    lsu_write_32(SOC_MCI_TOP_MCI_REG_INTERNAL_HW_ERROR_FATAL_MASK, mask);

    // Enable DMI access request.
    SEND_STDOUT_CTRL(CMD_MCI_SRAM_DMI_ACCESS);

    // Issue a byte write to the MCU SRAM address.
    VPRINTF(LOW, "INFO: issuing access to trigger AXI-DMI collision error\n");
    *((volatile uint8_t*)(uintptr_t)SOC_MCI_TOP_MCU_SRAM_BASE_ADDR) = 0xAA;

    // Wait for the interrupt to propagate
    for (uint8_t ii = 0; ii < 160; ii++) {
        __asm__ volatile ("nop"); // Sleep loop as "nop"
    }

    handle_error("Test did not receive expected NMI for MCU SRAM AXI-DMI collision\n");
}

