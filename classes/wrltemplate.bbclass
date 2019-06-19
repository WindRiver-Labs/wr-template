#
# Template helper class
#
# Copyright (C) 2016-2017 Wind River Systems, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#
# The Wind River template is a mechanism to assist the user in performing a
# specific configuration task.  This may include requiring other templates,
# setting various configuration options, adjusting image settings or even
# performing BSP specific configurations.
#
# The files involved in a template directory include:
#   README - template README file
#   require - list of other templates required for this one
#   template.conf - template configuration fragment
#   image.inc - image fragment
#   bsp-pkgs.conf - BSP specific configuration fragment
#   bsp-pkgs.inc - BSP specific image fragment
#
# The 'bsp-pkgs' files can only be in a template in a layer that provides a
# specific conf/machine/${MACHINE}.conf file and layers it may contain,
# otherwise they will be ignored
#

WRTEMPLATE_README ?= "${TOPDIR}/README_templates"
WRTEMPLATE_README[documentation] = "Generated Wind River template README file path"
WRTEMPLATE_CONF_WRTEMPLATE ?= "${TOPDIR}/conf/wrtemplate.conf"
WRTEMPLATE_CONF_WRTEMPLATE[documentation] = "Generated template configuration file path"
WRTEMPLATE_CONF_WRTEMPLATE_MACH ?= "${TOPDIR}/conf/wrtemplate_${MACHINE}.conf"
WRTEMPLATE_CONF_WRTEMPLATE_MACH[documentation] = "Generated machine specific template configuration file path"
WRTEMPLATE_CONF_WRIMAGE ?= "${TOPDIR}/conf/wrimage.inc"
WRTEMPLATE_CONF_WRIMAGE[documentation] = "Generated image recipe extension file path"
WRTEMPLATE_CONF_WRIMAGE_MACH ?= "${TOPDIR}/conf/wrimage_${MACHINE}.inc"
WRTEMPLATE_CONF_WRIMAGE_MACH[documentation] = "Generated machine specific image recipe extension file path"

WRTEMPLATE_INHERIT_CHECK := "${INHERIT}"

WRTEMPLATE_CLASSES ?= ""

include ${WRTEMPLATE_CONF_WRTEMPLATE}
include ${WRTEMPLATE_CONF_WRTEMPLATE_MACH}

inherit ${WRTEMPLATE_CLASSES}

# Space separated list of templates to load.  Note: "default" templates are
# always loaded.
WRTEMPLATE ?= ""

# Space separated list of templates to avoid loading.  Uses 'endswith'
WRTEMPLATE_SKIP ?= ""

# Should we process 'bsp' specific templates
WRTEMPLATE_BSP_PKGS ?= '1'

# Should the image use the image template items
# This can be set to != 1 globally, or on a per recipe basis such aas:
# WRTEMPLATE_IMAGE_pn-core-image-minimal = '0'
WRTEMPLATE_IMAGE ?= '1'

