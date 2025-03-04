/******************************************************************************
 *
 * Copyright (C) 2022-2023 Maxim Integrated Products, Inc. (now owned by 
 * Analog Devices, Inc.),
 * Copyright (C) 2023-2024 Analog Devices, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 ******************************************************************************/

/**
 * @file    flash.c
 * @brief   Flash read/write/erase functions implementation
 */

#include "flash.h"
#include <stdio.h>
#include "icc.h"
#include "flc.h"
#include "flc_regs.h"
#include "gcr_regs.h"

/***** Functions *****/
static int flash_write4(uint32_t startaddr, uint32_t length, uint32_t *data, bool verify);

//******************************************************************************
int flash_read(const struct lfs_config *c, lfs_block_t block, lfs_off_t off, void *buffer,
               lfs_size_t size)
{
    uint32_t first_block = *(uint32_t *)c->context;
    uint32_t startaddr = MXC_FLASH_PAGE_ADDR((first_block + block)) + off;
    uint8_t *data = (uint8_t *)buffer;

    // Copy data from flash into the data buffer
    for (uint8_t *ptr = (uint8_t *)startaddr; ptr < (uint8_t *)(startaddr + size); ptr++, data++) {
        *data = *ptr;
    }

    return LFS_ERR_OK;
}

//******************************************************************************
int flash_write(const struct lfs_config *c, lfs_block_t block, lfs_off_t off, const void *buffer,
                lfs_size_t size)
{
    uint32_t first_block = *(uint32_t *)c->context;

    // Get starting address of the write
    uint32_t startaddr = MXC_FLASH_PAGE_ADDR((first_block + block)) + off;
    uint32_t *data = (uint32_t *)buffer;

    // Write data to flash 4 bytes at a time
    return flash_write4(startaddr, size / c->prog_size, data, FALSE);
}

//******************************************************************************
int flash_erase(const struct lfs_config *c, lfs_block_t block)
{
    uint32_t first_block = *(uint32_t *)c->context;

    // Get address of filesystem block
    int addr = MXC_FLASH_PAGE_ADDR((first_block + block));
    LOGF("Erasing page at address %08x\n", addr);

    // Erase filesystem block
    int error_status = MXC_FLC_PageErase(addr);
    if (error_status != E_NO_ERROR) {
        return error_status;
    }
    return LFS_ERR_OK;
}

//******************************************************************************
int flash_sync(const struct lfs_config *c)
{
    // Not provided by the SDK
    return LFS_ERR_OK;
}

//******************************************************************************
int flash_verify(uint32_t address, uint32_t length, uint8_t *data)
{
    volatile uint8_t *ptr;

    // Scan through section of flash and check if it matches the data buffer
    for (ptr = (uint8_t *)address; ptr < (uint8_t *)(address + length); ptr++, data++) {
        if (*ptr != *data) {
            printf("Verify failed at 0x%x (0x%x != 0x%x)\n", (unsigned int)ptr, (unsigned int)*ptr,
                   (unsigned int)*data);
            return E_UNKNOWN;
        }
    }

    return E_NO_ERROR;
}

//******************************************************************************
int check_mem(uint32_t startaddr, uint32_t length, uint32_t data)
{
    uint32_t *ptr;

    // Scan section of flash to see if it matches the expected value
    for (ptr = (uint32_t *)startaddr; ptr < (uint32_t *)(startaddr + length); ptr++) {
        if (*ptr != data) {
            return 0;
        }
    }

    return 1;
}

//******************************************************************************
int check_erased(uint32_t startaddr, uint32_t length)
{
    // Scan through section of flash to see if it matches the erased value (0xFFFFFFFF)
    return check_mem(startaddr, length, 0xFFFFFFFF);
}

//******************************************************************************
int flash_write4(uint32_t startaddr, uint32_t length, uint32_t *data, bool verify)
{
    int i = 0;

    MXC_ICC_Disable(MXC_ICC0);

    // Write data to flash 4 bytes at a time
    for (uint32_t testaddr = startaddr; i < length; testaddr += 4) {
        // Write a word
        int error_status = MXC_FLC_Write(testaddr, 4, &data[i]);
        if (error_status != E_NO_ERROR) {
            printf("Failure in writing a word : error %i addr: 0x%08x\n", error_status, testaddr);
            return error_status;
        } else {
            LOGF("Word %u is written to the flash at addr 0x%08x\n", data[i], testaddr);
        }

        if (verify) {
            // Verify that word is written properly
            if (flash_verify(testaddr, 4, (uint8_t *)&data[i]) != E_NO_ERROR) {
                printf("Word is not written properly.\n");
                return E_UNKNOWN;
            }
        }
        i++;
    }

    MXC_ICC_Enable(MXC_ICC0);

    return E_NO_ERROR;
}
