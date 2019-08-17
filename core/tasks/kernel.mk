# Copyright (C) 2012 The CyanogenMod Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Android makefile to build kernel as a part of Android Build
#
# Configuration
# =============
#
# These config vars are usually set in BoardConfig.mk:
#
#   TARGET_KERNEL_SOURCE               = Kernel source dir, optional, defaults
#                                        to kernel/$(TARGET_DEVICE_DIR)
#   TARGET_KERNEL_CONFIG               = Kernel defconfig
#   TARGET_KERNEL_VARIANT_CONFIG       = Variant defconfig, optional
#   TARGET_KERNEL_SELINUX_CONFIG       = SELinux defconfig, optional
#   TARGET_KERNEL_ADDITIONAL_CONFIG    = Additional defconfig, optional
#   TARGET_KERNEL_ARCH                 = Kernel Arch
#   TARGET_KERNEL_HEADER_ARCH          = Optional Arch for kernel headers if
#                                          different from TARGET_KERNEL_ARCH
#   TARGET_KERNEL_CROSS_COMPILE_PREFIX = Compiler prefix (e.g. arm-eabi-)
#                                          defaults to arm-linux-androidkernel- for arm
#                                                      aarch64-linux-androidkernel- for arm64
#                                                      x86_64-linux-androidkernel- for x86
#
#   BOARD_KERNEL_IMAGE_NAME            = Built image name
#                                          for ARM use: zImage
#                                          for ARM64 use: Image.gz
#                                          for uncompressed use: Image
#                                          If using an appended DT, append '-dtb'
#                                          to the end of the image name.
#                                          For example, for ARM devices,
#                                          use zImage-dtb instead of zImage.
#
#   KERNEL_TOOLCHAIN_PREFIX            = Overrides TARGET_KERNEL_CROSS_COMPILE_PREFIX,
#                                          Set this var in shell to override
#                                          toolchain specified in BoardConfig.mk
#   KERNEL_TOOLCHAIN                   = Path to toolchain, if unset, assumes
#                                          TARGET_KERNEL_CROSS_COMPILE_PREFIX
#                                          is in PATH
#   USE_CCACHE                         = Enable ccache (global Android flag)
#
#   NEED_KERNEL_MODULE_ROOT            = Optional, if true, install kernel
#                                          modules in root instead of system


TARGET_AUTO_KDIR := $(shell echo $(TARGET_DEVICE_DIR) | sed -e 's/^device/kernel/g')

## Externally influenced variables
# kernel location - optional, defaults to kernel/<vendor>/<device>
TARGET_KERNEL_SOURCE ?= $(TARGET_AUTO_KDIR)
KERNEL_SRC := $(TARGET_KERNEL_SOURCE)
# kernel configuration - mandatory
KERNEL_DEFCONFIG := $(TARGET_KERNEL_CONFIG)
VARIANT_DEFCONFIG := $(TARGET_KERNEL_VARIANT_CONFIG)
SELINUX_DEFCONFIG := $(TARGET_KERNEL_SELINUX_CONFIG)

## Internal variables
KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config
KERNEL_OUT_STAMP := $(KERNEL_OUT)/.mkdir_stamp

TARGET_KERNEL_ARCH := $(strip $(TARGET_KERNEL_ARCH))
ifeq ($(TARGET_KERNEL_ARCH),)
KERNEL_ARCH := $(TARGET_ARCH)
else
KERNEL_ARCH := $(TARGET_KERNEL_ARCH)
endif

ifeq ($(KERNEL_ARCH),x86_64)
KERNEL_DEFCONFIG_ARCH := x86
else
KERNEL_DEFCONFIG_ARCH := $(KERNEL_ARCH)
endif
KERNEL_DEFCONFIG_SRC := $(KERNEL_SRC)/arch/$(KERNEL_DEFCONFIG_ARCH)/configs/$(KERNEL_DEFCONFIG)

TARGET_KERNEL_HEADER_ARCH := $(strip $(TARGET_KERNEL_HEADER_ARCH))
ifeq ($(TARGET_KERNEL_HEADER_ARCH),)
KERNEL_HEADER_ARCH := $(KERNEL_ARCH)
else
KERNEL_HEADER_ARCH := $(TARGET_KERNEL_HEADER_ARCH)
endif