# Check if we need to reprocess the templates
addhandler wrl_template_processing_eventhandler
wrl_template_processing_eventhandler[eventmask] = "bb.event.ConfigParsed"
#wrl_template_processing_eventhandler[eventmask] = "bb.event.SanityCheck"
python wrl_template_processing_eventhandler () {
    # Generate the wr files in conf even for do_populate_sdk_ext().

    def find_template(bbpath, template, known=[], startpath=None, findfirst=True):
        """
        known will be modified, so it's best to pass it in as a copy

        bbpath: Path to search
        known: list of known templates
        startpath: skip any found items prior to this path
        findfirst: Stop once we find the first match, otherwise keep looking
        """
        templates = []
        nflist = []

        spath = startpath

        notfound = 1
        # Search the path for the first template found, not already known
        for path in bbpath.split(':'):
            if spath:
                if path != spath:
                    continue
                else:
                    # We found it, stop looking...
                    spath = None

            tmpldir = os.path.join(path, 'templates', template)
            if os.path.exists(tmpldir):
                notfound = 0

                # Check if the template should be skipped
                skipped = 0
                for skip in (d.getVar("WRTEMPLATE_SKIP") or "").split():
                    if tmpldir.endswith(skip):
                        skipped = 1
                        break
                if skipped == 1:
                    if findfirst:
                        break
                    else:
                        continue
                # If the template is known, skip to the next template
                # with this name
                if tmpldir in known:
                    if findfirst:
                        break
                    else:
                        continue
                known.append(tmpldir)
                if os.path.exists(os.path.join(tmpldir, 'require')):
                    # Process requires -then- findfirst (the template)
                    f = open(os.path.join(tmpldir, 'require'))
                    for line in f.readlines():
                        line = line.lstrip().strip()
                        if line.startswith('#'):
                            continue
                        else:
                            if line == template:
                                # optimization, we can start looking in this dir, since we know this is the
                                # last template with this name that was found...  Also set the firstfound
                                # to false, so the system will keep looking for a later, not already included
                                # copy of this template...
                                (reqtempl, nf, nnflist) = find_template(bbpath, line, known.copy(), path, False)

                                # Recursive templates are allowed to fail with not-found
                                if nf == 1:
                                    nf = 0
                            else:
                                (reqtempl, nf, nnflist) = find_template(bbpath, line, known.copy())

                            # nf == 1; template was not found, change to '2', requirement not found, add to nflist
                            if nf == 1:
                                notfound = 2
                                nflist.append(line)
                            # nf == 2; requirement was not found, add to the requirement to nflist
                            elif nf == 2:
                                notfound = 2
                                nflist.append(nnflist)
                            # For all requirements found, add them if not already known
                            for req in reqtempl:
                                if req not in known:
                                    known.append(req)
                                    templates.append(req)
                    f.close()

                # Now that requirements have been handled, add the template to the list
                # templates should contain all requirements, then the template
                templates.append(tmpldir)
                break

        return (templates, notfound, nflist)

    bbpath = e.data.getVar('BBPATH')

    # Find this class... we then compare the date vs the generated files
    thisclass = bb.utils.which(bbpath, 'classes/wrltemplate.bbclass')

    readmef = d.getVar('WRTEMPLATE_README')
    wrtemplatef = d.getVar('WRTEMPLATE_CONF_WRTEMPLATE')
    wrtemplatemf = d.getVar('WRTEMPLATE_CONF_WRTEMPLATE_MACH')
    wrimagef = d.getVar('WRTEMPLATE_CONF_WRIMAGE')
    wrimagemf = d.getVar('WRTEMPLATE_CONF_WRIMAGE_MACH')

    if not (readmef and wrtemplatef and wrtemplatemf and wrimagef and wrimagemf):
        bb.warn("wrltemplate processing skipped, variables not configured properly.")
        return

    classmt = 0
    readmet = 0
    wrtemplatet = 0
    wrtemplatemt = 0
    wrimaget = 0
    wrimagemt = 0

    # If this class changes, we need to regenerate the templates
    # In order to do this, compare the mtime of this class and the generated files
    if e.data.getVar("WRTEMPLATE") == e.data.getVarFlag("WRTEMPLATE", 'manual') and \
       e.data.getVar("WRTEMPLATE") == e.data.getVarFlag("WRTEMPLATE", 'machine') and \
       e.data.getVar("WRTEMPLATE_SKIP") == e.data.getVarFlag("WRTEMPLATE", "skip") and \
       e.data.getVar("BBLAYERS") == e.data.getVarFlag("WRTEMPLATE", "bblayers"):
        classmt = os.path.getmtime(thisclass)

        if os.path.exists(readmef):
            readmet = os.path.getmtime(readmef)

        if os.path.exists(wrtemplatef):
            wrtemplatet = os.path.getmtime(wrtemplatef)

        if os.path.exists(wrtemplatemf):
            wrtemplatemt = os.path.getmtime(wrtemplatemf)

        if os.path.exists(wrimagef):
            wrimaget = os.path.getmtime(wrimagef)

        if os.path.exists(wrimagemf):
            wrimagemt = os.path.getmtime(wrimagemf)

    # mtime format is a string of space separated '<filename>(mtime)'
    def check_mtimes(mtimes):
        if mtimes:
            for entry in mtimes.split():
                tconf = '('.join(entry.split('(')[:-1])
                mtime = '('.join(entry.split('(')[-1:]).split(')')[0]

                if os.path.exists(tconf) and float(mtime) == os.path.getmtime(tconf):
                    continue

                return True

        return False

    # If WRTEMPLATE[mtimes] is set, we need to verify that the mtimes have not changed
    reload_mtime = check_mtimes(e.data.getVarFlag("WRTEMPLATE", "mtimes"))

    # If WRTEMPLATE[machine_mtimes] is set, we need to verify that the mtimes have not changed
    reload_machine_mtime = check_mtimes(e.data.getVarFlag("WRTEMPLATE", "machine_mtimes"))

    # If we detect missing configuration, or the configuration is older then this class
    # regenerate files as necessary...
    if reload_mtime or reload_machine_mtime or\
       e.data.getVar("WRTEMPLATE") != e.data.getVarFlag("WRTEMPLATE", 'manual') or \
       e.data.getVar("WRTEMPLATE_SKIP") != e.data.getVarFlag("WRTEMPLATE", "skip") or \
       e.data.getVar("WRTEMPLATE") != e.data.getVarFlag("WRTEMPLATE", 'machine') or \
       e.data.getVar("WRTEMPLATE_SKIP") != e.data.getVarFlag("WRTEMPLATE", "machine_skip") or \
       e.data.getVar("BBLAYERS") != e.data.getVarFlag("WRTEMPLATE", "bblayers") or \
       e.data.getVar("BBLAYERS") != e.data.getVarFlag("WRTEMPLATE", "machine_bblayers") or \
       readmet < classmt or wrtemplatet < classmt or wrimaget < classmt or \
       wrtemplatemt < classmt or wrimagemt < classmt:
        bb.plain("Processing Wind River templates files...")

        templates = []
        error = 0

        # Look for 'default' templates
        for path in bbpath.split(':'):
            if os.path.exists(os.path.join(path, 'templates/default')):
                (templs, notfound, nflist) = find_template(bbpath, 'default', templates.copy(), path)
                if notfound == 2:
                    for each in nflist:
                        bb.error("Unable to find template %s, required by %s." % (each, os.path.join(path, 'templates/default')))
                        error = 1
                for t in templs:
                    if t not in templates:
                        templates.append(t)

        # Process user templates
        for templ in e.data.getVar("WRTEMPLATE").split():
            (templs, notfound, nflist) = find_template(bbpath, templ, templates.copy())
            if notfound == 1:
                bb.error('Unable to find template "%s"' % (templ))
                error = 1
            if notfound == 2:
                for each in nflist:
                    bb.error("Unable to find template %s, required by %s." % (each, templ))
                error = 1
            for t in templs:
                if t not in templates:
                    templates.append(t)

        if error != 0:
            bb.fatal("Aborting template processing.")
            return

        # Check if the configuration wide files are out of date and need to be regenerated...
        if reload_mtime or \
           e.data.getVar("WRTEMPLATE") != e.data.getVarFlag("WRTEMPLATE", 'manual') or \
           e.data.getVar("WRTEMPLATE_SKIP") != e.data.getVarFlag("WRTEMPLATE", "skip") or \
           e.data.getVar("BBLAYERS") != e.data.getVarFlag("WRTEMPLATE", "bblayers") or \
           readmet < classmt or wrtemplatet < classmt or wrimaget < classmt:
            # Construct the README_templates file
            f = open(readmef, 'w')
            f.write("This file contains a collection of the enabled template's README files\n\n")
            for t in templates:
                tconf = os.path.realpath(os.path.join(t, 'README'))
                if os.path.exists(tconf):
                    f.write('#### %s:\n' % tconf)
                    fin = open(tconf, 'r')
                    for line in fin.readlines():
                        f.write('%s' % line)
                    fin.close()
                    f.write('\n')
            f.close()

            # Construct the conf/wrtemplate.conf file
            f = open(wrtemplatef, 'w')
            f.write('# This file is automatically generated by the wrltemplate bbclass.\n')
            f.write('# Any changes made to this file will be lost when it is regenerated.\n')
            f.write('# Generated on %s\n' % e.data.getVar('DATETIME'))
            f.write('\n')
            f.write('WRTEMPLATE[manual] = "%s"\n' % (e.data.getVar("WRTEMPLATE")))
            f.write('WRTEMPLATE[skip] = "%s"\n' % (e.data.getVar("WRTEMPLATE_SKIP")))
            f.write('WRTEMPLATE[bblayers] = "%s"\n' % (e.data.getVar("BBLAYERS")))
            f.write('\n')
            for t in templates:
                f.write('#### %s\n' % t)
                tconf = os.path.realpath(os.path.join(t, 'template.conf'))
                if os.path.exists(tconf):
                    f.write('WRTEMPLATE[mtimes] += "%s(%s)"\n' % (tconf, os.path.getmtime(tconf)))
                    fin = open(tconf, 'r')
                    for line in fin.readlines():
                        f.write('%s' % line)
                    fin.close()
                f.write('\n')
            f.close()

            # Construct the conf/wrimage.inc file
            f = open(wrimagef, 'w')
            f_wrtemplatef = open(wrtemplatef, 'a')
            f.write('# This file is automatically generated by the wrltemplate bbclass.\n')
            f.write('# Any changes made to this file will be lost when it is regenerated.\n')
            f.write('# Generated on %s\n' % e.data.getVar('DATETIME'))
            f.write('\n')
            for t in templates:
                f.write('#### %s\n' % t)
                tconf = os.path.realpath(os.path.join(t, 'image.inc'))
                if os.path.exists(tconf):
                    # Write image.inc's mtimes to WRTEMPLATE_CONF_WRTEMPLATE
                    # rather than WRTEMPLATE_CONF_WRIMAGE, otherwise it won't
                    # reload when image.inc's mtime is changed since the later
                    # one is not included when parsing.
                    f_wrtemplatef.write('WRTEMPLATE[mtimes] += "%s(%s)"\n' % (tconf, os.path.getmtime(tconf)))
                    fin = open(tconf, 'r')
                    for line in fin.readlines():
                        f.write('%s' % line)
                    fin.close()
                f.write('\n')
            f_wrtemplatef.close()
            f.close()

        # Check if the machine specific configuration files are out of date and need to be regenerated...
        # It is valid for the system config to be set, but machine config to be differrent
        # this happens when the user switches machines, or does a multiple machine build
        if reload_machine_mtime or \
           e.data.getVar("WRTEMPLATE") != e.data.getVarFlag("WRTEMPLATE", 'machine') or \
           e.data.getVar("WRTEMPLATE_SKIP") != e.data.getVarFlag("WRTEMPLATE", "machine_skip") or \
           e.data.getVar("BBLAYERS") != e.data.getVarFlag("WRTEMPLATE", "machine_bblayers") or \
           wrtemplatemt < classmt or wrimagemt < classmt:
            process_mach = d.getVar('WRTEMPLATE_BSP_PKGS')

            # Figure out which layer is providing the machine.conf file, limit
            # the following steps to ONLY templates in that layer (and layers in it's directory)
            machlayer = bb.utils.which(bbpath, e.data.expand('conf/machine/${MACHINE}.conf'))
            if machlayer:
                machlayer = "/".join(machlayer.split('/')[:-3])

            def get_layer_from_template(template):
                import re
                t_layer_m = re.match('(.*)/templates/default$', template)
                if not t_layer_m:
                    t_layer_m = re.match('(.*)/templates/feature/[^/]*', template)
                if t_layer_m:
                    return t_layer_m.group(1)
                else:
                    return ''

            # Construct the conf/wrtemplate_${MACHINE}.conf file
            f = open(wrtemplatemf, 'w')
            f.write('# This file is automatically generated by the wrltemplate bbclass.\n')
            f.write('# Any changes made to this file will be lost when it is regenerated.\n')
            f.write('# Generated on %s\n' % e.data.getVar('DATETIME'))
            f.write('\n')
            f.write('WRTEMPLATE[machine] = "%s"\n' % (e.data.getVar("WRTEMPLATE")))
            f.write('WRTEMPLATE[machine_skip] = "%s"\n' % (e.data.getVar("WRTEMPLATE_SKIP")))
            f.write('WRTEMPLATE[machine_bblayers] = "%s"\n' % (e.data.getVar("BBLAYERS")))
            f.write('\n')
            if process_mach == '1':
                for t in templates:
                    # Search templates in parent layer if it is a sublayer
                    t_layer = get_layer_from_template(t)
                    if t.startswith(machlayer) or (t_layer and machlayer.startswith(t_layer)):
                        f.write('#### %s\n' % t)
                        tconf = os.path.realpath(os.path.join(t, 'bsp-pkgs.conf'))
                        if os.path.exists(tconf):
                            f.write('WRTEMPLATE[machine_mtimes] += "%s(%s)"\n' % (tconf, os.path.getmtime(tconf)))
                            fin = open(tconf, 'r')
                            for line in fin.readlines():
                                f.write('%s' % line)
                            fin.close()
                        f.write('\n')
            f.close()

            # Construct the conf/wrimage_${MACHINE}.inc file
            f = open(wrimagemf, 'w')
            f.write('# This file is automatically generated by the wrltemplate bbclass.\n')
            f.write('# Any changes made to this file will be lost when it is regenerated.\n')
            f.write('# Generated on %s\n' % e.data.getVar('DATETIME'))
            f.write('\n')
            if process_mach == '1':
                for t in templates:
                    # Search templates in parent layer if it is a sublayer
                    t_layer = get_layer_from_template(t)
                    if t.startswith(machlayer + "/") or (t_layer and machlayer.startswith(t_layer + "/")):
                        f.write('#### %s\n' % t)
                        tconf = os.path.realpath(os.path.join(t, 'bsp-pkgs.inc'))
                        if os.path.exists(tconf):
                            f.write('WRTEMPLATE[machine_mtimes] += "%s(%s)"\n' % (tconf, os.path.getmtime(tconf)))
                            fin = open(tconf, 'r')
                            for line in fin.readlines():
                                f.write('%s' % line)
                            fin.close()
                        f.write('\n')
            f.close()

        e.data.setVar("BB_INVALIDCONF", True)

    else:
        # Check if a template has modified the INHERIT, this won't work..
        template_before = e.data.getVar("WRTEMPLATE_INHERIT_CHECK")
        template_after = e.data.getVar("INHERIT")

        if template_before != template_after:
            bb.error("The value of INHERIT has changed due to a template.  Templates " \
                    "should only add inherits by specifying changes to WRTEMPLATE_CLASSES.")

            inherits = ""
            for inherit in template_after.split():
                if inherit not in template_before.split():
                    inherits += " +%s" % inherit
                else:
                    inherits += " %s" % inherit

            bb.fatal("INHERIT:%s" % inherits)
}
