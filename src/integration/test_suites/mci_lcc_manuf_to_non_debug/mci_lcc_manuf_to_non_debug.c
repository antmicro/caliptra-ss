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
// Test: mci_lcc_manuf_to_non_debug
//
// Transitions the device RAW -> TEST_UNLOCKED0 -> MANUF (DEV).  From MANUF,
// xorshift32 selects two independent paths:
//
//   Translator sub-state (bit 0):
//     0 = TRANSLATOR_MANUF_NON_DEBUG  (PPD=0, debug_locked=1)
//     1 = TRANSLATOR_MANUF_DEBUG      (PPD=1, debug_locked=0)
//
//   Terminating action (bit 1):
//     0 = state_error injection  -> TRANSLATOR_NON_DEBUG
//     1 = SCRAP transition       -> SCRAP state
//
// In both cases SECURITY_STATE must show DEVICE_PRODUCTION(0x3) + debug_locked=1.
//
// SECURITY_STATE register layout:
//   bits [1:0]  device_lifecycle  (0x0=UNPROVISIONED, 0x1=MANUFACTURING, 0x3=PRODUCTION)
//   bit  [2]    debug_locked
//
//********************************************************************************
#include <stdint.h>

#include "soc_address_map.h"
#include "printf.h"
#include "riscv_hw_if.h"
#include "soc_ifc.h"
#include "caliptra_ss_lc_ctrl_address_map.h"
#include "caliptra_ss_lib.h"
#include "fuse_ctrl.h"
#include "lc_ctrl.h"

volatile char* stdout = (char *)SOC_MCI_TOP_MCI_REG_DEBUG_OUT;
#ifdef CPT_VERBOSITY
    enum printf_verbosity verbosity_g = CPT_VERBOSITY;
#else
    enum printf_verbosity verbosity_g = LOW;
#endif

#define LIFECYCLE_MANUFACTURING  (0x1u)
#define LIFECYCLE_PRODUCTION     (0x3u)

// TEX (TEST_EXIT -> MANUF) token — must match test_unlock_token.hjson
static const uint32_t tex_token[4] = {
    0x2f533ae9, 0x341d2478, 0x5f066362, 0xb5fe1577
};