KERNEL_HEADER_DEFCONFIG := $(strip $(KERNEL_HEADER_DEFCONFIG))
ifeq ($(KERNEL_HEADER_DEFCONFIG),)
KERNEL_HEADER_DEFCONFIG := $(KERNEL_DEFCONFIG)
endif

ifeq ($(BOARD_KERNEL_IMAGE_NAME),)
$(error BOARD_KERNEL_IMAGE_NAME not defined.)
endif
ifneq ($(TARGET_USES_UNCOMPRESSED_KERNEL),)
$(error TARGET_USES_UNCOMPRESSED_KERNEL is deprecated.)
endif
ifneq ($(TARGET_KERNEL_APPEND_DTB),)
$(error TARGET_KERNEL_APPEND_DTB is deprecated.)
endif
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/$(BOARD_KERNEL_IMAGE_NAME)

# Clear this first to prevent accidental poisoning from env
MAKE_FLAGS :=

ifeq ($(KERNEL_ARCH),arm64)
  # Avoid "unsupported RELA relocation: 311" errors (R_AARCH64_ADR_GOT_PAGE)
  MAKE_FLAGS += CFLAGS_MODULE="-fno-pic"
  ifeq ($(TARGET_ARCH),arm)
    KERNEL_CONFIG_OVERRIDE := CONFIG_ANDROID_BINDER_IPC_32BIT=y
  endif
endif

