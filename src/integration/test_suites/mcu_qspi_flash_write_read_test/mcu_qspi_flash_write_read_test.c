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
//********************************************************************************
// SPDX-License-Identifier: Apache-2.0
//
//
// Licensed under the Apache License, Version 2.0 (the \"License\");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an \"AS IS\" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//********************************************************************************"

#include "soc_address_map.h"
#include "printf.h"
#include "riscv_hw_if.h"
#include "soc_ifc.h"
#include "caliptra_ss_lib.h"
#include "string.h"
#include "stdint.h"
#include "veer-csr.h"
#include <stdint.h>

volatile char* stdout = (char *)0xa4011014;;

#ifdef CPT_VERBOSITY
    enum printf_verbosity verbosity_g = CPT_VERBOSITY;
#else
    enum printf_verbosity verbosity_g = LOW;
#endif

#define QSPI_BASE              0xa4081000

#define SRR_OFFSET             0x40
#define SPICR_OFFSET           0x60
#define SPISR_OFFSET           0x64
#define SPI_DTR_OFFSET         0x68
#define SPI_DRR_OFFSET         0x6c
#define SPISSR_OFFSET          0x70
#define SPI_TX_FIFO_OCR_OFFSET 0x74
#define SPI_RX_FIFO_OCR_OFFSET 0x78
#define SPI_DGIER_OFFSET       0x1c
#define SPI_IPISR_OFFSET       0x20
#define SPI_IPIER_OFFSET       0x28

/* SRR bit definitions */
#define SRR_SOFTRESET_MAGIC 0xa

#define BIT(n)  (1 << (n))

/* SPICR bit definitions */
#define SPICR_LOOP            BIT(0)
#define SPICR_SPE             BIT(1)
#define SPICR_MASTER          BIT(2)
#define SPICR_CPOL            BIT(3)
#define SPICR_CPHA            BIT(4)
#define SPICR_TX_FIFO_RESET   BIT(5)
#define SPICR_RX_FIFO_RESET   BIT(6)
#define SPICR_MANUAL_SS       BIT(7)
#define SPICR_MASTER_XFER_INH BIT(8)
#define SPICR_LSB_FIRST       BIT(9)

/* SPISR bit definitions */
#define SPISR_RX_EMPTY          BIT(0)
#define SPISR_RX_FULL           BIT(1)
#define SPISR_TX_EMPTY          BIT(2)
#define SPISR_TX_FULL           BIT(3)
#define SPISR_MODF              BIT(4)
#define SPISR_SLAVE_MODE_SELECT BIT(5)
#define SPISR_CPOL_CPHA_ERROR   BIT(6)
#define SPISR_SLAVE_MODE_ERROR  BIT(7)
#define SPISR_MSB_ERROR         BIT(8)
#define SPISR_LOOPBACK_ERROR    BIT(9)
#define SPISR_COMMAND_ERROR     BIT(10)

#define SPISR_ERROR_MASK (SPISR_COMMAND_ERROR |		\
			  SPISR_LOOPBACK_ERROR |	\
			  SPISR_MSB_ERROR |		\
			  SPISR_SLAVE_MODE_ERROR |	\
			  SPISR_CPOL_CPHA_ERROR)

/* DGIER bit definitions */
#define DGIER_GIE BIT(31)

/* IPISR and IPIER bit definitions */
#define IPIXR_MODF               BIT(0)
#define IPIXR_SLAVE_MODF         BIT(1)
#define IPIXR_DTR_EMPTY          BIT(2)
#define IPIXR_DTR_UNDERRUN       BIT(3)
#define IPIXR_DRR_FULL           BIT(4)
#define IPIXR_DRR_OVERRUN        BIT(5)
#define IPIXR_TX_FIFO_HALF_EMPTY BIT(6)
#define IPIXR_SLAVE_MODE_SELECT  BIT(7)
#define IPIXR_DDR_NOT_EMPTY      BIT(8)
#define IPIXR_CPOL_CPHA_ERROR    BIT(9)
#define IPIXR_SLAVE_MODE_ERROR   BIT(10)
#define IPIXR_MSB_ERROR          BIT(11)
#define IPIXR_LOOPBACK_ERROR     BIT(12)
#define IPIXR_COMMAND_ERROR      BIT(13)

