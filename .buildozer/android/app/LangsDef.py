'''
Project: TransGrub
Copyright (c) 2020 Xilin Jia <https://github.com/XilinJia>
This software is released under the GPLv3 license
https://www.gnu.org/licenses/gpl-3.0.en.html
'''


GameLangs = ('en', 'fr', 'de', 'it', 'es')
ClueLangs = ('en', 'fr', 'de', 'it', 'es', 'ru', 'ar', 'zh_cn', 'zh_tw')
langNames = dict()
langNames['en'] = "English"
langNames['fr'] = "français"
langNames['de'] = "Deutch"
langNames['it'] = "italiano"
langNames['es'] = "español"
langNames['ru'] = "русский"
langNames['ar'] = "Arabic"
langNames['zh_cn'] = "ChineseCN"
langNames['zh_tw'] = "ChineseTW"
revd=dict([reversed(i) for i in langNames.items()])
langNames.update(revd)
