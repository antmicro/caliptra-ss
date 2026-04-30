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
#include <string.h>
#include <stdint.h>
#include <time.h>
#include <stdlib.h>
#include <stdbool.h>

#include "soc_address_map.h"
#include "printf.h"
#include "riscv_hw_if.h"
#include "soc_ifc.h"
#include "caliptra_ss_lc_ctrl_address_map.h"
#include "caliptra_ss_lib.h"
#include "fuse_ctrl.h"
#include "lc_ctrl.h"
#include "fuse_ctrl_mmap.h"

volatile char* stdout = (char *)SOC_MCI_TOP_MCI_REG_DEBUG_OUT;
#ifdef CPT_VERBOSITY
    enum printf_verbosity verbosity_g = CPT_VERBOSITY;
#else
    enum printf_verbosity verbosity_g = LOW;
#endif

volatile int rst_count  = 0;

void test_unlocked0_provision() {
    const uint32_t sentinel = 0xA5;

    uint32_t act_state = lsu_read_32(LC_CTRL_LC_STATE_OFFSET);
    uint32_t exp_state = calc_lc_state_mnemonic(TEST_UNLOCKED0);
    if (act_state != exp_state) {
        VPRINTF(LOW, "ERROR: incorrect state: exp: %08X, act: %08X\n", act_state, exp_state);
        exit(1);
    }

    uint32_t write_value0, write_value1;
    uint32_t read_value0, read_value1;
    // Exclude life-cycle partition as it is not writable and
    // CSR and VENDOR_NON_SECRET_PROD_PARTITION partitions as they don't contain fuses
    uint32_t rnd_fuse_addresses[NUM_PARTITIONS-3];
    uint32_t written_value[NUM_PARTITIONS][2];
    uint32_t part_idx;

    for (uint32_t i = 0; i < (NUM_PARTITIONS-3); i++) {
        part_idx = i;
        if (i >= LIFE_CYCLE) part_idx++;
        if (i >= CSR_PARTITION) part_idx++;

        // 'xorshift32() % 0' is undefined behaviour, don't allow that to happen
        if (partitions[part_idx].num_fuses == 0) {
            VPRINTF(LOW, "ERROR: partition with index %d has no fuses\n", part_idx);
            continue;
        }

        if (partitions[part_idx].address > 0x40 && partitions[part_idx].address < 0xD0) {
            grant_caliptra_core_for_fc_writes();
            SEND_STDOUT_CTRL(CMD_DISABLE_CPTR_DEBUG);
        } else {
            grant_mcu_for_fc_writes();
            SEND_STDOUT_CTRL(CMD_RELEASE_CPTR_DEBUG);
        }

        rnd_fuse_addresses[i] = partitions[part_idx].fuses[xorshift32() % partitions[part_idx].num_fuses];

        write_value0 = xorshift32();
        write_value1 = xorshift32();
        dai_wr(rnd_fuse_addresses[i], write_value0, write_value1, partitions[part_idx].granularity, 0);
        written_value[part_idx][0] = write_value0;
        written_value[part_idx][1] = write_value1;

        dai_rd(rnd_fuse_addresses[i], &read_value0, &read_value1, partitions[part_idx].granularity, 0);
        if (read_value0  != write_value0 ||
            (partitions[part_idx].granularity == 64 && read_value1 != write_value1)
           ) {
            VPRINTF(LOW, "ERROR: incorrect value: exp: %08X act: %08X\n", write_value0, read_value0);
            if (partitions[part_idx].granularity == 64) {
                VPRINTF(LOW, "ERROR: incorrect value: exp: %08X act: %08X\n", write_value1, read_value1);
            }
        }

        if (partitions[part_idx].sw_digest) {
            dai_wr(partitions[part_idx].digest_address, xorshift32();, xorshift32(), 64, 0);
        } else if (partitions[part_idx].hw_digest) {
            calculate_digest(partitions[part_idx].address);
        }
    }

    reset_fc_lcc_rtl();
    wait_dai_op_idle(0);

    for (uint32_t i = 0; i < (NUM_PARTITIONS-1); i++) {
        part_idx = i;
        if (i >= LIFE_CYCLE) part_idx++;
        if (i >= CSR_PARTITION) part_idx++;

        if (partitions[part_idx].address > 0x40 && partitions[part_idx].address < 0xD0) {
            grant_caliptra_core_for_fc_writes();
            SEND_STDOUT_CTRL(CMD_DISABLE_CPTR_DEBUG);
        } else {
            grant_mcu_for_fc_writes();
            SEND_STDOUT_CTRL(CMD_RELEASE_CPTR_DEBUG);
        }

        if (partitions[part_idx].sw_digest || partitions[part_idx].hw_digest) {
            dai_wr(rnd_fuse_addresses[i], xorshift32(), xorshift32(), partitions[part_idx].granularity, OTP_CTRL_STATUS_DAI_ERROR_MASK);
        }

        if (partitions[part_idx].sw_digest) {
            dai_rd(rnd_fuse_addresses[i], &read_value0, &read_value1, partitions[part_idx].granularity, 0);
            if (read_value0 != written_value[part_idx][0] ||
                (partitions[part_idx].granularity == 64 && read_value1 != written_value[part_idx][1])
               ) {
                VPRINTF(LOW, "ERROR: incorrect value: exp: %08X act: %08X\n", written_value[part_idx][0], read_value0);
                written_value[part_idx][0] {
                    VPRINTF(LOW, "ERROR: incorrect value: exp: %08X act: %08X\n", written_value[part_idx][1], read_value1);
                }
            }
        }
    }
}

void main (void) {
    if (rst_count == 0) {
        rst_count += 1;
        VPRINTF(LOW, "=================\nMCU Caliptra Boot Go\n=================\n\n")

        mcu_cptra_init_d();
        wait_dai_op_idle(0);

        lcc_initialization();
        grant_mcu_for_fc_writes();

        transition_state_check(TEST_UNLOCKED0, raw_unlock_token[0], raw_unlock_token[1], raw_unlock_token[2], raw_unlock_token[3], 1);

        initialize_otp_controller();

        test_unlocked0_provision();

        SEND_STDOUT_CTRL(TB_CMD_COLD_RESET);
        for (uint8_t ii = 0; ii < 160; ii++) {
            __asm__ volatile ("nop"); // Sleep loop as "nop"
        }
    } else if (rst_count == 1) {
        SEND_STDOUT_CTRL(0xff);

        for (uint8_t ii = 0; ii < 160; ii++) {
            __asm__ volatile ("nop"); // Sleep loop as "nop"
        }
    }
}