void main(void) {
    VPRINTF(LOW, "=================\nMCU mci_lcc_manuf_to_non_debug\n=================\n\n");

    mcu_cptra_init_d();
    wait_dai_op_idle(0);

    lcc_initialization();
    grant_mcu_for_fc_writes();

    // RAW -> TEST_UNLOCKED0
    transition_state_check(TEST_UNLOCKED0,
                           raw_unlock_token[0], raw_unlock_token[1],
                           raw_unlock_token[2], raw_unlock_token[3], 1);
    lcc_initialization();
    grant_mcu_for_fc_writes();
    initialize_otp_controller();

    // TEST_UNLOCKED0 -> MANUF
    transition_state_check(MANUF,
                           tex_token[0], tex_token[1],
                           tex_token[2], tex_token[3], 1);
    lcc_initialization();
    wait_dai_op_idle(0);

    uint32_t rand_val  = xorshift32();
    uint32_t use_debug = rand_val & 1;
    uint32_t use_scrap = (rand_val >> 1) & 1;

    if (use_debug) {
        force_PPD_pin();
    }

    // Verify MANUFACTURING lifecycle and expected debug_locked
    uint32_t sec_state = lsu_read_32(SOC_MCI_TOP_MCI_REG_SECURITY_STATE);
    uint32_t lifecycle = sec_state & MCI_REG_SECURITY_STATE_DEVICE_LIFECYCLE_MASK;
    if (lifecycle != LIFECYCLE_MANUFACTURING) {
        VPRINTF(LOW, "ERROR: expected MANUFACTURING(0x%x) in MANUF state, got lifecycle=0x%x (SECURITY_STATE=0x%08x)\n",
                LIFECYCLE_MANUFACTURING, lifecycle, sec_state);
        SEND_STDOUT_CTRL(0x01);
        return;
    }
    uint32_t exp_locked = use_debug ? 0u : 1u;
    uint32_t act_locked = !!(sec_state & MCI_REG_SECURITY_STATE_DEBUG_LOCKED_MASK);
    if (act_locked != exp_locked) {
        VPRINTF(LOW, "ERROR: MANUF state expected debug_locked=%u (%s), got %u (SECURITY_STATE=0x%08x)\n",
                exp_locked, use_debug ? "MANUF_DEBUG" : "MANUF_NON_DEBUG", act_locked, sec_state);
        SEND_STDOUT_CTRL(0x01);
        return;
    }
    VPRINTF(LOW, "INFO: MANUF state OK — lifecycle=MANUFACTURING(0x%x), debug_locked=%u [%s] (SECURITY_STATE=0x%08x)\n",
            lifecycle, act_locked, use_debug ? "MANUF_DEBUG" : "MANUF_NON_DEBUG", sec_state);

    if (use_scrap) {
        VPRINTF(LOW, "INFO: SCRAP path — issuing SCRAP transition from MANUF\n");
        if (!use_debug) {
            force_PPD_pin();
        }
        sw_transition_req(calc_lc_state_mnemonic(SCRAP), 0, 0, 0, 0, 0);
        reset_fc_lcc_rtl();
        lcc_initialization();
        wait_dai_op_idle(0);
    } else {
        VPRINTF(LOW, "INFO: state_error path — injecting state_error into MCI LCC translator\n");
        lsu_write_32(SOC_MCI_TOP_MCI_REG_DEBUG_OUT, CMD_LC_INJECT_STATE_ERROR);

        uint32_t locked = 0;
        for (uint32_t i = 0; i < 10000; i++) {
            sec_state = lsu_read_32(SOC_MCI_TOP_MCI_REG_SECURITY_STATE);
            if (sec_state & MCI_REG_SECURITY_STATE_DEBUG_LOCKED_MASK) {
                locked = 1;
                break;
            }
        }
        if (!locked) {
            VPRINTF(LOW, "ERROR: debug_locked did not become 1 after state_error injection (SECURITY_STATE=0x%08x)\n", sec_state);
            SEND_STDOUT_CTRL(0x01);
            return;
        }
    }

    // Verify DEVICE_PRODUCTION + debug_locked=1
    sec_state = lsu_read_32(SOC_MCI_TOP_MCI_REG_SECURITY_STATE);
    lifecycle = sec_state & MCI_REG_SECURITY_STATE_DEVICE_LIFECYCLE_MASK;
    if (lifecycle != LIFECYCLE_PRODUCTION) {
        VPRINTF(LOW, "ERROR: expected DEVICE_PRODUCTION(0x%x), got lifecycle=0x%x (SECURITY_STATE=0x%08x)\n",
                LIFECYCLE_PRODUCTION, lifecycle, sec_state);
        SEND_STDOUT_CTRL(0x01);
        return;
    }
    if (!(sec_state & MCI_REG_SECURITY_STATE_DEBUG_LOCKED_MASK)) {
        VPRINTF(LOW, "ERROR: expected debug_locked=1 after %s, SECURITY_STATE=0x%08x\n",
                use_scrap ? "SCRAP" : "state_error", sec_state);
        SEND_STDOUT_CTRL(0x01);
        return;
    }
    VPRINTF(LOW, "INFO: DEVICE_PRODUCTION confirmed — lifecycle=0x%x, debug_locked=1 (SECURITY_STATE=0x%08x)\n",
            lifecycle, sec_state);

    if (!use_scrap) {
        lsu_write_32(SOC_MCI_TOP_MCI_REG_DEBUG_OUT, CMD_LC_RELEASE_STATE_ERROR);
    }

    for (uint8_t i = 0; i < 160; i++) {
        __asm__ volatile ("nop");
    }

    SEND_STDOUT_CTRL(0xff);
}
