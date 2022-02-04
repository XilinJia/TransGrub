# 
#  Project: TransGrub
#  Copyright (c) 2020 Xilin Jia <https://github.com/XilinJia>
#  This software is released under the GPLv3 license
#  https://www.gnu.org/licenses/gpl-3.0.en.html
#  

from word2word import Word2word
import json
import random
import re
import gzip
import msgpack

nGrades = 3
WordGrades = list(map(str, list(range(1, nGrades+1))))
wordGrade = -1
useInflections=False

nStages = 5
WordStages = list(map(str, list(range(1, nStages+1))))
wordStage = 0

datadir = ''

class GameProvider:
    
    def __init__(self):
        self.wx2wy = None
        self.lang1 = ''
        self.lang2 = ''
        self.wordStruct = []
        self.baseWordList = []
        self.allwordSet = set()
        self.stagewords = [set() for x in range(len(WordStages))]
        self.words1 = set()
        self.words2 = set()
        
        self._load_settings('')   
        if self.lang1 != '' and self.lang2 != '':
            self.compile_corpus('')
            random.seed(a=random.randint(1, 1000))
 
    def _load_settings(self, junk):
        try:
            with open(datadir + "/GPsetting.txt") as fs:
                prevLangs = json.load(fs)
                print(prevLangs)
                self.lang1 = prevLangs[0]
                self.lang2 = prevLangs[1]
                fs.close()
        except FileNotFoundError:
            print(datadir + "/GPsetting.txt not found")
            pass

    def is_ready(self) :
        return self.lang1 != '' and self.lang2 != ''

    def is_word_valid(self, word, lang) :
        if lang in ['en', 'fr', 'es', 'it']:
            return 4 <= len(word) < 14  and not (re.search('[A-Z]|[0-9]', word)) and \
                not (re.search('[\,\.\-\'\/\´]', word))
        elif lang in ['de', 'ru', 'ar']:
            return 4 <= len(word) < 14  and not (re.search('[0-9]', word)) and \
                not (re.search('[\,\.\-\'\/\´]', word))
        elif lang in ['zh_cn', 'zh_tw']:
            return not (re.search('[a-z]|[A-Z]|[0-9]', word)) and \
                    not (re.search('[\,\.\-\'\/\´\:]', word))
        return False
         
    def _loadWords_gmsg(self) :
        print("lang1:", self.lang1)
        with gzip.open(self.lang1 + "ws.gmsg", 'rb') as fw:
            byte_data = fw.read()
            self.wordStruct = msgpack.unpackb(byte_data)
            print("num base words: ", len(self.wordStruct))
            fw.close()
        
    def build_stages(self) :
        if self.wordStruct:
            nWords = 0
            wordsGrade = []
            if wordGrade < 0 or wordGrade >= nGrades:
                wordsGrade = self.wordStruct
            else:
                gradeSize = int(len(self.wordStruct)/nGrades)
                if wordGrade<nGrades-1:
                    wordsGrade = self.wordStruct[wordGrade*gradeSize:(wordGrade+1)*gradeSize-1]  
                else:
                    wordsGrade = self.wordStruct[wordGrade*gradeSize:]
            self.allwordSet = set()
            for wb in wordsGrade:
                word = wb[0].strip()
                if word in self.words1:
                    nWords += 1
                    self.allwordSet.add(word)
                # else:
                #     print("word discarded:", word)
                if useInflections:
                    for wf in wb[1]:
                        wordf = wf.strip()
                        if wordf in self.words1:
                            nWords += 1
                            self.allwordSet.add(wordf)
                            
            wordList = sorted(list(self.allwordSet), key=len)
            stageSize = int(len(wordList) / nStages)
            for i in range(nStages) :
                self.stagewords[i] = set(wordList[i*stageSize:(i+1)*stageSize-1])
            self.stagewords[nStages-1].update(wordList[nStages*stageSize-1:])
                
            print("B nWords: ", nWords, len(self.stagewords[0]), len(self.stagewords[1]), 
                  len(self.stagewords[2]), len(self.stagewords[3]), len(self.stagewords[4]))
       
    def compile_corpus(self, junk):
        self.wx2wy = Word2word(self.lang1, self.lang2, custom_savedir=datadir)
        print("x2y: ", self.wx2wy.compute_summary())
        for word in self.wx2wy.word2x:
            word = word.strip()
            # print(word)
            if self.is_word_valid(word, self.lang1) :
                self.words1.add(word.strip())
        print("num of longer words1: ", len(self.words1), len(WordStages))
        # for word in self.words1:
            # print(word, ": ", self.wx2wy(word, n_best=5))
        # for word in self.wx2wy.y2word.values():
        #     print(word)
        
        self._loadWords_gmsg()
        self.build_stages()
        
        for word in self.wx2wy.y2word.values():
            word = word.strip()
            if self.is_word_valid(word, self.lang2) :
                    self.words2.add(word.strip())
        print("num of longer words2: ", len(self.words2))
        self.save_settings()
        
    def save_settings(self) :
        with open(datadir + "/GPsetting.txt", 'w+') as fso:
            json.dump([self.lang1, self.lang2], fso)
            fso.close()
            
    def get_word_and_clues(self):
        while True:
            randWord = random.choice(tuple(self.stagewords[wordStage]))
            wordTrans = self.wx2wy(randWord, n_best=6)
            wordClues = []
            for word in wordTrans:
                if word in self.words2:
                    wordClues.append(word)
            if self.lang2 != 'zh_cn' and len(wordClues) < 3:
                continue
            return randWord, wordClues
       