#define BUFFER_SIZE 12

static void xlnx_quadspi_cs_control(bool on)
{
	uint32_t spissr = 0x01;

	if (on) {
		spissr &= ~(0x01);
	}

  lsu_write_32(QSPI_BASE + SPISSR_OFFSET, spissr);
}

static int xlnx_quadspi_init()
{
  uint32_t reg = 0x0;

  printf("MCU: QSPI init, soft reset...\n");
  lsu_write_32(QSPI_BASE + SRR_OFFSET, SRR_SOFTRESET_MAGIC);
  printf("MCU: soft reset done\n");

	return 0;
}

static void spi_xfer(uint8_t *tx_buf, uint8_t *rx_buf, uint32_t len)
{
    uint32_t spisr, spicr;

    spicr = lsu_read_32(QSPI_BASE + SPICR_OFFSET);
		spicr |= SPICR_TX_FIFO_RESET | SPICR_RX_FIFO_RESET | SPICR_SPE | SPICR_MASTER;
		lsu_write_32(QSPI_BASE + SPICR_OFFSET, spicr);

    uint32_t tx_count = len >= 16 ? 16 : len;
    int i, j = 0;

    for (i = 0; i < tx_count; i++) {
      lsu_write_32(QSPI_BASE + SPI_DTR_OFFSET, tx_buf[i]);
    }

    xlnx_quadspi_cs_control(true);

		/* Master Inhibit enable in the CR */
    spicr = lsu_read_32(QSPI_BASE + SPICR_OFFSET);
    spicr &= ~SPICR_MASTER_XFER_INH;
		lsu_write_32(QSPI_BASE + SPICR_OFFSET, spicr);

    while (true) {
      spisr = lsu_read_32(QSPI_BASE + SPISR_OFFSET);

      if (i < len && !(spisr & SPISR_TX_FULL)) {
        lsu_write_32(QSPI_BASE + SPI_DTR_OFFSET, tx_buf[i++]);
      }

			if (i == len && (spisr & SPISR_TX_EMPTY)) {
        break;
      }

      if (!(spisr & SPISR_RX_EMPTY)) {
        rx_buf[j++] = (uint8_t) lsu_read_32(QSPI_BASE + SPI_DRR_OFFSET);
      }
    }

    xlnx_quadspi_cs_control(false);

		/* Master Inhibit disable in the CR */
    spicr = lsu_read_32(QSPI_BASE + SPICR_OFFSET);
    spicr |= SPICR_MASTER_XFER_INH;
		lsu_write_32(QSPI_BASE + SPICR_OFFSET, spicr);

    while(true) {
      spisr = lsu_read_32(QSPI_BASE + SPISR_OFFSET);
      if (!(spisr & SPISR_RX_EMPTY))
        rx_buf[j++] = (uint8_t) lsu_read_32(QSPI_BASE + SPI_DRR_OFFSET);
      if (j == len)
        break;
    }
}

#define READ_ID_CMD 0x9F
#define READ_ID_BUF_SIZE 5

static void flash_read_id()
{
  uint8_t tx_buf[READ_ID_BUF_SIZE] = {0};
  uint8_t rx_buf[READ_ID_BUF_SIZE] = {0};
  tx_buf[0] = READ_ID_CMD;

  spi_xfer(tx_buf, rx_buf, READ_ID_BUF_SIZE);
  printf("ID: Manufacturer ID: 0x%x Mem type: 0x%x Mem size: 0x%x UID: 0x%x\n", rx_buf[1], rx_buf[2], rx_buf[3], rx_buf[4]);

}

#define READ_STATUS_CMD 0x05
#define READ_STATUS_BUF_SIZE 2

static uint8_t flash_read_status()
{
  uint8_t tx_buf[READ_STATUS_BUF_SIZE] = {0};
  uint8_t rx_buf[READ_STATUS_BUF_SIZE] = {0};
  tx_buf[0] = READ_STATUS_CMD;

  spi_xfer(tx_buf, rx_buf, READ_STATUS_BUF_SIZE);
  return rx_buf[1];
}

#define WRITE_ENABLE_CMD 0x06
#define WRITE_ENABLE_BUF_SIZE 1

