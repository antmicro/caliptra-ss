// SPDX-License-Identifier: Apache-2.0

#include "caliptra_defines.h"
#include "printf.h"
#include "riscv_hw_if.h"
#include "i3c_csr_accessors.h"
#include "I3CCSR.h"

#define HCI_VERSION (0x120)
#define I3C_RECOVERY_LOCAL_IMAGE 0x0

// Helpers for Recovery Flow CSRs
#define I3C_DEVICE_ID_LOW 0x0
#define I3C_DEVICE_ID_MASK 0x1
#define I3C_DEVICE_STATUS_LOW 0x0
#define I3C_DEVICE_STATUS_MASK 0x3
#define I3C_LOCAL_C_IMAGE_SUPPORT_LOW 0x6
#define I3C_LOCAL_C_IMAGE_SUPPORT_MASK 0x40
#define I3C_PUSH_C_IMAGE_SUPPORT_LOW 0x7
#define I3C_PUSH_C_IMAGE_SUPPORT_MASK 0x80
#define I3C_INDIRECT_CONTROL_LOW 0x5
#define I3C_INDIRECT_CONTROL_MASK 0x20
#define I3C_RECOVERY_STATUS_LOW 0x0
#define I3C_RECOVERY_STATUS_MASK 0xff


volatile char* stdout = (char *)0xd0580000;
volatile uint32_t intr_count = 0;
volatile uint32_t rst_count __attribute__((section(".dccm.persistent"))) = 0;
#ifdef CPT_VERBOSITY
enum printf_verbosity verbosity_g = CPT_VERBOSITY;
#else
enum printf_verbosity verbosity_g = LOW;
#endif

int check_and_report_value(uint32_t value, uint32_t expected) {
  if (value == expected) {
    printf("CORRECT\n");
    return 0;
  }
  else {
    printf("ERROR (0x%x vs 0x%x)\n", value, expected);
    return 1;
  }
}


int report_recovery_status(uint32_t value) {
  printf("Recovery status: ");
  switch (value)
  {
  case 0x0:
    printf("Not in recovery mode.\n");
    return 1;
  case 0x1:
    printf("Awaiting recovery image.\n");
    break;
  case 0x2:
    printf("Booting recovery image.\n");
    break;
  case 0x3:
    printf("Recovery successful.\n");
    break;
  case 0xc:
    printf("Recovery failed.\n");
    break;
  case 0xd:
    printf("Recovery image authentication error.\n");
    break;
  case 0xe:
    printf("Error entering recovery mode.\n");
    break;
  case 0xf:
    printf("Invalid component address space.\n");
    break;
  default:
    printf("Undefined recovery status.\n");
    break;
  }
  return 0;
}

// Caliptra MCU bringup from src/integration/test_suites/mcu_cptra_bringup/mcu_cptra_bringup.c
#define BOOT_IDLE 0
#define BOOT_FUSE 1
#define BOOT_FW_RST 2
#define BOOT_WAIT 3
#define BOOT_DONE 4
#define DATA_READY 1

