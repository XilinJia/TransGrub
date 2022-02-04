'''
Project: TransGrub
Copyright (c) 2020 Xilin Jia <https://github.com/XilinJia>
This software is released under the GPLv3 license
https://www.gnu.org/licenses/gpl-3.0.en.html
'''

from kivy.config import Config
# Config.set('graphics','width', 800)
# Config.set('graphics','height', 600)

# import kivy
# kivy.require('1.1.0')

from kivy.uix.floatlayout import FloatLayout
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.togglebutton import ToggleButton
from kivy.uix.behaviors.button import ButtonBehavior
from kivy.uix.image import Image
from kivy.properties import ObjectProperty, StringProperty
from kivy.clock import Clock
from kivy.core.window import Window
from kivy.uix.spinner import Spinner, SpinnerOption
from kivy.uix.popup import Popup
from kivy.uix.label import Label
from kivy.animation import Animation
from VerticalProgress import VerticalProgressBar

import certifi
import os

from LangsDef import *
from engine import Engine
from engine import WordGrades, WordStages

windowWidth = Window.width
windowHeight = Window.height


class SpinnerOptions(SpinnerOption):

    def __init__(self, **kwargs):
        super(SpinnerOptions, self).__init__(**kwargs)
        self.background_normal = ''
        self.background_color = [0, 0.6, 0.6, 1]    
        # self.height = 26

class IconButton(ButtonBehavior, Image):
    pass

