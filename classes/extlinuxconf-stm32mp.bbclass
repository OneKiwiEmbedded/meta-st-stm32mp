# Copyright (C) 2017, STMicroelectronics - All Rights Reserved
# Released under the MIT license (see COPYING.MIT for the terms)
#
# --------------------------------------------------------------------
# Extract from openembedded-core 'uboot-extlinux-config.bbclass' class
# --------------------------------------------------------------------
# External variables:
#
# UBOOT_EXTLINUX_CONSOLE           - Set to "console=ttyX" to change kernel boot
#                                    default console.
# UBOOT_EXTLINUX_LABELS            - A list of targets for the automatic config.
# UBOOT_EXTLINUX_KERNEL_ARGS       - Add additional kernel arguments.
# UBOOT_EXTLINUX_KERNEL_IMAGE      - Kernel image name.
# UBOOT_EXTLINUX_FDTDIR            - Device tree directory.
# UBOOT_EXTLINUX_FDT               - Device tree file.
# UBOOT_EXTLINUX_INITRD            - Indicates a list of filesystem images to
#                                    concatenate and use as an initrd (optional).
# UBOOT_EXTLINUX_MENU_DESCRIPTION  - Name to use as description.
# UBOOT_EXTLINUX_ROOT              - Root kernel cmdline.
# UBOOT_EXTLINUX_TIMEOUT           - Timeout before DEFAULT selection is made.
#                                    Measured in 1/10 of a second.
# UBOOT_EXTLINUX_DEFAULT_LABEL     - Target to be selected by default after
#                                    the timeout period
#
# If there's only one label system will boot automatically and menu won't be
# created. If you want to use more than one labels, e.g linux and alternate,
# use overrides to set menu description, console and others variables.
#
# --------------------------------------------------------------------
# STM32MP specific implementation
# --------------------------------------------------------------------
# Append new mechanism to allow multiple config file generation.
#   - multiple targets case:
#     each config file generated is created under specific path:
#       '${B}/<UBOOT_EXTLINUX_BOOTPREFIXES>extlinux/extlinux.conf'
#   - simple target case:
#     the 'extlinux.conf' file generated is created under default path:
#       '${B}/extlinux/extlinux.conf'
#
# New external variables added:
# UBOOT_EXTLINUX_TARGETS        - List of targets for multi config file creation
# UBOOT_EXTLINUX_BOOTPREFIXES   - Prefix used in uboot script to select config file
#
# Add an extra configuration to allow to duplicate current config file into a new
# one by appending some new labels to the current ones.
# This mechanism is enabled through UBOOT_EXTLINUX_TARGETS_EXTRA_CONFIG var.
# The format to specify it is:
# UBOOT_EXTLINUX_TARGETS_EXTRA_CONFIG ??= "foo"
# UBOOT_EXTLINUX_TARGETS_EXTRA_CONFIG[foo] = "label1 label2"
# Along with current config file created 'extlinux.conf', a new config file is
# created at same location with name 'foo_extlinux.conf'.
# This config file contains the labels defined for current config file with also
# the new configured lables (i.e. label1 and lable2).
#
# --------------------------------------------------------------------
# Implementation:
# --------------------------------------------------------------------
# We create all config file based on a loop for all targets set in
# UBOOT_EXTLINUX_TARGETS var, then we use the mechanism defined in
# 'uboot-extlinux-config.bbclass' class to generate the config file
# Plus for each target we may use the UBOOT_EXTLINUX_TARGETS_EXTRA_CONFIG var
# to create additional config file that will use the labels list from on going
# target plus the labels defined for this extra target.
#
# We manage to allow var override using the current target defined from the
# ongoing loop.
# In the same way var averride is managed through the ongoing label loop while
# writting the config file (refer to 'uboot-extlinux-config.bbclass' class for
# details).
# --------------------------------------------------------------------

UBOOT_EXTLINUX_TARGETS ?= ""

# Configure FIT kernel image for extlinux file creation
UBOOT_EXTLINUX_FIT ??= "0"

