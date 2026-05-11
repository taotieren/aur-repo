#!/usr/bin/env python3
from lilaclib import *

def pre_build():
    aur_pre_build('serial-studio-bin', maintainers=['mrinmoy'])

    with open('PKGBUILD', 'r') as f:
        lines = f.readlines()
    
    new_lines = []
    for i, line in enumerate(lines):
        if '.AppImage --appimage-extract' in line:
            indent = len(line) - len(line.lstrip())
            new_lines.append(' ' * indent + 'chmod +x ${_pkgname}-${CARCH}-${pkgver}-${pkgrel}.AppImage\n')
            new_lines.append(line)
        elif 'install -dm644' in line:
            new_lines.append(line.replace('install -dm644', 'install -dm755'))
        else:
            new_lines.append(line)
    
    with open('PKGBUILD', 'w') as f:
        f.writelines(new_lines)