ifneq ($(TARGET_KERNEL_ADDITIONAL_CONFIG),)
KERNEL_ADDITIONAL_CONFIG := $(TARGET_KERNEL_ADDITIONAL_CONFIG)
KERNEL_ADDITIONAL_CONFIG_SRC := $(KERNEL_SRC)/arch/$(KERNEL_ARCH)/configs/$(KERNEL_ADDITIONAL_CONFIG)
    ifeq ("$(wildcard $(KERNEL_ADDITIONAL_CONFIG_SRC))","")
        $(warning TARGET_KERNEL_ADDITIONAL_CONFIG '$(TARGET_KERNEL_ADDITIONAL_CONFIG)' doesn't exist)
        KERNEL_ADDITIONAL_CONFIG_SRC := /dev/null
    endif
else
    KERNEL_ADDITIONAL_CONFIG_SRC := /dev/null
endif

## Do be discontinued in a future version. Notify builder about target
## kernel format requirement
ifeq ($(BOARD_KERNEL_IMAGE_NAME),)
ifeq ($(BOARD_USES_UBOOT),true)
        $(error "Please set BOARD_KERNEL_IMAGE_NAME to uImage")
else ifeq ($(BOARD_USES_UNCOMPRESSED_BOOT),true)
        $(error "Please set BOARD_KERNEL_IMAGE_NAME to Image")
endif
endif

ifeq "$(wildcard $(KERNEL_SRC) )" ""
    ifneq ($(TARGET_PREBUILT_KERNEL),)
        HAS_PREBUILT_KERNEL := true
        NEEDS_KERNEL_COPY := true
    else
        $(foreach cf,$(PRODUCT_COPY_FILES), \
            $(eval _src := $(call word-colon,1,$(cf))) \
            $(eval _dest := $(call word-colon,2,$(cf))) \
            $(ifeq kernel,$(_dest), \
                $(eval HAS_PREBUILT_KERNEL := true)))
    endif

    ifneq ($(HAS_PREBUILT_KERNEL),)
        $(warning ***************************************************************)
        $(warning * Using prebuilt kernel binary instead of source              *)
        $(warning * THIS IS DEPRECATED, AND WILL BE DISCONTINUED                *)
        $(warning * Please configure your device to download the kernel         *)
        $(warning * source repository to $(KERNEL_SRC))
        $(warning * See http://wiki.cyanogenmod.org/w/Doc:_integrated_kernel_building)
        $(warning * for more information                                        *)
        $(warning ***************************************************************)
        FULL_KERNEL_BUILD := false
        KERNEL_BIN := $(TARGET_PREBUILT_KERNEL)
    else
        $(warning ***************************************************************)
        $(warning *                                                             *)
        $(warning * No kernel source found, and no fallback prebuilt defined.   *)
        $(warning * Please make sure your device is properly configured to      *)
        $(warning * download the kernel repository to $(KERNEL_SRC))
        $(warning * and add the TARGET_KERNEL_CONFIG variable to BoardConfig.mk *)
        $(warning *                                                             *)
        $(warning * As an alternative, define the TARGET_PREBUILT_KERNEL        *)
        $(warning * variable with the path to the prebuilt binary kernel image  *)
        $(warning * in your BoardConfig.mk file                                 *)
        $(warning *                                                             *)
        $(warning ***************************************************************)
        $(error "NO KERNEL")
    endif
else
    NEEDS_KERNEL_COPY := true
    ifeq ($(TARGET_KERNEL_CONFIG),)
        $(warning **********************************************************)
        $(warning * Kernel source found, but no configuration was defined  *)
        $(warning * Please add the TARGET_KERNEL_CONFIG variable to your   *)
        $(warning * BoardConfig.mk file                                    *)
        $(warning **********************************************************)
        # $(error "NO KERNEL CONFIG")
    else
        #$(info Kernel source found, building it)
        FULL_KERNEL_BUILD := true
        KERNEL_BIN := $(TARGET_PREBUILT_INT_KERNEL)
    endif
endif

ifeq ($(FULL_KERNEL_BUILD),true)

KERNEL_HEADERS_INSTALL := $(KERNEL_OUT)/usr
KERNEL_HEADERS_INSTALL_STAMP := $(KERNEL_OUT)/.headers_install_stamp

ifeq ($(NEED_KERNEL_MODULE_ROOT),true)
KERNEL_MODULES_INSTALL := root
KERNEL_MODULES_OUT := $(TARGET_ROOT_OUT)/lib/modules
else
KERNEL_MODULES_INSTALL := system
KERNEL_MODULES_OUT := $(TARGET_OUT)/lib/modules
endif

TARGET_KERNEL_CROSS_COMPILE_PREFIX := $(strip $(TARGET_KERNEL_CROSS_COMPILE_PREFIX))
ifneq ($(TARGET_KERNEL_CROSS_COMPILE_PREFIX),)
KERNEL_TOOLCHAIN_PREFIX ?= $(TARGET_KERNEL_CROSS_COMPILE_PREFIX)
else ifeq ($(KERNEL_ARCH),arm64)
KERNEL_TOOLCHAIN_PREFIX ?= aarch64-linux-androidkernel-
else ifeq ($(KERNEL_ARCH),arm)
KERNEL_TOOLCHAIN_PREFIX ?= arm-linux-androidkernel-
else ifeq ($(KERNEL_ARCH),x86)
KERNEL_TOOLCHAIN_PREFIX ?= x86_64-linux-androidkernel-
endif

ifeq ($(KERNEL_TOOLCHAIN),)
KERNEL_TOOLCHAIN_PATH := $(KERNEL_TOOLCHAIN_PREFIX)
else
ifneq ($(KERNEL_TOOLCHAIN_PREFIX),)
KERNEL_TOOLCHAIN_PATH := $(KERNEL_TOOLCHAIN)/$(KERNEL_TOOLCHAIN_PREFIX)
endif
endif

ifneq ($(USE_CCACHE),)
    # Detect if the system already has ccache installed to use instead of the prebuilt
    _ccache := $(shell which ccache)

    ifeq ($(_ccache),)
        _ccache := $(ANDROID_BUILD_TOP)/prebuilts/misc/$(HOST_PREBUILT_TAG)/ccache/ccache
        # Check that the executable is here.
        _ccache := $(strip $(wildcard $(_ccache)))
    endif
endif

KERNEL_CROSS_COMPILE := CROSS_COMPILE="$(_ccache) $(KERNEL_TOOLCHAIN_PATH)"
_ccache =

define mv-modules
    mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.order`;\
    if [ "$$mdpath" != "" ];then\
        mpath=`dirname $$mdpath`;\
        ko=`find $$mpath/kernel -type f -name *.ko`;\
        for i in $$ko; do $(KERNEL_TOOLCHAIN_PATH)strip --strip-unneeded $$i;\
        mv $$i $(KERNEL_MODULES_OUT)/; done;\
    fi
endef

define clean-module-folder
    mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.order`;\
    if [ "$$mdpath" != "" ];then\
        mpath=`dirname $$mdpath`; rm -rf $$mpath;\
    fi
endef

ifeq ($(HOST_OS),darwin)
  MAKE_FLAGS += C_INCLUDE_PATH=$(ANDROID_BUILD_TOP)/external/elfutils/libelf/
endif

PATH_OVERRIDE := PATH=$(shell cat $(OUT_DIR)/.path_interposer_origpath):$$PATH

ifeq ($(TARGET_KERNEL_MODULES),)
    TARGET_KERNEL_MODULES := $(KERNEL_OUT)/.no_external_modules
endif

$(KERNEL_OUT_STAMP):
	$(hide) mkdir -p $(KERNEL_OUT)
	$(hide) rm -rf $(KERNEL_MODULES_OUT)
	$(hide) mkdir -p $(KERNEL_MODULES_OUT)
	$(hide) touch $@

KERNEL_ADDITIONAL_CONFIG_OUT := $(KERNEL_OUT)/.additional_config

$(KERNEL_ADDITIONAL_CONFIG_OUT):
	$(hide) cmp -s $(KERNEL_ADDITIONAL_CONFIG_SRC) $@ || cp $(KERNEL_ADDITIONAL_CONFIG_SRC) $@;

$(KERNEL_CONFIG): $(KERNEL_OUT_STAMP) $(KERNEL_DEFCONFIG_SRC) $(KERNEL_ADDITIONAL_CONFIG_OUT)
	$(hide) echo -e ${CL_GRN}"Building Kernel Config"${CL_RST}
	$(PATH_OVERRIDE) $(MAKE_PREBUILT) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) VARIANT_DEFCONFIG=$(VARIANT_DEFCONFIG) SELINUX_DEFCONFIG=$(SELINUX_DEFCONFIG) $(KERNEL_DEFCONFIG)
	$(hide) if [ ! -z "$(KERNEL_CONFIG_OVERRIDE)" ]; then \
			echo "Overriding kernel config with '$(KERNEL_CONFIG_OVERRIDE)'"; \
			echo $(KERNEL_CONFIG_OVERRIDE) >> $(KERNEL_OUT)/.config; \
			$(PATH_OVERRIDE) $(MAKE_PREBUILT) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) oldconfig; fi
	# Create defconfig build artifact
	$(hide) $(PATH_OVERRIDE) $(MAKE_PREBUILT) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) savedefconfig
	$(hide) if [ ! -z "$(KERNEL_ADDITIONAL_CONFIG)" ]; then \
			echo "Using additional config '$(KERNEL_ADDITIONAL_CONFIG)'"; \
			$(KERNEL_SRC)/scripts/kconfig/merge_config.sh -m -O $(KERNEL_OUT) $(KERNEL_OUT)/.config $(KERNEL_SRC)/arch/$(KERNEL_ARCH)/configs/$(KERNEL_ADDITIONAL_CONFIG); \
			$(PATH_OVERRIDE) $(MAKE_PREBUILT) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) KCONFIG_ALLCONFIG=$(KERNEL_OUT)/.config alldefconfig; fi