class TransGrub(FloatLayout):
    info = StringProperty()
    title_label = ObjectProperty()
    waitPopup = ObjectProperty()
    opts_layout = ObjectProperty()
    pieces_stack = ObjectProperty()
    clues_field = ObjectProperty()
    solutions_field = ObjectProperty()
    check_stack = ObjectProperty()
    get_hint_btn = ObjectProperty()
    luck_btn = ObjectProperty()
    progres_box = ObjectProperty()
    
    def __init__(self, datadir, **kwargs) :
        self.eng = Engine(datadir)
        self.waitPopup = \
            Popup(title='', separator_height=0,
                    size_hint=(None, None), size=(400, 400),
                    content=Label(text='Preparing for the languages.\n\nPlease wait a moment.',
                                font_size = '30sp'))
        help_label = Label(text='Inflections can be included/excluded by toggle of the button.\n'\
                        'Grades separate words based on usage frequency in the language.  ' \
                        'Lower grades present more frequent words.\n'\
                        'Stages separate words based on length.  ' \
                        'Lower stages present shorter words.\n'\
                        'Press main window to dismiss help.',
                        text_size=(0.7*windowWidth,None),
                        halign="left",
                        valign = "middle",
                        font_size = '18sp')
        self.helpPopup = Popup(title='', separator_height=0,
                  size_hint=(None, None), size=(0.8*windowWidth, 0.8*windowHeight),
                  background_color = [3, 3, 1.5, 1.],
                  content=help_label)
            
        self.configPopup = self._build_configPopup()
                
        super(TransGrub, self).__init__(**kwargs)   
        self.luck_btn.bind(text=self.on_luck)
        self.luck_btn.disabled = True

        print("Window size: ", windowWidth, windowHeight)
        self.pieces_stack.height = 0.4 * windowHeight
        
        self._do_wait(self._build_eng)
        
        self._build_progressbar()

    def _build_progressbar(self):
        self.g1l1pb = VerticalProgressBar()
        self.g1l2pb = VerticalProgressBar()
        self.progres_box.add_widget(self.g1l1pb)
        self.progres_box.add_widget(self.g1l2pb)
        self.g1l1pb.pos = self.progres_box.pos
        self.g1l2pb.pos = self.progres_box.pos
        self.g1l1pb.set_value(70)
        self.g1l2pb.set_value(30)

    def _build_eng(self, junk) :
        self.eng.buildProvider()
        
        if not self.eng.isReady():
            self.do_config()
        else:
            if self.eng.getLang2() in ['zh_cn', 'zh_tw']:
                self.clues_field.font_name = "DroidSansFallback"
                self.clues_field.line_height = 1.15
                self.clues_field.font_size = '16sp'
            elif self.eng.getLang2() == 'ar':
                self.clues_field.font_name = "Scheherazade-Bold"
                self.clues_field.line_height = 0.58
                self.clues_field.font_size = '25sp'
            else:
                self.clues_field.font_name = "Roboto"
                self.clues_field.line_height = 1.15
                self.clues_field.font_size = '17sp'
            
            # self.stageSpinner.text = 'stage 1'
            self._update_title()

    def _update_title(self) :
        self.title_label.text = self.eng.titleText()
        
    def _build_configPopup(self) :
        configLayout = FloatLayout()
        boxLayout = BoxLayout(orientation = 'horizontal',
                              size_hint=(0.5, 0.1),
                              pos_hint={'left': 0., 'top': 1.})
        self.spinner2 = Spinner(text='Clue\nLanguage', values=[langNames[x] for x in ClueLangs],
                               size_hint=(None, 1))
        trans_arrowLabel = Label(text=' >>>> ', size_hint=(0.1, 1))
        self.spinner1 = Spinner(text='Game\nLanguage', values=[langNames[x] for x in GameLangs],
                               size_hint=(None, 1))
        boxLayout.add_widget(self.spinner2)
        boxLayout.add_widget(trans_arrowLabel)
        boxLayout.add_widget(self.spinner1)
        self.spinner1.bind(text=self._set_lang1)
        self.spinner2.bind(text=self._set_lang2)
        configLayout.add_widget(boxLayout)
                
        helpBtn = Button(text='Help', size_hint=(.15, .1), 
                                 pos_hint={'right': 1, 'top': 1},
                                 background_color=(2, 1, 0.2, 1))
        helpBtn.bind(on_release=self._show_help)
        configLayout.add_widget(helpBtn)

        self.gradeSpinner = Spinner(text='Grade All', 
                                    values=["Grade " + s for s in WordGrades+['All']],
                                    size_hint=(None, 1),
                                    width=min(150, 0.2*windowWidth),
                                    background_color=(0, 0.6, 0.6, 1))
        self.gradeSpinner.option_cls = SpinnerOptions
        self.inflectBtn = ToggleButton(text='No\nInflects', 
                                       size_hint=(None, 1),
                                       width=min(150, 0.2*windowWidth),
                                       halign='center')
        self.stageSpinner = Spinner(text='Stage 1', values=["Stage " + s for s in WordStages],
                               size_hint=(None, 1),
                               width=min(150, 0.2*windowWidth),
                               background_color=(0, 0.6, 0.6, 1))
        self.stageSpinner.option_cls = SpinnerOptions
        grade_stageBox = BoxLayout(orientation = 'horizontal',
                              size_hint=(0.6, 0.1),
                              pos_hint={'left': 0., 'top': 0.8})
        grade_stageBox.add_widget(self.inflectBtn)
        grade_stageBox.add_widget(self.gradeSpinner)
        grade_stageBox.add_widget(self.stageSpinner)
        configLayout.add_widget(grade_stageBox)
        self.gradeSpinner.bind(text=self._set_grade)
        self.stageSpinner.bind(text=self._set_stage)
        self.inflectBtn.bind(state=self._inflect_set)

        pointBtn = Button(text='Get Points', size_hint=(.18, .1), 
                                 pos_hint={'center_x': 0.8, 'center_y': 0.45},
                                 background_color=(0.2, 1, 2, 1))
        pointBtn.bind(on_press=self._get_points)
        configLayout.add_widget(pointBtn)

        okBtn = Button(text='OK', size_hint=(.18, .1), 
                                 pos_hint={'center_x': 0.5, 'center_y': 0.25},
                                 background_color=(0.2, 1, 0.2, 1))
        okBtn.bind(on_press=self._confirm_setup)
        configLayout.add_widget(okBtn)
        
        configLayout.bind()
        return Popup(title='', 
                     content=configLayout,
                     background_color = [3, 3, 1.5, 0.8])

    def _set_lang1(self, obj, text) :
        self.eng.setLang1(langNames[text])
 
    def _set_lang2(self, obj, text) :
        self.eng.setLang2(langNames[text])

    def do_config(self) :
        # print(self.spinner1._label.texture.size, self.spinner2._label.texture.size)
        if self.eng.getLang1() != '':
            self.spinner1.text = langNames[self.eng.getLang1()]
        if self.eng.getLang2() != '':
            self.spinner2.text = langNames[self.eng.getLang2()]
        self.eng.langChange = False
        self.spinner1.width = self.spinner1._label.texture.size[0] + 30
        self.spinner2.width = self.spinner2._label.texture.size[0] + 30
        self.configPopup.open()

    def _do_wait(self, action) :
        self.waitPopup.open()
        Clock.schedule_once(action, 0)
        self.waitPopup.dismiss()
        
    def _confirm_setup(self, junk) :
        if self.eng.isReady():
            if self.eng.langChange and self.eng.getLang1() != self.eng.getLang2():
                self.eng.saveSettings()
                self._do_wait(self._build_eng)
                self.clear_gui()
            elif self.eng.engChange:
                self.clear_gui()
                self.eng.engChange = False
            self.configPopup.dismiss() 

    def _show_help(self, junk) :
        self.helpPopup.open()
        
    def _cancel_setup(self, junk) :
        self.configPopup.dismiss()

    def _get_points(self, junk) :
        self.eng.getPoints()
        self._update_title()
        
    def _set_stage(self, obj, text) :
        stage = int(text.replace("Stage ", ''))-1
        self.eng.setStage(stage)
        print("In _set_stage ", stage+1)
        self._update_title()

    def _set_grade(self, obj, text) :
        gtext = text.replace("Grade ", '')
        if gtext == "All":
            gtext = "0"
        grade = int(gtext)-1
        self.eng.setGrade(grade)
        print("In _set_grade ", grade+1)
        self._update_title()

    def _inflect_set(self, obj, state) :
        print("_inflect_set: ", state)
        if state == "down":
            inflections = True
            self.inflectBtn.text = 'Use\nInflects'
        else:
            inflections = False
            self.inflectBtn.text = 'No\nInflects'
        self.eng.setInflection(inflections)
        self._update_title()
        
    def _prepare_game(self):
        self.eng.prepareGame()
        self._populate_gui()

    def clear_gui(self) :
        self.clues_field.text = ''
        self.solutions_field.text = ''
        self.pieces_stack.clear_widgets()

    def _populate_gui(self) :
        maxWindthRatio = 1. / (int(len(self.eng.getWordPieces()) / 4) + 1)
        for piece in self.eng.getWordPieces():
            btn = Button(text=piece, 
                         font_size='25sp', 
                         size_hint=(None, None),
                         width=0.9*maxWindthRatio*windowWidth,
                         height=0.1*windowHeight,
                         on_press=self.on_answer)
            self.pieces_stack.add_widget(btn)
        
    def _update_clue_fields(self):
        self.clues_field.text, self.solutions_field.text = self.eng.updateClueFields()
       
    def on_get_hint(self):    
        pieces = self.eng.getHint()
        self._update_title()
        if pieces == None:
            return
        print("on_get_hint", pieces)  
        anim = Animation(background_color = (2, 2, 1, 1), duration=2.) + \
            Animation(background_color = (1, 1, 1, 1), duration=2.)
        for piece in self.pieces_stack.children:
            if piece.text in pieces:
                print(piece, piece.text)
                anim.start(piece)
                
    def on_new_game(self):
        self.eng.buildNewGame()
        self._update_title()
        self.luck_btn.text = ""
        self.luck_btn.disabled = False
        self.check_stack.clear_widgets()
        self.pieces_stack.clear_widgets()
        self._prepare_game()
        self._update_clue_fields()
        
    def on_luck(self, obj, text) :
        print("on_luck:", obj, text)
        if text != "":
            self.eng.setLuck(float(text))
            self._update_title()

    def on_answer(self, obj):
        # print("on_answer: ", obj, obj.text)
        btn = Button(text=obj.text, 
                font_size='18sp',
                size_hint=(None, 1),
                width=0.04*windowWidth*len(obj.text),
                on_press=self.on_regret)
        self.check_stack.add_widget(btn)
        obj.disabled = True
        self.luck_btn.disabled = True

    def on_regret(self, obj):
        for button in self.pieces_stack.children:
            if button.disabled and obj.text == button.text:
                button.disabled = False
                break
        obj.parent.remove_widget(obj)
        
    def on_check(self):
        word = ''
        for obj in self.check_stack.children:
            word = obj.text + word
        if word == '':
            return
        if self.eng.check(word):
            self._update_title()
            self.solutions_field.text = self.eng.updateSolutions()
            self.check_stack.clear_widgets()
                    
