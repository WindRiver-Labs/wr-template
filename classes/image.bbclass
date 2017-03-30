#
# Template helper and image override class
#
# Purpose of this class is to intercept the image.bbclass inherit and add
# template process inclusion.
#
# Copyright (C) 2016-2017 Wind River Systems, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

def wrlt_next_class(d, classname):
    """
    This function should be called w/ d and the name of this class (classname)

    It will find the next (in the path) version of this class, or return ""

    It allows a class in an early layer to include a class in a later layer.
    """

    idx = -1
    bbpath = d.getVar('BBPATH', True).split(':')

    # We need to expand the bbpath to match __inherit_cache entry
    bbpath = list(map(lambda x: os.path.realpath(x), bbpath))

    # based on bb.data.inherits_class -- find the last inherit of this class
    val = d.getVar('__inherit_cache', False) or []
    needle = os.path.join('classes', '%s.bbclass' % classname)
    val.reverse()
    for v in val:
        if v.endswith(needle):
           layername = os.path.dirname(os.path.dirname(v))

           # If the bbpath has the same layer more than once, scan to the end
           while True:
               try:
                   idx = bbpath.index(layername, idx+1)
               except ValueError:
                   break
           break

    ret = bb.utils.which(":".join(bbpath[idx+1:]), 'classes/%s.bbclass' % classname) or ""

    return ret

inherit ${@wrlt_next_class(d, 'image')}

# The includes must always be -after- image.bbclass inherit
# because they may add or remove from the image variable
require ${@['${WRTEMPLATE_CONF_WRIMAGE}', 'wrlnoimage.inc'][d.getVar('WRTEMPLATE_IMAGE', True) != '1']}
require ${@['${WRTEMPLATE_CONF_WRIMAGE_MACH}', 'wrlnoimage_mach.inc'][d.getVar('WRTEMPLATE_IMAGE', True) != '1']}
