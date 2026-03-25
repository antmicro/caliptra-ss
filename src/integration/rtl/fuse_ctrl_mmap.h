// SPDX-License-Identifier: Apache-2.0
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
//

#ifndef FUSE_CTRL_MMAP_HEADERS
#define FUSE_CTRL_MMAP_HEADERS

typedef enum {
    // SW_TEST_UNLOCK_PARTITION
    CPTRA_SS_MANUF_DEBUG_UNLOCK_TOKEN = 0x0000,
    // SECRET_MANUF_PARTITION
    CPTRA_CORE_UDS_SEED = 0x0048,
    // SECRET_PROD_PARTITION_0
    CPTRA_CORE_FIELD_ENTROPY_0 = 0x0090,
    // SECRET_PROD_PARTITION_1
    CPTRA_CORE_FIELD_ENTROPY_1 = 0x00A0,
    // SECRET_PROD_PARTITION_2
    CPTRA_CORE_FIELD_ENTROPY_2 = 0x00B0,
    // SECRET_PROD_PARTITION_3
    CPTRA_CORE_FIELD_ENTROPY_3 = 0x00C0,
    // SW_MANUF_PARTITION
    CPTRA_CORE_ANTI_ROLLBACK_DISABLE = 0x00D0,
    CPTRA_CORE_IDEVID_CERT_IDEVID_ATTR = 0x00D8,
    // SECRET_LC_TRANSITION_PARTITION
    CPTRA_SS_TEST_UNLOCK_TOKEN_1 = 0x0140,
    CPTRA_SS_TEST_UNLOCK_TOKEN_2 = 0x0150,
    CPTRA_SS_TEST_UNLOCK_TOKEN_3 = 0x0160,
    CPTRA_SS_TEST_UNLOCK_TOKEN_4 = 0x0170,
    CPTRA_SS_TEST_UNLOCK_TOKEN_5 = 0x0180,
    CPTRA_SS_TEST_UNLOCK_TOKEN_6 = 0x0190,
    CPTRA_SS_TEST_UNLOCK_TOKEN_7 = 0x01A0,
    CPTRA_SS_TEST_EXIT_TO_MANUF_TOKEN = 0x01B0,
    CPTRA_SS_MANUF_TO_PROD_TOKEN = 0x01C0,
    CPTRA_SS_PROD_TO_PROD_END_TOKEN = 0x01D0,
    CPTRA_SS_RMA_TOKEN = 0x01E0,
    // LIFE_CYCLE
    LC_TRANSITION_CNT = 0x01F8,
    LC_STATE = 0x0228,
    // VENDOR_HASHES_MANUF_PARTITION
    CPTRA_CORE_VENDOR_PK_HASH_2 = 0x0250,
    CPTRA_CORE_VENDOR_PK_HASH_2_VALID = 0x0280,
    CPTRA_CORE_VENDOR_PK_HASH_3 = 0x0284,
    CPTRA_CORE_VENDOR_PK_HASH_3_VALID = 0x02B4,
    CPTRA_CORE_VENDOR_PK_HASH_4 = 0x02B8,
    CPTRA_CORE_VENDOR_PK_HASH_4_VALID = 0x02E8,
    CPTRA_CORE_VENDOR_PK_HASH_PAD = 0x02EC,
    // VENDOR_HASHES_OWNER_PROD_PARTITION
    CPTRA_SS_OWNER_PK_HASH = 0x02F8,
    CPTRA_SS_OWNER_PQC_KEY_TYPE = 0x0328,
    CPTRA_SS_OWNER_PK_HASH_VALID = 0x032C,
    // VENDOR_HASHES_PROD_PARTITION
    CPTRA_CORE_VENDOR_PK_HASH_1 = 0x0338,
    CPTRA_CORE_PQC_KEY_TYPE_1 = 0x0368,
    CPTRA_CORE_VENDOR_PK_HASH_1_VALID = 0x036C,
    // VENDOR_REVOCATIONS_PROD_PARTITION
    CPTRA_SS_OWNER_ECC_REVOCATION = 0x0378,
    CPTRA_SS_OWNER_MLDSA_REVOCATION = 0x037C,
    CPTRA_CORE_ECC_REVOCATION_1 = 0x0380,
    CPTRA_CORE_MLDSA_REVOCATION_1 = 0x0384,
    CPTRA_CORE_ECC_REVOCATION_2 = 0x0388,
    CPTRA_CORE_MLDSA_REVOCATION_2 = 0x038C,
    CPTRA_CORE_ECC_REVOCATION_3 = 0x0390,
    CPTRA_CORE_MLDSA_REVOCATION_3 = 0x0394,
    CPTRA_CORE_ECC_REVOCATION_4 = 0x0398,
    CPTRA_CORE_MLDSA_REVOCATION_4 = 0x039C,
    // VENDOR_NON_SECRET_PROD_PARTITION
    CPTRA_SS_VENDOR_SPECIFIC_NON_SECRET_FUSE_0 = 0x03A8,
    // CSR_PARTITION
    CSR_REGION = 0x03B0
} fuse_k;

