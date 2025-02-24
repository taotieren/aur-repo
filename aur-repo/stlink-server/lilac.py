#!/usr/bin/env python3

from lilaclib import *
import os

build_args = ["-r", os.path.expanduser("~/chroots")]


def post_build():
    aur_post_build()
