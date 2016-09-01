#
# Template helper class
#
# Copyright (C) 2016 Wind River
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
# The generate files are listed below:

WRTEMPLATE_README = "README_templates"
WRTEMPLATE_CONF_WRTEMPLATE = "conf/wrtemplate.conf"
WRTEMPLATE_CONF_WRTEMPLATE_MACH = "conf/wrtemplate_${MACHINE}.conf"
WRTEMPLATE_CONF_WRIMAGE = "conf/wrimage.inc"
WRTEMPLATE_CONF_WRIMAGE_MACH = "conf/wrimage_${MACHINE}.inc"

include ${WRTEMPLATE_CONF_WRTEMPLATE}
include ${WRTEMPLATE_CONF_WRTEMPLATE_MACH}

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
    def find_template(bbpath, template, startpath=None, known=[]):
        """
        known will be modified, so it's best to pass it in as a copy
        """
        templates = []
        nflist = []

        # Following standard bitbake paths, first in win
        bbpaths = bbpath.split(':')

        # Rearrange the bbpaths to start with 'startpath'
        # 'rolling' any earlier paths to the end, i.e.
        # a:b:c:d:e:f with a startpath of 'd' will become
        # d:e:f:a:b:c
        if startpath:
           try:
               indx = bbpaths.index(startpath)
               l = len(bbpaths)
               if indx != 0:
                   path = ":".join(bbpaths[-1 * (l - (indx)):]) + ":" + ":".join(bbpaths[:(indx)])
                   bbpaths = path.split(':')
           except ValueError:
               pass

        notfound = 1
        # Search the path for the first template found
        for path in bbpaths:
            tmpldir = os.path.join(path, 'templates', template)
            if os.path.exists(tmpldir):
                notfound = 0

                # Check if the template should be skipped
                skipped = 0
                for skip in (d.getVar("WRTEMPLATE_SKIP", True) or "").split():
                    if tmpldir.endswith(skip):
                        skipped = 1
                        break
                if skipped == 1:
                    break
                # If the template is known, we just return, nothing to do
                if tmpldir in known:
                    break
                known.append(tmpldir)
                if os.path.exists(os.path.join(tmpldir, 'require')):
                    # Process requires -then- first
                        f = open(os.path.join(tmpldir, 'require'))
                        for line in f.readlines():
                            line = line.lstrip().strip()
                            if line.startswith('#'):
                                continue
                            else:
                                if line == template:
                                    # This is a recursive template, move to the -next- path
                                    idx = bbpaths.index(path)
                                    if idx + 1 >= len(bbpaths):
                                        path = bbpaths[0]
                                    else:
                                        path = bbpaths[idx + 1]
                                (reqtempl, nf, nnflist) = find_template(bbpath, line, path, known.copy())
                                if nf == 1:
                                    notfound = 2
                                    nflist.append(line)
                                if nf == 2:
                                    notfound = 2
                                    nflist.append(nnflist)
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

    bbpath = e.data.getVar('BBPATH', True)

    # Find this class... we then compare the date vs the generated files
    thisclass = bb.utils.which(bbpath, 'classes/wrltemplate.bbclass')

    readmef = os.path.join(e.data.getVar('TOPDIR', True), d.getVar('WRTEMPLATE_README', True))
    wrtemplatef = os.path.join(e.data.getVar('TOPDIR', True), d.getVar('WRTEMPLATE_CONF_WRTEMPLATE', True))
    wrtemplatemf = os.path.join(e.data.getVar('TOPDIR', True), d.getVar('WRTEMPLATE_CONF_WRTEMPLATE_MACH', True))
    wrimagef = os.path.join(e.data.getVar('TOPDIR', True), d.getVar('WRTEMPLATE_CONF_WRIMAGE', True))
    wrimagemf = os.path.join(e.data.getVar('TOPDIR', True), d.getVar('WRTEMPLATE_CONF_WRIMAGE_MACH', True))

    classmt = 0
    readmet = 0
    wrtemplatet = 0
    wrtemplatemt = 0
    wrimaget = 0
    wrimagemt = 0

    # If the config file looks ok, verify they are newer then this class
    if e.data.getVar("WRTEMPLATE", True) == e.data.getVarFlag("WRTEMPLATE", 'manual', True) and \
       e.data.getVar("WRTEMPLATE", True) == e.data.getVarFlag("WRTEMPLATE", 'machine', True) and \
       e.data.getVar("WRTEMPLATE_SKIP", True) == e.data.getVarFlag("WRTEMPLATE", "skip", True) and \
       e.data.getVar("BBLAYERS", True) == e.data.getVarFlag("WRTEMPLATE", "bblayers", True):
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

    # If we detect missing configuration, or the configuration is older then this class
    # regenerate files as necessary...
    if e.data.getVar("WRTEMPLATE", True) != e.data.getVarFlag("WRTEMPLATE", 'manual', True) or \
       e.data.getVar("WRTEMPLATE_SKIP", True) != e.data.getVarFlag("WRTEMPLATE", "skip", True) or \
       e.data.getVar("WRTEMPLATE", True) != e.data.getVarFlag("WRTEMPLATE", 'machine', True) or \
       e.data.getVar("WRTEMPLATE_SKIP", True) != e.data.getVarFlag("WRTEMPLATE", "machine_skip", True) or \
       e.data.getVar("BBLAYERS", True) != e.data.getVarFlag("WRTEMPLATE", "bblayers", True) or \
       e.data.getVar("BBLAYERS", True) != e.data.getVarFlag("WRTEMPLATE", "machine_bblayers", True) or \
       readmet < classmt or wrtemplatet < classmt or wrimaget < classmt or \
       wrtemplatemt < classmt or wrimagemt < classmt:
        bb.plain("Processing Wind River templates files...")

        templates = []
        error = 0

        # Look for 'default' templates
        for path in bbpath.split(':'):
            if os.path.exists(os.path.join(path, 'templates/default')):
                (templs, notfound, nflist) = find_template(bbpath, 'default', path, templates.copy())
                if notfound == 2:
                    for each in nflist:
                        bb.error("Unable to find template %s, required by %s." % (each, os.path.join(path, 'templates/default')))
                        error = 1
                for t in templs:
                    if t not in templates:
                        templates.append(t)

        # Process user templates
        for templ in e.data.getVar("WRTEMPLATE", True).split():
            (templs, notfound, nflist) = find_template(bbpath, templ, None, templates.copy())
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
        if e.data.getVar("WRTEMPLATE", True) != e.data.getVarFlag("WRTEMPLATE", 'manual', True) or \
           e.data.getVar("WRTEMPLATE_SKIP", True) != e.data.getVarFlag("WRTEMPLATE", "skip", True) or \
           e.data.getVar("BBLAYERS", True) != e.data.getVarFlag("WRTEMPLATE", "bblayers", True) or \
           readmet < classmt or wrtemplatet < classmt or wrimaget < classmt:
            # Construct the README_templates file
            f = open(readmef, 'w')
            f.write("This file contains a collection of the enabled template's README files\n\n")
            for t in templates:
                tconf = os.path.join(t, 'README')
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
            f.write('# Generated on %s\n' % e.data.getVar('DATETIME', True))
            f.write('\n')
            f.write('WRTEMPLATE[manual] = "%s"\n' % (e.data.getVar("WRTEMPLATE", True)))
            f.write('WRTEMPLATE[skip] = "%s"\n' % (e.data.getVar("WRTEMPLATE_SKIP", True)))
            f.write('WRTEMPLATE[bblayers] = "%s"\n' % (e.data.getVar("BBLAYERS", True)))
            f.write('\n')
            for t in templates:
                f.write('#### %s\n' % t)
                tconf = os.path.join(t, 'template.conf')
                if os.path.exists(tconf):
                    f.write('require %s\n' % tconf)
            f.close()

            # Construct the conf/wrimage.inc file
            f = open(wrimagef, 'w')
            f.write('# This file is automatically generated by the wrltemplate bbclass.\n')
            f.write('# Any changes made to this file will be lost when it is regenerated.\n')
            f.write('# Generated on %s\n' % e.data.getVar('DATETIME', True))
            f.write('\n')
            for t in templates:
                f.write('#### %s\n' % t)
                tconf = os.path.join(t, 'image.inc')
                if os.path.exists(tconf):
                    fin = open(tconf, 'r')
                    for line in fin.readlines():
                        f.write('%s' % line)
                    fin.close()
                f.write('\n')
            f.close()

        # Check if the machine specific configuration files are out of date and need to be regenerated...
        # It is valid for the system config to be set, but machine config to be differrent
        # this happens when the user switches machines, or does a multiple machine build
        if e.data.getVar("WRTEMPLATE", True) != e.data.getVarFlag("WRTEMPLATE", 'machine', True) or \
           e.data.getVar("WRTEMPLATE_SKIP", True) != e.data.getVarFlag("WRTEMPLATE", "machine_skip", True) or \
           e.data.getVar("BBLAYERS", True) != e.data.getVarFlag("WRTEMPLATE", "machine_bblayers", True) or \
           wrtemplatemt < classmt or wrimagemt < classmt:
            process_mach = d.getVar('WRTEMPLATE_BSP_PKGS', True)

            # Figure out which layer is providing the machine.conf file, limit
            # the following steps to ONLY templates in that layer (and layers in it's directory)
            machlayer = bb.utils.which(bbpath, e.data.expand('conf/machine/${MACHINE}.conf'))
            if machlayer:
                machlayer = "/".join(machlayer.split('/')[:-3])

            # Construct the conf/wrtemplate_${MACHINE}.conf file
            f = open(wrtemplatemf, 'w')
            f.write('# This file is automatically generated by the wrltemplate bbclass.\n')
            f.write('# Any changes made to this file will be lost when it is regenerated.\n')
            f.write('# Generated on %s\n' % e.data.getVar('DATETIME', True))
            f.write('\n')
            f.write('WRTEMPLATE[machine] = "%s"\n' % (e.data.getVar("WRTEMPLATE", True)))
            f.write('WRTEMPLATE[machine_skip] = "%s"\n' % (e.data.getVar("WRTEMPLATE_SKIP", True)))
            f.write('WRTEMPLATE[machine_bblayers] = "%s"\n' % (e.data.getVar("BBLAYERS", True)))
            f.write('\n')
            if process_mach == '1':
                for t in templates:
                    if t.startswith(machlayer):
                        f.write('#### %s\n' % t)
                        tconf = os.path.join(t, 'bsp-pkgs.conf')
                        if os.path.exists(tconf):
                           f.write('require %s\n' % tconf)
            f.close()

            # Construct the conf/wrimage_${MACHINE}.inc file
            f = open(wrimagemf, 'w')
            f.write('# This file is automatically generated by the wrltemplate bbclass.\n')
            f.write('# Any changes made to this file will be lost when it is regenerated.\n')
            f.write('# Generated on %s\n' % e.data.getVar('DATETIME', True))
            f.write('\n')
            if process_mach == '1':
                for t in templates:
                    if t.startswith(machlayer):
                        f.write('#### %s\n' % t)
                        tconf = os.path.join(t, 'bsp-pkgs.inc')
                        if os.path.exists(tconf):
                            fin = open(tconf, 'r')
                            for line in fin.readlines():
                                f.write('%s\n' % line)
                            fin.close()
                        f.write('\n')
            f.close()

        e.data.setVar("BB_INVALIDCONF", '1')
}