typedef enum {
    SW_TEST_UNLOCK_PARTITION,
    SECRET_MANUF_PARTITION,
    SECRET_PROD_PARTITION_0,
    SECRET_PROD_PARTITION_1,
    SECRET_PROD_PARTITION_2,
    SECRET_PROD_PARTITION_3,
    SW_MANUF_PARTITION,
    SECRET_LC_TRANSITION_PARTITION,
    LIFE_CYCLE,
    VENDOR_HASHES_MANUF_PARTITION,
    VENDOR_HASHES_OWNER_PROD_PARTITION,
    VENDOR_HASHES_PROD_PARTITION,
    VENDOR_REVOCATIONS_PROD_PARTITION,
    VENDOR_NON_SECRET_PROD_PARTITION,
    CSR_PARTITION
} partition_k;

typedef struct {
    uint32_t index;
    uint32_t address;
    uint32_t digest_address;
    uint32_t variant;
    uint32_t granularity;
    bool is_secret;
    bool hw_digest;
    bool sw_digest;
    bool has_read_lock;
    bool has_ecc;
    uint32_t lc_phase;
    bool is_lifecycle;
    uint32_t num_fuses;
    uint32_t *fuses;
} partition_t;

#define NUM_PARTITIONS 15

uint32_t sw_test_unlock_partition_fuses[] = {
    CPTRA_SS_MANUF_DEBUG_UNLOCK_TOKEN
};
uint32_t secret_manuf_partition_fuses[] = {
    CPTRA_CORE_UDS_SEED
};
uint32_t secret_prod_partition_0_fuses[] = {
    CPTRA_CORE_FIELD_ENTROPY_0
};
uint32_t secret_prod_partition_1_fuses[] = {
    CPTRA_CORE_FIELD_ENTROPY_1
};
uint32_t secret_prod_partition_2_fuses[] = {
    CPTRA_CORE_FIELD_ENTROPY_2
};
uint32_t secret_prod_partition_3_fuses[] = {
    CPTRA_CORE_FIELD_ENTROPY_3
};
uint32_t sw_manuf_partition_fuses[] = {
    CPTRA_CORE_ANTI_ROLLBACK_DISABLE,
    CPTRA_CORE_IDEVID_CERT_IDEVID_ATTR
};
uint32_t secret_lc_transition_partition_fuses[] = {
    CPTRA_SS_TEST_UNLOCK_TOKEN_1,
    CPTRA_SS_TEST_UNLOCK_TOKEN_2,
    CPTRA_SS_TEST_UNLOCK_TOKEN_3,
    CPTRA_SS_TEST_UNLOCK_TOKEN_4,
    CPTRA_SS_TEST_UNLOCK_TOKEN_5,
    CPTRA_SS_TEST_UNLOCK_TOKEN_6,
    CPTRA_SS_TEST_UNLOCK_TOKEN_7,
    CPTRA_SS_TEST_EXIT_TO_MANUF_TOKEN,
    CPTRA_SS_MANUF_TO_PROD_TOKEN,
    CPTRA_SS_PROD_TO_PROD_END_TOKEN,
    CPTRA_SS_RMA_TOKEN
};
uint32_t life_cycle_fuses[] = {
    LC_TRANSITION_CNT,
    LC_STATE
};
uint32_t vendor_hashes_manuf_partition_fuses[] = {
    CPTRA_CORE_VENDOR_PK_HASH_2,
    CPTRA_CORE_VENDOR_PK_HASH_2_VALID,
    CPTRA_CORE_VENDOR_PK_HASH_3,
    CPTRA_CORE_VENDOR_PK_HASH_3_VALID,
    CPTRA_CORE_VENDOR_PK_HASH_4,
    CPTRA_CORE_VENDOR_PK_HASH_4_VALID,
    CPTRA_CORE_VENDOR_PK_HASH_PAD
};
uint32_t vendor_hashes_owner_prod_partition_fuses[] = {
    CPTRA_SS_OWNER_PK_HASH,
    CPTRA_SS_OWNER_PQC_KEY_TYPE,
    CPTRA_SS_OWNER_PK_HASH_VALID
};
uint32_t vendor_hashes_prod_partition_fuses[] = {
    CPTRA_CORE_VENDOR_PK_HASH_1,
    CPTRA_CORE_PQC_KEY_TYPE_1,
    CPTRA_CORE_VENDOR_PK_HASH_1_VALID
};
uint32_t vendor_revocations_prod_partition_fuses[] = {
    CPTRA_SS_OWNER_ECC_REVOCATION,
    CPTRA_SS_OWNER_MLDSA_REVOCATION,
    CPTRA_CORE_ECC_REVOCATION_1,
    CPTRA_CORE_MLDSA_REVOCATION_1,
    CPTRA_CORE_ECC_REVOCATION_2,
    CPTRA_CORE_MLDSA_REVOCATION_2,
    CPTRA_CORE_ECC_REVOCATION_3,
    CPTRA_CORE_MLDSA_REVOCATION_3,
    CPTRA_CORE_ECC_REVOCATION_4,
    CPTRA_CORE_MLDSA_REVOCATION_4
};
uint32_t vendor_non_secret_prod_partition_fuses[] = {
    CPTRA_SS_VENDOR_SPECIFIC_NON_SECRET_FUSE_0
};
uint32_t csr_partition_fuses[] = {
    CSR_REGION
};