void bringup (void) {
    int argc=0;
    char *argv[1];
    uint32_t boot_fsm_ps;
    const uint32_t mbox_dlen = 64;
    uint32_t mbox_data[] = { 0x00000000,
                             0x11111111,
                             0x22222222,
                             0x33333333,
                             0x44444444,
                             0x55555555,
                             0x66666666,
                             0x77777777,
                             0x88888888,
                             0x99999999,
                             0xaaaaaaaa,
                             0xbbbbbbbb,
                             0xcccccccc,
                             0xdddddddd,
                             0xeeeeeeee,
                             0xffffffff };
    uint32_t mbox_resp_dlen;
    uint32_t mbox_resp_data;

    VPRINTF(LOW, "=================\nMCU Caliptra Bringup\n=================\n\n")

    ////////////////////////////////////
    // Fuse and Boot Bringup
    //
    // Wait for ready_for_fuses
    while(!(lsu_read_32(CLP_SOC_IFC_REG_CPTRA_FLOW_STATUS) & SOC_IFC_REG_CPTRA_FLOW_STATUS_READY_FOR_FUSES_MASK));

    // Initialize fuses
    lsu_write_32(CLP_SOC_IFC_REG_CPTRA_FUSE_WR_DONE, SOC_IFC_REG_CPTRA_FUSE_WR_DONE_DONE_MASK);
    VPRINTF(LOW, "MCU: Set fuse wr done\n");

    // Wait for Boot FSM to stall (on breakpoint) or finish bootup
    boot_fsm_ps = (lsu_read_32(/*CLP_SOC_IFC_REG_CPTRA_FLOW_STATUS*/0x3003003c) & SOC_IFC_REG_CPTRA_FLOW_STATUS_BOOT_FSM_PS_MASK) >> SOC_IFC_REG_CPTRA_FLOW_STATUS_BOOT_FSM_PS_LOW;
    while(boot_fsm_ps != BOOT_DONE && boot_fsm_ps != BOOT_WAIT) {
        for (uint8_t ii = 0; ii < 16; ii++) {
            __asm__ volatile ("nop"); // Sleep loop as "nop"
        }
        boot_fsm_ps = (lsu_read_32(/*CLP_SOC_IFC_REG_CPTRA_FLOW_STATUS*/0x3003003c) & SOC_IFC_REG_CPTRA_FLOW_STATUS_BOOT_FSM_PS_MASK) >> SOC_IFC_REG_CPTRA_FLOW_STATUS_BOOT_FSM_PS_LOW;
    }

    // Advance from breakpoint, if set
    if (boot_fsm_ps == BOOT_WAIT) {
        lsu_write_32(CLP_SOC_IFC_REG_CPTRA_BOOTFSM_GO, SOC_IFC_REG_CPTRA_BOOTFSM_GO_GO_MASK);
    }
    VPRINTF(LOW, "MCU: Set BootFSM GO\n");

    ////////////////////////////////////
    // Mailbox command test
    //

    // MBOX: Wait for ready_for_fw
    while(!(lsu_read_32(CLP_SOC_IFC_REG_CPTRA_FLOW_STATUS) & SOC_IFC_REG_CPTRA_FLOW_STATUS_READY_FOR_FW_MASK)) {
        for (uint8_t ii = 0; ii < 16; ii++) {
            __asm__ volatile ("nop"); // Sleep loop as "nop"
        }
    }
    VPRINTF(LOW, "MCU: Ready for FW\n");

    // MBOX: Setup valid AXI ID
    lsu_write_32(CLP_SOC_IFC_REG_CPTRA_MBOX_VALID_PAUSER_0, 0);
//    lsu_write_32(CLP_SOC_IFC_REG_CPTRA_MBOX_VALID_AXI_ID_1, 1);
//    lsu_write_32(CLP_SOC_IFC_REG_CPTRA_MBOX_VALID_AXI_ID_2, 2);
//    lsu_write_32(CLP_SOC_IFC_REG_CPTRA_MBOX_VALID_AXI_ID_3, 3);
    lsu_write_32(CLP_SOC_IFC_REG_CPTRA_MBOX_PAUSER_LOCK_0, SOC_IFC_REG_CPTRA_MBOX_PAUSER_LOCK_0_LOCK_MASK);
//    lsu_write_32(CLP_SOC_IFC_REG_CPTRA_MBOX_AXI_ID_LOCK_1, SOC_IFC_REG_CPTRA_MBOX_AXI_ID_LOCK_1_LOCK_MASK);
//    lsu_write_32(CLP_SOC_IFC_REG_CPTRA_MBOX_AXI_ID_LOCK_2, SOC_IFC_REG_CPTRA_MBOX_AXI_ID_LOCK_2_LOCK_MASK);
//    lsu_write_32(CLP_SOC_IFC_REG_CPTRA_MBOX_AXI_ID_LOCK_3, SOC_IFC_REG_CPTRA_MBOX_AXI_ID_LOCK_3_LOCK_MASK);
    VPRINTF(LOW, "MCU: Configured MBOX Valid AXI ID\n");

    // MBOX: Acquire lock
    while((lsu_read_32(CLP_MBOX_CSR_MBOX_LOCK) & MBOX_CSR_MBOX_LOCK_LOCK_MASK));
    VPRINTF(LOW, "MCU: Mbox lock acquired\n");

    // MBOX: Write CMD
    lsu_write_32(CLP_MBOX_CSR_MBOX_CMD, 0xFADECAFE); // Resp required

    // MBOX: Write DLEN
    lsu_write_32(CLP_MBOX_CSR_MBOX_DLEN, 64);

    // MBOX: Write datain
    for (uint32_t ii = 0; ii < mbox_dlen/4; ii++) {
        lsu_write_32(CLP_MBOX_CSR_MBOX_DATAIN, mbox_data[ii]);
    }

    // MBOX: Execute
    lsu_write_32(CLP_MBOX_CSR_MBOX_EXECUTE, MBOX_CSR_MBOX_EXECUTE_EXECUTE_MASK);
    VPRINTF(LOW, "MCU: Mbox execute\n");

    // MBOX: Poll status
    while(((lsu_read_32(CLP_MBOX_CSR_MBOX_STATUS) & MBOX_CSR_MBOX_STATUS_STATUS_MASK) >> MBOX_CSR_MBOX_STATUS_STATUS_LOW) != DATA_READY) {
        for (uint8_t ii = 0; ii < 16; ii++) {
            __asm__ volatile ("nop"); // Sleep loop as "nop"
        }
    }
    VPRINTF(LOW, "MCU: Mbox response ready\n");

    // MBOX: Read response data length
    mbox_resp_dlen = lsu_read_32(CLP_MBOX_CSR_MBOX_DLEN);

    // MBOX: Read dataout
    for (uint32_t ii = 0; ii < (mbox_resp_dlen/4 + (mbox_resp_dlen%4 ? 1 : 0)); ii++) {
        mbox_resp_data = lsu_read_32(CLP_MBOX_CSR_MBOX_DATAOUT);
    }
    VPRINTF(LOW, "MCU: Mbox response received\n");

    // MBOX: Clear Execute
    lsu_write_32(CLP_MBOX_CSR_MBOX_EXECUTE, 0);
    VPRINTF(LOW, "MCU: Mbox execute clear\n");

    SEND_STDOUT_CTRL(0xff);

}