static void flash_write_enable()
{
  uint8_t tx_buf[WRITE_ENABLE_BUF_SIZE] = {0};
  uint8_t rx_buf[WRITE_ENABLE_BUF_SIZE] = {0};
  tx_buf[0] = WRITE_ENABLE_CMD;

  spi_xfer(tx_buf, rx_buf, WRITE_ENABLE_BUF_SIZE);
}

#define ERASE_SECTOR_CMD 0xD8
#define ERASE_SECTOR_BUF_SIZE 4

static void flash_erase_sector(uint32_t addr)
{
  uint8_t tx_buf[ERASE_SECTOR_BUF_SIZE] = {0};
  uint8_t rx_buf[ERASE_SECTOR_BUF_SIZE] = {0};

  tx_buf[0] = ERASE_SECTOR_CMD;
  tx_buf[1] = (addr >> 16) & 0xFF;
  tx_buf[2] = (addr >> 8)  & 0xFF;
  tx_buf[3] = addr & 0xFF;

  flash_write_enable();

  spi_xfer(tx_buf, rx_buf, ERASE_SECTOR_BUF_SIZE);

  while (true) {
    uint8_t status = flash_read_status();
    if ((status & 0x01) == 0) {
      break;
    }
  }
}

#define WRITE_DATA_CMD 0x02
#define WRITE_DATA_BUF_SIZE (256 + 4)

static void flash_write_page(uint32_t addr, uint8_t *data, size_t len)
{
  uint8_t status;
  uint8_t tx_buf[WRITE_DATA_BUF_SIZE] = {0};
  uint8_t rx_buf[WRITE_DATA_BUF_SIZE] = {0};

  tx_buf[0] = WRITE_DATA_CMD;
  tx_buf[1] = (addr >> 16) & 0xFF;
  tx_buf[2] = (addr >> 8)  & 0xFF;
  tx_buf[3] = addr & 0xFF;

  memcpy(&tx_buf[4], data, len);

  flash_write_enable();

  spi_xfer(tx_buf, rx_buf, len + 4);

  while (true) {
    status = flash_read_status();
    if ((status & 0x01) == 0) {
      break;
    }
  }
}

#define READ_DATA_CMD 0x03
#define READ_DATA_BUF_SIZE (256 + 4)

static void flash_read_data(uint32_t addr, uint8_t *data, uint32_t len)
{
  uint8_t tx_buf[READ_DATA_BUF_SIZE] = {0};
  uint8_t rx_buf[READ_DATA_BUF_SIZE] = {0};

  tx_buf[0] = READ_DATA_CMD;

  // Address
  tx_buf[1] = (addr >> 16) & 0xFF;
  tx_buf[2] = (addr >> 8)  & 0xFF;
  tx_buf[3] = addr & 0xFF;

  spi_xfer(tx_buf, rx_buf, len + 4);
  memcpy(data, &rx_buf[4], len);
}

#if 0
void flash_write(uint32_t addr, uint8_t *buf, size_t len)
{
    while (len > 0) {
        uint32_t page_off = addr & 0xFF;
        size_t chunk = 256 - page_off;

        if (chunk > len)
            chunk = len;

        flash_write_enable();

        flash_page_program(addr, buf, chunk);

        flash_wait_ready();

        addr += chunk;
        buf  += chunk;
        len  -= chunk;
    }
}
#endif

void main (void)
{
    int argc=0;
    char *argv[1];
    uint8_t status;
    uint32_t data[4] = {
      0x12345678,
      0xABCDCAFE,
      0x23456789,
      0xFEEDCAFE,
    };
    uint32_t data_read[4];

    printf("MCU: QSPI test\n");
    xlnx_quadspi_init();

    printf("MCU: Read ID\n");
    flash_read_id();

    printf("MCU: Erase Sector\n");
    flash_erase_sector(0x00);


    printf("MCU: Write Page\n");
    flash_write_page(0x00, (uint8_t *) data, 16);

    printf("MCU: Read Data\n");
    flash_read_data(0x00, (uint8_t *) data_read, 16);

    for (int i = 0; i < 4; i++)
      printf("data[%d] = 0x%x\n", i, data_read[i]);

    if (memcmp(data, data_read, 16) != 0)
      printf("QSPI data mismatch!\n");
    else
      printf("QSPI data match!\n");
}