UBOOT_EXTLINUX_CONSOLE ??= "console=${console},${baudrate}"
UBOOT_EXTLINUX_LABELS ??= "linux"
UBOOT_EXTLINUX_FDT ??= ""
UBOOT_EXTLINUX_FDTOVERLAYS ??= ""
UBOOT_EXTLINUX_FDTDIR ??= "../"
UBOOT_EXTLINUX_KERNEL_IMAGE ?= "/${KERNEL_IMAGETYPE}"
UBOOT_EXTLINUX_KERNEL_ARGS ?= "rootwait rw"
UBOOT_EXTLINUX_TIMEOUT ?= "20"

def create_extlinux_file(cfile, labels, data):
    """
    Copy/Paste extract of 'do_create_extlinux_config()' function
    from openembedded-core 'uboot-extlinux-config.bbclass' class
    """
    # Use copy of provided data environment to allow label override without side
    # effect when looping on 'create_extlinux_file' function.
    localdata = bb.data.createCopy(data)
    # Default function from OpenEmbedded class
    try:
        with open(cfile, 'w') as cfgfile:
            cfgfile.write('# Generic Distro Configuration file generated by OpenEmbedded\n')

            if len(labels.split()) > 1:
                cfgfile.write('menu title Select the boot mode\n')

            splashscreen_name = localdata.getVar('UBOOT_EXTLINUX_SPLASH')
            if not splashscreen_name:
                bb.warn('UBOOT_EXTLINUX_SPLASH not defined')
            else:
                cfgfile.write('MENU BACKGROUND /%s.bmp\n' % (splashscreen_name))

            timeout =  localdata.getVar('UBOOT_EXTLINUX_TIMEOUT')
            if timeout:
                cfgfile.write('TIMEOUT %s\n' % (timeout))

            if len(labels.split()) > 1:
                default = None
                for label in labels.split():
                    if localdata.getVar('UBOOT_EXTLINUX_DEFAULT_LABEL:%s' % label):
                        default = localdata.getVar('UBOOT_EXTLINUX_DEFAULT_LABEL:%s' % label)
                        break
                if default is None:
                    default = localdata.getVar('UBOOT_EXTLINUX_DEFAULT_LABEL')
                if default:
                    cfgfile.write('DEFAULT %s\n' % (default))

            # Need to deconflict the labels with existing overrides
            label_overrides = labels.split()
            default_overrides = localdata.getVar('OVERRIDES').split(':')
            # We're keeping all the existing overrides that aren't used as a label
            # an override for that label will be added back in while we're processing that label
            keep_overrides = list(filter(lambda x: x not in label_overrides, default_overrides))

            for label in labels.split():

                localdata.setVar('OVERRIDES', ':'.join(keep_overrides + [label]))

                extlinux_console = localdata.getVar('UBOOT_EXTLINUX_CONSOLE')

                menu_description = localdata.getVar('UBOOT_EXTLINUX_MENU_DESCRIPTION')
                if not menu_description:
                    menu_description = label

                root = localdata.getVar('UBOOT_EXTLINUX_ROOT')
                if not root:
                    bb.fatal('UBOOT_EXTLINUX_ROOT not defined')

                kernel_image = localdata.getVar('UBOOT_EXTLINUX_KERNEL_IMAGE')
                fdtdir = localdata.getVar('UBOOT_EXTLINUX_FDTDIR')

                fdt = localdata.getVar('UBOOT_EXTLINUX_FDT')

                fit = localdata.getVar('UBOOT_EXTLINUX_FIT')

                if fit == '1':
                    # Set specific kernel configuration if 'fit' feature is enabled
                    kernel_image = kernel_image + '#conf-' + label + '.dtb'
                    cfgfile.write('LABEL %s\n\tKERNEL %s\n' % (menu_description, kernel_image))
                elif fdt:
                    cfgfile.write('LABEL %s\n\tKERNEL %s\n\tFDT %s\n' %
                                 (menu_description, kernel_image, fdt))
                elif fdtdir:
                    cfgfile.write('LABEL %s\n\tKERNEL %s\n\tFDTDIR %s\n' %
                                 (menu_description, kernel_image, fdtdir))
                else:
                    cfgfile.write('LABEL %s\n\tKERNEL %s\n' % (menu_description, kernel_image))

                kernel_args = localdata.getVar('UBOOT_EXTLINUX_KERNEL_ARGS')

                fdtoverlay = localdata.getVar('UBOOT_EXTLINUX_FDTOVERLAYS')
                if fdtoverlay:
                    cfgfile.write('\tFDTOVERLAYS %s\n'% fdtoverlay)

                initrd = localdata.getVar('UBOOT_EXTLINUX_INITRD')
                if initrd:
                    cfgfile.write('\tINITRD %s\n'% initrd)

                kernel_args = root + " " + kernel_args
                cfgfile.write('\tAPPEND %s %s\n' % (kernel_args, extlinux_console))

    except OSError:
        bb.fatal('Unable to open %s' % (cfile))