class Puzzle:
    
    def __init__(self, word, clue):
        self.word = word
        self.clue = clue
        self.solution = 'X' * len(word)
        self.solved = False
        

class Game:
    
    def __init__(self, size):
        self.size = size
        self.nPuzzles = 0
        self.puzzles = []
        self.selectPieces = []     

    def add_puzzel(self, word, clue) :
        self.puzzles.append(Puzzle(word, clue))
        self.nPuzzles = len(self.puzzles)
        
    def build(self) :
        for puzzle in self.puzzles:
            wlen = len(puzzle.word)
            ps = min(int(0.5*wlen), random.randint(2, 3))
            for i in range(0, wlen, ps):
                if 0<wlen-i < ps+2:
                    piece = puzzle.word[i:wlen]
                    # print(piece)
                    self.selectPieces.append(piece)
                    break
                piece = puzzle.word[i:i+ps]
                # print(piece)
                self.selectPieces.append(piece)
        random.shuffle(self.selectPieces)
    
    def prepare(self, gp) :
        ii = 0
        while ii < self.size:
            randWord, wordClues = gp.get_word_and_clues()  
            if self.is_word_in(randWord):
                print("game prepare repeating word", randWord)
                continue          
            print(randWord, ": ", wordClues)
            ii += 1
            self.add_puzzel(randWord, ", ".join(wordClues[0:3]))
        
    def is_word_in(self, word) :
        for puzzle in self.puzzles:
            if word == puzzle.word:
                return True
        return False
        
    def check(self, word) :
        for puzzle in self.puzzles:
            # print(puzzle.word)
            if not puzzle.solved and word == puzzle.word:
                puzzle.solution = word
                puzzle.solved = True
                return puzzle.solved
        return False
    
    def is_solved(self) :
        for puzzle in self.puzzles:
            if not puzzle.solved:
                return False
        return True
            
    def get_hint(self) :
        pieces = set()
        for puzzle in self.puzzles:
            if not puzzle.solved:
                for piece in self.selectPieces:
                    if piece in puzzle.word:
                        pieces.add(piece)
                return pieces
        return None
    

