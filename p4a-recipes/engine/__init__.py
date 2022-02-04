 
from pythonforandroid.recipe import IncludedFilesBehaviour, CythonRecipe

class EngineRecipe(IncludedFilesBehaviour, CythonRecipe):
    version = '0.8'
    url = None
    name = 'engine'
    
    src_filename = '.'
    depends = ['cython', 'msgpack']
    # built_libraries = {'engine.so': '.'}
    # call_hostpython_via_targetpython = False
    # install_in_hostpython = True
    
    # site_packages_name = 'engine'

print("__init__.py building recipe")
recipe = EngineRecipe()