python do_create_multiextlinux_config() {
    targets = d.getVar('UBOOT_EXTLINUX_TARGETS')
    if not targets:
        bb.fatal("UBOOT_EXTLINUX_TARGETS not defined, nothing to do")
    if not targets.strip():
        bb.fatal("No targets, nothing to do")

    # Need to deconflict the targets with existing overrides
    target_overrides = targets.split()
    default_overrides = d.getVar('OVERRIDES').split(':')
    # We're keeping all the existing overrides that aren't used as a target
    # an override for that target will be added back in while we're processing that target
    keep_overrides = list(filter(lambda x: x not in target_overrides, default_overrides))

    # Init FIT parameter
    fit_config = d.getVar('UBOOT_EXTLINUX_FIT')

    for target in targets.split():
        bb.note("Loop for '%s' target" % target)

        # Append target as OVERRIDES
        d.setVar('OVERRIDES', ':'.join(keep_overrides + [target]))

        # Initialize labels
        labels = d.getVar('UBOOT_EXTLINUX_LABELS')
        if not labels:
            bb.fatal("UBOOT_EXTLINUX_LABELS not defined, nothing to do")
        if not labels.strip():
            bb.fatal("No labels, nothing to do")

        # Initialize extra target configs
        extra_extlinuxtargetconfig = d.getVar('UBOOT_EXTLINUX_TARGETS_EXTRA_CONFIG') or ""

        # Initialize subdir for config file location
        if len(targets.split()) > 1 or len(extra_extlinuxtargetconfig.split()) > 0:
            bootprefix = d.getVar('UBOOT_EXTLINUX_BOOTPREFIXES') or ""
            subdir = bootprefix + 'extlinux'
        else:
            subdir = 'extlinux'

        # Initialize config file
        cfile = os.path.join(d.getVar('B'), subdir , 'extlinux.conf')

        # Create extlinux folder
        bb.utils.mkdirhier(os.path.dirname(cfile))

        # Standard extlinux file creation
        if fit_config == '1':
            bb.note("UBOOT_EXTLINUX_FIT set to '1'. Skip standard extlinux file creation")
        else:
            bb.note("Create %s/extlinux.conf file for %s labels" % (subdir, labels))
            create_extlinux_file(cfile, labels, d)

        # Manage UBOOT_EXTLINUX_TARGETS_EXTRA_CONFIG
        extra_extlinuxtargetconfigflag = d.getVarFlags('UBOOT_EXTLINUX_TARGETS_EXTRA_CONFIG')
        # The "doc" varflag is special, we don't want to see it here
        extra_extlinuxtargetconfigflag.pop('doc', None)
        # Handle new targets and labels append
        if len(extra_extlinuxtargetconfig.split()) > 0:
            bb.note("Manage EXTRA target configuration:")
            for config in extra_extlinuxtargetconfig.split():
                # Init extra config vars:
                extra_extlinuxlabels = ""
                extra_cfile = ""
                # Specific case for 'fit' to automate configuration with device tree name
                if fit_config == '1':
                    # Override current 'labels' with 'config' from UBOOT_EXTLINUX_TARGETS_EXTRA_CONFIG
                    # Under such configuration, UBOOT_EXTLINUX_TARGETS_EXTRA_CONFIG should contain the
                    # list of supported device tree file (without '.dtb' suffix) to allow proper extlinux
                    # file creation for each device tree file.
                    bb.note(">>> Override default init to allow default extlinux file creation with %s config as extra label." % config)
                    labels = config
                    # Update extra config vars for this specific case:
                    extra_extlinuxlabels = labels
                    extra_cfile = os.path.join(d.getVar('B'), subdir , config + '_' + 'extlinux.conf')
                    # Configure dynamically the default menu configuration if there is no specific one configured
                    if d.getVar('UBOOT_EXTLINUX_DEFAULT_LABEL:%s' % config):
                        bb.note(">>> Specific configuration for UBOOT_EXTLINUX_DEFAULT_LABEL var detected for %s label: %s" % (config, d.getVar('UBOOT_EXTLINUX_DEFAULT_LABEL:%s' % config)))
                    else:
                        bb.note(">>> Set UBOOT_EXTLINUX_DEFAULT_LABEL to %s" % config)
                        d.setVar('UBOOT_EXTLINUX_DEFAULT_LABEL', config)

                # Append extra configuration if any
                for f, v in extra_extlinuxtargetconfigflag.items():
                    if config == f:
                        bb.note(">>> Loop for '%s' extra target config." % config)
                        if len(v.split()) > 0:
                            bb.note(">>> Set '%s' to extra_extlinuxlabels." % v)
                            extra_extlinuxlabels = labels + ' ' + v
                            extra_cfile = os.path.join(d.getVar('B'), subdir , config + '_' + 'extlinux.conf')
                        else:
                            bb.note(">>> No extra labels defined, no new config file to create")
                        break
                # Manage new config file creation
                if extra_extlinuxlabels != "":
                    socname_list =  d.getVar('STM32MP_SOC_NAME')
                    if socname_list and len(socname_list.split()) > 0:
                        for soc in socname_list.split():
                            if config.find(soc) > -1:
                                if d.getVar('UBOOT_EXTLINUX_SPLASH:%s' % soc):
                                    splash = d.getVar('UBOOT_EXTLINUX_SPLASH:%s' % soc)
                                    bb.note(">>> Specific configuration for SPLASH Screen detected with configuration: %s" % config)
                                    bb.note(">>> Set UBOOT_EXTLINUX_SPLASH to %s" % splash)
                                    d.setVar('UBOOT_EXTLINUX_SPLASH', splash)
                    bb.note(">>> Create %s/%s_extlinux.conf file for %s labels" % (subdir, config, extra_extlinuxlabels))
                    create_extlinux_file(extra_cfile, extra_extlinuxlabels, d)
}
addtask create_multiextlinux_config before do_compile

