 #! /bin/bash

cd CythonModules

python setup.py build_ext -v --inplace

mv engine.cpython-37m-x86_64-linux-gnu.so ../