TARGET_KERNEL_BINARIES := $(KERNEL_OUT)/.kernel_binaries
$(TARGET_KERNEL_BINARIES): $(KERNEL_OUT_STAMP) $(KERNEL_CONFIG) $(KERNEL_HEADERS_INSTALL_STAMP)
	$(hide) echo "Building Kernel"
	$(PATH_OVERRIDE) $(MAKE_PREBUILT) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(BOARD_KERNEL_IMAGE_NAME)
	$(hide) if grep -q 'CONFIG_OF=y' $(KERNEL_CONFIG) ; \
			then \
				echo -e ${CL_GRN}"Building DTBs"${CL_RST} ; \
				$(PATH_OVERRIDE) $(MAKE_PREBUILT) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) dtbs ; \
			else \
				echo "DTBs not enabled" ; \
			fi ;
	$(hide) if grep -q 'CONFIG_MODULES=y' $(KERNEL_CONFIG) ; \
			then \
				echo -e ${CL_GRN}"Building Kernel Modules"${CL_RST} ; \
				$(PATH_OVERRIDE) $(MAKE_PREBUILT) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) modules && \
				$(PATH_OVERRIDE) $(MAKE_PREBUILT) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) INSTALL_MOD_PATH=../../$(KERNEL_MODULES_INSTALL) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) modules_install && \
				$(mv-modules) && \
				$(clean-module-folder) ; \
			else \
				echo "Kernel Modules not enabled" ; \
			fi ;


$(TARGET_KERNEL_MODULES): $(TARGET_KERNEL_BINARIES)

$(TARGET_PREBUILT_INT_KERNEL): $(TARGET_KERNEL_MODULES)
	$(mv-modules)
	$(clean-module-folder)

