'''
Project: TransGrub
Copyright (c) 2020 Xilin Jia <https://github.com/XilinJia>
This software is released under the GPLv3 license
https://www.gnu.org/licenses/gpl-3.0.en.html
'''

# from setuptools import setup
from distutils.core import setup
from Cython.Build import cythonize
from distutils.extension import Extension
from Cython.Distutils import build_ext

setup(
    name = "engine",
    ext_modules = [Extension("engine", ["engine.pyx"])],
    cmdclass = {'build_ext': build_ext},
)

# python setup.py build_ext -v