void main() {
  int error, data;

  bringup();

  printf("---------------------------\n");
  printf("     I3C Recovery Test     \n");
  printf("---------------------------\n");

  // Enter recovery mode
  // Write `0x3` to `DEVICE_STATUS`
  write_i3c_reg_field(I3C_REG_I3C_EC_SECFWRECOVERYIF_DEVICE_STATUS_0, I3C_DEVICE_STATUS_LOW, I3C_DEVICE_STATUS_MASK, 0x3);

  // Ensure the recovery handler changed mode and is awaiting recovery image
  // Read `RECOVERY_STATUS` - should be `1`
  data = read_i3c_reg_field(I3C_REG_I3C_EC_SECFWRECOVERYIF_RECOVERY_STATUS, I3C_RECOVERY_STATUS_LOW, I3C_RECOVERY_STATUS_MASK);
  // TODO: Add timeout
  while (!data) {
    data = read_i3c_reg_field(I3C_REG_I3C_EC_SECFWRECOVERYIF_RECOVERY_STATUS, I3C_RECOVERY_STATUS_LOW, I3C_RECOVERY_STATUS_MASK);
  }

  error += report_recovery_status(data);

  printf("\n----------------------------------------\n");
  // End the sim in failure or print hello world upon success
  if (error > 0) printf("%c", 0x1);
  else printf("\nHello World\n");
}
