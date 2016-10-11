# uboot-extlinux-config.bbclass
#
# This class allow the extlinux.conf generation for U-Boot use. The
# U-Boot support for it is given to allow the Generic Distribution
# Configuration specification use by OpenEmbedded-based products.
#
# External variables:
#
# UBOOT_EXTLINUX_CONSOLE           - Set to "console=ttyX" to change kernel boot
#                                    default console.
# UBOOT_EXTLINUX_LABELS            - A list of targets for the automatic config.
# UBOOT_EXTLINUX_KERNEL_ARGS       - Add additional kernel arguments.
# UBOOT_EXTLINUX_KERNEL_IMAGE      - Kernel image name.
# UBOOT_EXTLINUX_FDTDIR            - Device tree directory.
# UBOOT_EXTLINUX_INITRD            - Indicates a list of filesystem images to
#                                    concatenate and use as an initrd (optional).
# UBOOT_EXTLINUX_MENU_DESCRIPTION  - Name to use as description.
# UBOOT_EXTLINUX_ROOT              - Root kernel cmdline.
#
# If there's only one label system will boot automatically and menu won't be
# created. If you want to use more than one labels, e.g linux and alternate,
# use overrides to set menu description, console and others variables.
#
# Ex:
#
# UBOOT_EXTLINUX_LABELS ??= "default fallback"
#
# UBOOT_EXTLINUX_KERNEL_IMAGE_default ??= "../zImage"
# UBOOT_EXTLINUX_MENU_DESCRIPTION_default ??= "Linux Default"
#
# UBOOT_EXTLINUX_KERNEL_IMAGE_fallback ??= "../zImage-fallback"
# UBOOT_EXTLINUX_MENU_DESCRIPTION_fallback ??= "Linux Fallback"
#
# Results:
#
# menu title Select the boot mode
# LABEL Linux Default
#   KERNEL ../zImage
#   FDTDIR ../
#   APPEND root=/dev/mmcblk2p2 rootwait rw console=${console}
# LABEL Linux Fallback
#   KERNEL ../zImage-fallback
#   FDTDIR ../
#   APPEND root=/dev/mmcblk2p2 rootwait rw console=${console}
#
# Copyright (C) 2016, O.S. Systems Software LTDA.  All Rights Reserved
# Released under the MIT license (see packages/COPYING)
#
# The kernel has an internal default console, which you can override with
# a console=...some_tty...
UBOOT_EXTLINUX_CONSOLE ??= "console=${console}"
UBOOT_EXTLINUX_LABELS ??= "linux"
UBOOT_EXTLINUX_FDTDIR ??= "../"
UBOOT_EXTLINUX_KERNEL_IMAGE ??= "../${KERNEL_IMAGETYPE}"
UBOOT_EXTLINUX_KERNEL_ARGS ??= "rootwait rw"
UBOOT_EXTLINUX_MENU_DESCRIPTION_linux ??= "${DISTRO_NAME}"

UBOOT_EXTLINUX_CONFIG = "${B}/extlinux.conf"

python create_extlinux_config() {
    if d.getVar("UBOOT_EXTLINUX", True) != "1":
      return

    if not d.getVar('WORKDIR', True):
        bb.error("WORKDIR not defined, unable to package")

    labels = d.getVar('UBOOT_EXTLINUX_LABELS', True)
    if not labels:
        bb.fatal("UBOOT_EXTLINUX_LABELS not defined, nothing to do")

    if not labels.strip():
        bb.fatal("No labels, nothing to do")

    cfile = d.getVar('UBOOT_EXTLINUX_CONFIG', True)
    if not cfile:
        bb.fatal('Unable to read UBOOT_EXTLINUX_CONFIG')

    try:
        with open(cfile, 'w') as cfgfile:
            cfgfile.write('# Generic Distro Configuration file generated by OpenEmbedded\n')

            if len(labels.split()) > 1:
                cfgfile.write('menu title Select the boot mode\n')

            for label in labels.split():
                localdata = bb.data.createCopy(d)

                overrides = localdata.getVar('OVERRIDES', True)
                if not overrides:
                    bb.fatal('OVERRIDES not defined')

                localdata.setVar('OVERRIDES', label + ':' + overrides)
                bb.data.update_data(localdata)

                extlinux_console = localdata.getVar('UBOOT_EXTLINUX_CONSOLE', True)

                menu_description = localdata.getVar('UBOOT_EXTLINUX_MENU_DESCRIPTION', True)
                if not menu_description:
                    menu_description = label

                root = localdata.getVar('UBOOT_EXTLINUX_ROOT', True)
                if not root:
                    bb.fatal('UBOOT_EXTLINUX_ROOT not defined')

                kernel_image = localdata.getVar('UBOOT_EXTLINUX_KERNEL_IMAGE', True)
                fdtdir = localdata.getVar('UBOOT_EXTLINUX_FDTDIR', True)
                if fdtdir:
                    cfgfile.write('LABEL %s\n\tKERNEL %s\n\tFDTDIR %s\n' %
                                 (menu_description, kernel_image, fdtdir))
                else:
                    cfgfile.write('LABEL %s\n\tKERNEL %s\n' % (menu_description, kernel_image))

                kernel_args = localdata.getVar('UBOOT_EXTLINUX_KERNEL_ARGS', True)

                initrd = localdata.getVar('UBOOT_EXTLINUX_INITRD', True)
                if initrd:
                    cfgfile.write('\tINITRD %s\n'% initrd)

                kernel_args = root + " " + kernel_args
                cfgfile.write('\tAPPEND %s %s\n' % (kernel_args, extlinux_console))

    except OSError:
        bb.fatal('Unable to open %s' % (cfile))
}

do_install[prefuncs] += "create_extlinux_config"