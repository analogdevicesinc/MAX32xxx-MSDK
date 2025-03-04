###############################################################################
 #
 # Copyright (C) 2022-2023 Maxim Integrated Products, Inc. (now owned by
 # Analog Devices, Inc.),
 # Copyright (C) 2023-2024 Analog Devices, Inc.
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #
 ##############################################################################

################################################################################
# This file can be included in a project makefile to build the library for the 
# project.
################################################################################

ifeq "$(PERIPH_DRIVER_DIR)" ""
# If PERIPH_DRIVER_DIR is not specified, this Makefile will locate itself.
PERIPH_DRIVER_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
endif

TARGET_UC ?= $(subst m,M,$(subst a,A,$(subst x,X,$(TARGET))))
TARGET_LC ?= $(subst M,m,$(subst A,a,$(subst X,x,$(TARGET))))

# Specify the library variant.
ifeq "$(MFLOAT_ABI)" "hardfp"
PD_LIBRARY_VARIANT=hardfp
else
ifeq "$(MFLOAT_ABI)" "hard"
PD_LIBRARY_VARIANT=hardfp
else
PD_LIBRARY_VARIANT=softfp
endif
endif

MXC_SPI_VERSION ?= v1
# Selects the SPI drivers to build with.  Acceptable values are:
# - v1
# - v2
ifneq "$(MXC_SPI_VERSION)" ""
PD_LIBRARY_VARIANT := spi-$(MXC_SPI_VERSION)_$(PD_LIBRARY_VARIANT)
endif
ifeq "$(MXC_SPI_VERSION)" "v1"
PROJ_CFLAGS+=-DMXC_SPI_V1
else
ifeq "$(MXC_SPI_VERSION)" "v2"
PROJ_CFLAGS+=-DMXC_SPI_V2
else
$(error Invalid value for MXC_SPI_VERSION = "$(MXC_SPI_VERSION)"  Acceptable values are "v1" or "v2")
endif
endif


# Specify the build directory if not defined by the project
ifeq "$(BUILD_DIR)" ""
ifeq "$(RISCV_CORE)" ""
PERIPH_DRIVER_BUILD_DIR=${PERIPH_DRIVER_DIR}/bin/$(TARGET_UC)/$(PD_LIBRARY_VARIANT)
else
PERIPH_DRIVER_BUILD_DIR=${PERIPH_DRIVER_DIR}/bin/$(TARGET_UC)/$(PD_LIBRARY_VARIANT)_riscv
endif
else
PERIPH_DRIVER_BUILD_DIR=$(BUILD_DIR)/PeriphDriver
endif

# Export other variables needed by the peripheral driver makefile
export TARGET
export COMPILER
# export TARGET_MAKEFILE
# export PROJ_CFLAGS
# export PROJ_LDFLAGS
# export MXC_OPTIMIZE_CFLAGS
# export DUAL_CORE
# export RISCV_CORE
# export RISCV_LOAD
# export MFLOAT_ABI

include ${PERIPH_DRIVER_DIR}/$(TARGET_LC)_files.mk
IPATH += ${PERIPH_DRIVER_INCLUDE_DIR}
ifeq "$(PD_LIBRARY_VARIANT)" ""
PERIPH_DRIVER_LIB_FILENAME := libPeriphDriver
else
PERIPH_DRIVER_LIB_FILENAME := libPeriphDriver_$(PD_LIBRARY_VARIANT)
endif
PERIPH_DRIVER_LIB := $(PERIPH_DRIVER_LIB_FILENAME).a
# export PERIPH_DRIVER_DIR
export PERIPH_DRIVER_LIB
export PERIPH_DRIVER_BUILD_DIR

# Add to library list
LIBS += ${PERIPH_DRIVER_BUILD_DIR}/${PERIPH_DRIVER_LIB}
# Add rule to build the Driver Library
${PERIPH_DRIVER_BUILD_DIR}/${PERIPH_DRIVER_LIB}: ${PERIPH_DRIVER_C_FILES} ${PERIPH_DRIVER_A_FILES} ${PROJECTMK}
	@$(MAKE) -f ${PERIPH_DRIVER_DIR}/libPeriphDriver.mk  lib BUILD_DIR=${PERIPH_DRIVER_BUILD_DIR} PROJ_CFLAGS="$(PROJ_CFLAGS)" PROJ_LDFLAGS="$(PROJ_LDFLAGS)" MXC_OPTIMIZE_CFLAGS=$(MXC_OPTIMIZE_CFLAGS) IPATH="$(IPATH)" MFLOAT_ABI=$(MFLOAT_ABI) DUAL_CORE=$(DUAL_CORE) RISCV_CORE=$(RISCV_CORE) PROJECTMK=$(PROJECTMK) PERIPH_DRIVER_LIB_FILENAME=$(PERIPH_DRIVER_LIB_FILENAME)

clean.periph:
	@$(MAKE) -f ${PERIPH_DRIVER_DIR}/libPeriphDriver.mk BUILD_DIR=${PERIPH_DRIVER_BUILD_DIR} PERIPH_DRIVER_LIB_FILENAME=$(PERIPH_DRIVER_LIB_FILENAME) clean

query.periphdrivers:
	@$(MAKE) -f ${PERIPH_DRIVER_DIR}/libPeriphDriver.mk query QUERY_VAR="${QUERY_VAR}"