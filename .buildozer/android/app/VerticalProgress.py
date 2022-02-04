'''
Project: TransGrub
Copyright (c) 2020 Xilin Jia <https://github.com/XilinJia>
This software is released under the GPLv3 license
https://www.gnu.org/licenses/gpl-3.0.en.html
'''


from kivy.uix.progressbar import ProgressBar
from kivy.graphics import Color, Rectangle

class VerticalProgressBar(ProgressBar):

    def __init__(self, **kwargs):
        # self.size = (30,30)
        self.max = 100
        super(VerticalProgressBar, self).__init__(**kwargs)
        
        self.bind(pos=self.update_rect, size=self.update_rect)

    def update_rect(self, instance, value):
        self.draw()

    def draw(self):

        with self.canvas:
            
            # Empty canvas instructions
            self.canvas.clear()

            # Draw no-progress rectangle
            Color(0.26, 0.26, 0.26)
            Rectangle(pos=self.pos, size=self.size)

            Color(1, 0, 0)
            Rectangle(pos=self.pos, size=(self.size[0], self.value_normalized * self.size[1]))

    def set_value(self, value):
        # Update the progress bar value
        self.value = value

        # Draw all the elements
        self.draw()
 
