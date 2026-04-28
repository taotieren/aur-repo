#!/usr/bin/env python3
from lilaclib import *

def pre_build():
    aur_pre_build('serial-studio-bin', maintainers=['mrinmoy'])
    for line in edit_file('PKGBUILD'):

        if line.strip().endswith('.AppImage --appimage-extract'):
            print('    chmod +x "${srcdir}"/*.AppImage')

        print(line)