$(KERNEL_HEADERS_INSTALL_STAMP): $(KERNEL_OUT_STAMP) $(KERNEL_CONFIG)
	$(hide) echo -e ${CL_GRN}"Building Kernel Headers"${CL_RST}
	$(hide) if [ ! -z "$(KERNEL_HEADER_DEFCONFIG)" ]; then \
			$(hide) rm -f ../$(KERNEL_CONFIG); \
			$(PATH_OVERRIDE) $(MAKE_PREBUILT) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_HEADER_ARCH) $(KERNEL_CROSS_COMPILE) VARIANT_DEFCONFIG=$(VARIANT_DEFCONFIG) SELINUX_DEFCONFIG=$(SELINUX_DEFCONFIG) $(KERNEL_HEADER_DEFCONFIG); \
			$(PATH_OVERRIDE) $(MAKE_PREBUILT) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_HEADER_ARCH) $(KERNEL_CROSS_COMPILE) headers_install; fi
	$(hide) if [ "$(KERNEL_HEADER_DEFCONFIG)" != "$(KERNEL_DEFCONFIG)" ]; then \
			echo "Used a different defconfig for header generation"; \
			$(hide) rm -f ../$(KERNEL_CONFIG); \
			$(PATH_OVERRIDE) $(MAKE_PREBUILT) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) VARIANT_DEFCONFIG=$(VARIANT_DEFCONFIG) SELINUX_DEFCONFIG=$(SELINUX_DEFCONFIG) $(KERNEL_DEFCONFIG); fi
	$(hide) if [ ! -z "$(KERNEL_CONFIG_OVERRIDE)" ]; then \
			echo "Overriding kernel config with '$(KERNEL_CONFIG_OVERRIDE)'"; \
			echo $(KERNEL_CONFIG_OVERRIDE) >> $(KERNEL_OUT)/.config; \
			$(PATH_OVERRIDE) $(MAKE_PREBUILT) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) oldconfig; fi
	$(hide) if [ ! -z "$(KERNEL_ADDITIONAL_CONFIG)" ]; then \
			echo "Using additional config '$(KERNEL_ADDITIONAL_CONFIG)'"; \
			$(KERNEL_SRC)/scripts/kconfig/merge_config.sh -m -O $(KERNEL_OUT) $(KERNEL_OUT)/.config $(KERNEL_SRC)/arch/$(KERNEL_ARCH)/configs/$(KERNEL_ADDITIONAL_CONFIG); \
			$(PATH_OVERRIDE) $(MAKE_PREBUILT) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) KCONFIG_ALLCONFIG=$(KERNEL_OUT)/.config alldefconfig; fi
	$(hide) touch $@

# provide this rule because there are dependencies on this throughout the repo
$(KERNEL_HEADERS_INSTALL): $(KERNEL_HEADERS_INSTALL_STAMP)

.PHONY: kerneltags
kerneltags: $(KERNEL_OUT_STAMP) $(KERNEL_CONFIG)
	$(PATH_OVERRIDE) $(MAKE_PREBUILT) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) tags

.PHONY: kernelconfig
kernelconfig:  KERNELCONFIG_MODE := menuconfig

.PHONY: kernelxconfig
kernelxconfig: KERNELCONFIG_MODE := xconfig

.PHONY: kernelxconfig kernelconfig
kernelxconfig kernelconfig: $(KERNEL_OUT_STAMP)
	$(MAKE_PREBUILT) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_DEFCONFIG)
	env KCONFIG_NOTIMESTAMP=true \
		 $(MAKE_PREBUILT) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNELCONFIG_MODE)
	env KCONFIG_NOTIMESTAMP=true \
		 $(MAKE_PREBUILT) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) savedefconfig
	cp $(KERNEL_OUT)/defconfig $(KERNEL_DEFCONFIG_SRC)

.PHONY: alldefconfig
alldefconfig: $(KERNEL_OUT_STAMP)
	env KCONFIG_NOTIMESTAMP=true \
		 $(PATH_OVERRIDE) $(MAKE_PREBUILT) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) alldefconfig

endif # FULL_KERNEL_BUILD

## Install it

ifeq ($(NEEDS_KERNEL_COPY),true)
file := $(INSTALLED_KERNEL_TARGET)
ALL_PREBUILT += $(file)
$(file) : $(KERNEL_BIN) | $(ACP)
	$(transform-prebuilt-to-target)

ALL_PREBUILT += $(INSTALLED_KERNEL_TARGET)
endif

.PHONY: kernel
kernel: $(INSTALLED_KERNEL_TARGET)