do_create_multiextlinux_config[dirs] += "${B}"
do_create_multiextlinux_config[cleandirs] += "${B}"
# Manage specific var dependency:
# Because of local overrides within create_multiextlinux_config() function, we
# need to make sure to add each variables to the vardeps list.
UBOOT_EXTLINUX_TARGET_VARS = "FIT LABELS BOOTPREFIXES TIMEOUT DEFAULT_LABEL TARGETS_EXTRA_CONFIG"
do_create_multiextlinux_config[vardeps] += "${@' '.join(['UBOOT_EXTLINUX:%s:%s' % (v, l) for v in d.getVar('UBOOT_EXTLINUX_TARGET_VARS').split() for l in d.getVar('UBOOT_EXTLINUX_TARGETS').split()])}"
UBOOT_EXTLINUX_LABELS_VARS = "CONSOLE MENU_DESCRIPTION ROOT KERNEL_IMAGE FDTDIR FDT KERNEL_ARGS INITRD FIT"
UBOOT_EXTLINUX_LABELS_CONFIGURED = "${@' '.join(dict.fromkeys(' '.join('%s' % d.getVar('UBOOT_EXTLINUX_LABELS:%s' % o) for o in d.getVar('UBOOT_EXTLINUX_TARGETS').split()).split()))}"
UBOOT_EXTLINUX_LABELS_CONFIGURED += "${@' '.join(dict.fromkeys(' '.join('%s' % d.getVar('UBOOT_EXTLINUX_TARGETS_EXTRA_CONFIG:%s' % o) for o in d.getVar('UBOOT_EXTLINUX_TARGETS').split()).split()))}"
do_create_multiextlinux_config[vardeps] += "${@' '.join(['UBOOT_EXTLINUX:%s:%s' % (v, l) for v in d.getVar('UBOOT_EXTLINUX_LABELS_VARS').split() for l in d.getVar('UBOOT_EXTLINUX_LABELS_CONFIGURED').split()])}"