class JudgeClass :
    
    def __init__(self) :
        self.luckFac = 1
        self.gradeFac = [1., 1.1, 1.2, 1.3]
        self.stageFac = [1., 1.1, 1.2, 1.3, 1.4, 1.6, 1.8]
        self.inflectFac = dict()
        self.inflectFac[False] = 0.8
        self.inflectFac[True] = 1.0
        self.score = 500
        try:
            with open("SCsetting.bin", "rb") as fs:
                num=fs.read()
                self.score = int.from_bytes(num, byteorder='big', signed=True)
                print("SCSetting:", self.score)
                fs.close()
        except FileNotFoundError:
            pass
                
    def set_luck(self, luck) :
        self.luckFac = luck
        
    def on_new_game(self) :
        self.score -= 10 * self.stageFac[wordStage] * self.gradeFac[wordGrade] * self.luckFac
        self.save_score()
        
    def on_solve(self) :
        self.score += 15 * self.inflectFac[useInflections] * self.stageFac[wordStage] * self.gradeFac[wordGrade] * self.luckFac
        self.save_score()
        
    def on_hint(self) :
        self.score -= 1 * self.stageFac[wordStage] * self.gradeFac[wordGrade] * self.luckFac / self.inflectFac[useInflections]
        self.save_score()
        
    def save_score(self) :
        with open("SCsetting.bin", 'wb+') as fso:
            four_bytes = int(self.score).to_bytes(4, byteorder='big', signed=True)
            fso.write(four_bytes)
            fso.close()
        
    
class Engine :

    def __init__(self, ddir) :
        global datadir
        datadir = ddir   
        self.gp = None
        self.game = None
        self.judge = JudgeClass()
        
        self.langChange = False
        self.engChange = False

    def getLang1(self) :
        return self.gp.lang1
    
    def getLang2(self) :
        return self.gp.lang2
    
    def setLang1(self, lang) :
        self.gp.lang1 = lang
        self.langChange = True

    def setLang2(self, lang) :
        self.gp.lang2 = lang
        self.langChange = True
        
    def buildProvider(self) :
        self.gp = GameProvider()
        self.langChange = False
        self.engChange = False

    def isReady(self) :
        return self.gp.is_ready()
    
    def titleText(self) :
        # print("titleText: wordStage = ", wordStage)
        text = self.getLang2() + ">>" + self.getLang1()
        ti = ''
        if useInflections:
            ti = 'I-'
        text += ": " + ti + str(wordGrade+1) + "-" + str(wordStage+1) + " *" + str(self.judge.luckFac) + "\n"
        text += str(int(self.judge.score))
        return text
    
    def saveSettings(self) :
        self.gp.save_settings()

    def getPoints(self) :
        self.judge.score += 500
        
    def setStage(self, val) :
        global wordStage
        wordStage = val
        self.engChange = True

    def setGrade(self, val) :
        global wordGrade
        wordGrade = val
        self.gp.build_stages()
        self.engChange = True

    def setInflection(self, val) :
        global useInflections
        useInflections = val
        print("setInflection: ", useInflections)
        self.gp.build_stages()
        self.engChange = True

    def prepareGame(self) :
        self.game = Game(7)
        self.game.prepare(self.gp)        
        self.game.build()

    def getWordPieces(self) :
        return self.game.selectPieces
        
    def getHint(self) :
        self.judge.on_hint()
        return self.game.get_hint()

    def buildNewGame(self) :
        self.judge.on_new_game()
        self.judge.set_luck(1.)

    def setLuck(self, luck) :
        self.judge.set_luck(luck)
       
    def check(self, word) :
        checked = self.game.check(word)
        if self.game.is_solved():
            self.judge.on_solve()            
        return checked
        
    def updateClueFields(self) :
        clues = ''
        solutions = ''
        ii = 1
        for puzzle in self.game.puzzles:
            if clues != '':
                clues += '\n'
                solutions += '\n'
            clues += 'W' + str(ii) + ':  ' + puzzle.clue
            solutions += puzzle.solution
            ii += 1
        return clues, solutions
    
    def updateSolutions(self) :
        solutions = ''
        for puzzle in self.game.puzzles:
            solutions += puzzle.solution + '\n'
        return solutions[:-1]