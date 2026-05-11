#!/usr/bin/env python3
from lilaclib import *

def pre_build():
    aur_pre_build('serial-studio-bin', maintainers=['mrinmoy'])

    with open('PKGBUILD', 'r') as f:
        lines = f.readlines()
    
    new_lines = []
    for line in lines:
        if '.AppImage --appimage-extract' in line:
            new_lines.append('    chmod +x ${_pkgname}-${CARCH}-${pkgver}-${pkgrel}.AppImage\n')
            new_lines.append(line)
        
        elif 'install -dm644' in line:
            new_lines.append(line.replace('install -dm644', 'install -dm755'))
        
        elif 'ln -s "${pkgdir}/opt/' in line:
            fixed_line = line.replace('"${pkgdir}/opt/', '"/opt/')
            new_lines.append(fixed_line)
        
        else:
            new_lines.append(line)
    
    with open('PKGBUILD', 'w', newline='\n') as f:
        f.writelines(new_lines)