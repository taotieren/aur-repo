#!/usr/bin/env python3
from lilaclib import *

def pre_build():
    aur_pre_build('serial-studio-bin', maintainers=['mrinmoy'])

    new_lines = []
    for line in edit_file('PKGBUILD'):
        if '.AppImage --appimage-extract' in line:
            indent = '    '
            new_lines.append(f'{indent}chmod +x ${{_pkgname}}-${{CARCH}}-${{pkgver}}-${{pkgrel}}.AppImage\n')
            new_lines.append(line)
        
        elif 'install -dm644' in line:
            new_lines.append(line.replace('install -dm644', 'install -dm755'))
        
        else:
            new_lines.append(line)

    with open('PKGBUILD', 'w') as f:
        f.writelines(new_lines)