partition_t partitions[NUM_PARTITIONS] = {
    // SW_TEST_UNLOCK_PARTITION
    {
        .index = 0,
        .address = 0x0000,
        .digest_address = 0x0040,
        .variant = 0,
        .granularity = 32,
        .is_secret = false,
        .hw_digest = true,
        .sw_digest = false,
        .has_read_lock = false,
        .has_ecc = true,
        .lc_phase = 16,
        .is_lifecycle = false,
        .num_fuses = 1,
        .fuses = sw_test_unlock_partition_fuses
    },
    // SECRET_MANUF_PARTITION
    {
        .index = 1,
        .address = 0x0048,
        .digest_address = 0x0088,
        .variant = 0,
        .granularity = 64,
        .is_secret = true,
        .hw_digest = true,
        .sw_digest = false,
        .has_read_lock = false,
        .has_ecc = true,
        .lc_phase = 16,
        .is_lifecycle = false,
        .num_fuses = 1,
        .fuses = secret_manuf_partition_fuses
    },
    // SECRET_PROD_PARTITION_0
    {
        .index = 2,
        .address = 0x0090,
        .digest_address = 0x0098,
        .variant = 0,
        .granularity = 64,
        .is_secret = true,
        .hw_digest = true,
        .sw_digest = false,
        .has_read_lock = false,
        .has_ecc = true,
        .lc_phase = 17,
        .is_lifecycle = false,
        .num_fuses = 1,
        .fuses = secret_prod_partition_0_fuses
    },
    // SECRET_PROD_PARTITION_1
    {
        .index = 3,
        .address = 0x00A0,
        .digest_address = 0x00A8,
        .variant = 0,
        .granularity = 64,
        .is_secret = true,
        .hw_digest = true,
        .sw_digest = false,
        .has_read_lock = false,
        .has_ecc = true,
        .lc_phase = 17,
        .is_lifecycle = false,
        .num_fuses = 1,
        .fuses = secret_prod_partition_1_fuses
    },
    // SECRET_PROD_PARTITION_2
    {
        .index = 4,
        .address = 0x00B0,
        .digest_address = 0x00B8,
        .variant = 0,
        .granularity = 64,
        .is_secret = true,
        .hw_digest = true,
        .sw_digest = false,
        .has_read_lock = false,
        .has_ecc = true,
        .lc_phase = 17,
        .is_lifecycle = false,
        .num_fuses = 1,
        .fuses = secret_prod_partition_2_fuses
    },
    // SECRET_PROD_PARTITION_3
    {
        .index = 5,
        .address = 0x00C0,
        .digest_address = 0x00C8,
        .variant = 0,
        .granularity = 64,
        .is_secret = true,
        .hw_digest = true,
        .sw_digest = false,
        .has_read_lock = false,
        .has_ecc = true,
        .lc_phase = 17,
        .is_lifecycle = false,
        .num_fuses = 1,
        .fuses = secret_prod_partition_3_fuses
    },
    // SW_MANUF_PARTITION
    {
        .index = 6,
        .address = 0x00D0,
        .digest_address = 0x0138,
        .variant = 1,
        .granularity = 32,
        .is_secret = false,
        .hw_digest = false,
        .sw_digest = true,
        .has_read_lock = true,
        .has_ecc = true,
        .lc_phase = 16,
        .is_lifecycle = false,
        .num_fuses = 2,
        .fuses = sw_manuf_partition_fuses
    },
    // SECRET_LC_TRANSITION_PARTITION
    {
        .index = 7,
        .address = 0x0140,
        .digest_address = 0x01F0,
        .variant = 0,
        .granularity = 64,
        .is_secret = true,
        .hw_digest = true,
        .sw_digest = false,
        .has_read_lock = false,
        .has_ecc = true,
        .lc_phase = 1,
        .is_lifecycle = false,
        .num_fuses = 11,
        .fuses = secret_lc_transition_partition_fuses
    },
    // LIFE_CYCLE
    {
        .index = 8,
        .address = 0x01F8,
        .digest_address = 0x0000,
        .variant = 2,
        .granularity = 32,
        .is_secret = false,
        .hw_digest = false,
        .sw_digest = false,
        .has_read_lock = false,
        .has_ecc = true,
        .lc_phase = 0,
        .is_lifecycle = true,
        .num_fuses = 1,
        .fuses = life_cycle_fuses
    },
    // VENDOR_HASHES_MANUF_PARTITION
    {
        .index = 9,
        .address = 0x0250,
        .digest_address = 0x02F0,
        .variant = 1,
        .granularity = 32,
        .is_secret = false,
        .hw_digest = false,
        .sw_digest = true,
        .has_read_lock = true,
        .has_ecc = true,
        .lc_phase = 16,
        .is_lifecycle = false,
        .num_fuses = 7,
        .fuses = vendor_hashes_manuf_partition_fuses
    },
    // VENDOR_HASHES_OWNER_PROD_PARTITION
    {
        .index = 10,
        .address = 0x02F8,
        .digest_address = 0x0330,
        .variant = 1,
        .granularity = 32,
        .is_secret = false,
        .hw_digest = false,
        .sw_digest = true,
        .has_read_lock = true,
        .has_ecc = true,
        .lc_phase = 17,
        .is_lifecycle = false,
        .num_fuses = 3,
        .fuses = vendor_hashes_owner_prod_partition_fuses
    },
    // VENDOR_HASHES_PROD_PARTITION
    {
        .index = 11,
        .address = 0x0338,
        .digest_address = 0x0370,
        .variant = 1,
        .granularity = 32,
        .is_secret = false,
        .hw_digest = false,
        .sw_digest = true,
        .has_read_lock = true,
        .has_ecc = true,
        .lc_phase = 17,
        .is_lifecycle = false,
        .num_fuses = 3,
        .fuses = vendor_hashes_prod_partition_fuses
    },
    // VENDOR_REVOCATIONS_PROD_PARTITION
    {
        .index = 12,
        .address = 0x0378,
        .digest_address = 0x03A0,
        .variant = 1,
        .granularity = 32,
        .is_secret = false,
        .hw_digest = false,
        .sw_digest = true,
        .has_read_lock = true,
        .has_ecc = false,
        .lc_phase = 17,
        .is_lifecycle = false,
        .num_fuses = 10,
        .fuses = vendor_revocations_prod_partition_fuses
    },
    // VENDOR_NON_SECRET_PROD_PARTITION
    {
        .index = 13,
        .address = 0x03A8,
        .digest_address = 0x0000,
        .variant = 1,
        .granularity = 32,
        .is_secret = false,
        .hw_digest = false,
        .sw_digest = false,
        .has_read_lock = true,
        .has_ecc = false,
        .lc_phase = 17,
        .is_lifecycle = false,
        .num_fuses = 0,
        .fuses = vendor_non_secret_prod_partition_fuses
    },
    // CSR_PARTITION
    {
        .index = 14,
        .address = 0x03B0,
        .digest_address = 0x0000,
        .variant = 1,
        .granularity = 32,
        .is_secret = false,
        .hw_digest = false,
        .sw_digest = false,
        .has_read_lock = false,
        .has_ecc = false,
        .lc_phase = 19,
        .is_lifecycle = false,
        .num_fuses = 0,
        .fuses = csr_partition_fuses
    },
};

#endif // FUSE_CTRL_MMAP_HEADERS
