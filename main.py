'''
Project: TransGrub
Copyright (c) 2020 Xilin Jia <https://github.com/XilinJia>
This software is released under the GPLv3 license
https://www.gnu.org/licenses/gpl-3.0.en.html
'''


# import kivy
# kivy.require('1.1.0')

from kivy.utils import platform
from kivy.app import App

from TransGrub import TransGrub

class TransGrubApp(App):

    def build(self):
        datadir = ''
        if platform == 'android':
            from android.storage import app_storage_path
            datadir = app_storage_path()
        else:
            datadir = getattr(self, 'user_data_dir')
        print(datadir)        
        
        return TransGrub(datadir, info='TransGrub')


if __name__ == '__main__':
    TransGrubApp().run()
 
