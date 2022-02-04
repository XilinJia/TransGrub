''''
 * Project: TransGrub
 * Copyright (c) 2020 Xilin Jia <https://github.com/XilinJia>
 * This software is released under the GPLv3 license
 * https://www.gnu.org/licenses/gpl-3.0.en.html
 ''''

from word2word import Word2word
import json
import random
import re
import gzip
import msgpack
import threading

import os

wordGrade = -1
useInflections=False

wordStage = 0

datadir = ''
filename = "GPsetting"
settingsDict = dict()

def save_settings() :
    with gzip.open(datadir + "/" + filename, 'wb') as fso:
        print("save_settings", settingsDict)
        packed = msgpack.packb(settingsDict)
        fso.write(packed)
        fso.close()
        
def load_settings() :
    global settingsDict
    try:
        with gzip.open(datadir + "/" + filename, "rb") as fs:
            byte_data = fs.read()
            settingsDict = msgpack.unpackb(byte_data)
            print("settingsDict: ", settingsDict)
            fs.close()
    except FileNotFoundError:
        print(datadir + filename + " not found")
        pass

    
class GameProvider:
    
    def __init__(self):
        
        self.gradeSize = 200
        self.nGrades = 1
        self.WordGrades = []
        self.nStages = 5
        self.WordStages = list(map(str, list(range(1, self.nStages+1))))

        self.wx2wy = None
        self.lang1 = ''
        self.lang2 = ''
        self.wordStruct = []
        self.baseWordList = []
        self.allwordSet = set()
        self.wordsPlayed = set()
        self.wordsTrashed = set()
        self.stagewords = [set() for x in range(self.nStages)]
        self.gameWords = []
        self.words1 = set()
        self.words2 = set()
        
        self.ratioPlayed = 0.
        
        self._load_settings('')   
        if self.lang1 != '' and self.lang2 != '':
            self.compile_corpus('')
            random.seed(a=random.randint(1, 1000))
            self.stats()
 
    def _load_settings(self, junk):
        load_settings()
        print("_load_settings")
        if "Langs" in settingsDict.keys():
            self.lang1 = settingsDict["Langs"][0]
            self.lang2 = settingsDict["Langs"][1]
        if "WordsPlayed-"+self.lang1 in settingsDict.keys():
            self.wordsPlayed = set(settingsDict["WordsPlayed-"+self.lang1])
        else:
            self.wordsPlayed = set()
        if "WordsTrashed-"+self.lang1 in settingsDict.keys():
            self.wordsTrashed = set(settingsDict["WordsTrashed-"+self.lang1])
        else:
            self.wordsTrashed = set()
            
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
            fw.close()
        print("num base words: ", len(self.wordStruct))
        self.nGrades = int(round(len(self.wordStruct)/self.gradeSize))
        self.WordGrades = list(map(str, list(range(1, self.nGrades+1))))
        print("self.nGrades: ", self.nGrades, self.WordGrades)
        
    def build_stages(self) :
        if self.wordStruct:
            nWords = 0
            wordsGrade = []
            if wordGrade < 0 or wordGrade >= self.nGrades:
                wordsGrade = self.wordStruct
            else:
                # gradeSize = int(len(self.wordStruct)/nGrades)
                if wordGrade<self.nGrades-1:
                    wordsGrade = self.wordStruct[wordGrade*self.gradeSize:(wordGrade+1)*self.gradeSize-1]  
                else:
                    wordsGrade = self.wordStruct[wordGrade*self.gradeSize:]
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

            def custom_key(str):
                return len(str), str.lower() 
                                       
            wordList = sorted(self.allwordSet, key=custom_key)
            stageSize = int(len(wordList) / self.nStages)
            for i in range(self.nStages) :
                self.stagewords[i] = set(wordList[i*stageSize:(i+1)*stageSize-1])
            self.stagewords[self.nStages-1].update(wordList[self.nStages*stageSize-1:])
            
            self.stats()
                
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
        print("num of longer words1: ", len(self.words1))
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
        settingsDict["Langs"] = [self.lang1, self.lang2]
        save_settings()
                        
    def get_words_clues(self, numWords):
        self.gameWords = [''] * numWords
        clueLists = [None] * numWords
        # print("stage=", wordStage, self.stagewords[wordStage])
        for i in range(numWords):
            while True:
                wordsSet = self.stagewords[wordStage] - set(self.gameWords) - self.wordsPlayed - self.wordsTrashed
                print("num of words left: ", len(wordsSet))
                if len(wordsSet) <= 0:
                    break
                randWord = random.choice(tuple(wordsSet))
                wordTrans = self.wx2wy(randWord, n_best=6)
                wordClues = []
                for word in wordTrans:
                    if word in self.words2:
                        wordClues.append(word)
                if len(wordClues) < 3:
                    print(randWord, "has too few clues:", wordClues)
                    self.wordsTrashed.add(randWord)
                    settingsDict["WordsTrashed-"+self.lang1] = list(self.wordsTrashed)
                    continue
                print(randWord, wordClues)
                self.gameWords[i] = randWord
                clueLists[i] = wordClues
                break
        return self.gameWords, clueLists
    
    def stats(self) :
        numInStage = len(self.stagewords[wordStage])
        numUnplayed = len(self.stagewords[wordStage] - self.wordsPlayed - self.wordsTrashed) 
        print("stats numUnplayed, numInStage", numUnplayed, numInStage)             
        self.ratioPlayed = (numInStage - numUnplayed) / numInStage
        settingsDict["WordsPlayed-"+self.lang1] = list(self.wordsPlayed)
        settingsDict["WordsTrashed-"+self.lang1] = list(self.wordsTrashed)


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

    def add_puzzle(self, word, clue) :
        self.puzzles.append(Puzzle(word, clue))
        self.nPuzzles = len(self.puzzles)
        
    def chop(self) :
        for puzzle in self.puzzles:
            wlen = len(puzzle.word)
            ps = min(int(0.5*wlen), random.randint(2, 3))
            for i in range(0, wlen, ps):
                if 0<wlen-i < ps+2:
                    piece = puzzle.word[i:wlen]
                    self.selectPieces.append(piece)
                    break
                piece = puzzle.word[i:i+ps]
                self.selectPieces.append(piece)
        random.shuffle(self.selectPieces)
    
    def prepare(self, words, clueLists) :
        numWords = 0
        for i in range(self.size):
            word = words[i]
            if word == '':
                continue
            numWords += 1
            clues = clueLists[i]
            self.add_puzzle(word, ", ".join(clues[0:3]))            
        return numWords
                
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
        self.inflectFac[False] = 0.9
        self.inflectFac[True] = 1.1
        self.fullness = 1.
        self.score = 500
        
        load_settings()
        if "SCSCs" in settingsDict.keys():
            self.score = int.from_bytes(settingsDict["SCSCs"], byteorder='big', signed=True)
            print("SCSetting:", self.score)
                
    def set_luck(self, luck) :
        self.luckFac = luck
        self.score -= 10 * (luck-1) * self.fullness * self.stageFac[wordStage] * self.gradeFac[wordGrade]
        
    def on_new_game(self, ratio) :
        self.fullness = ratio
        cost = 10 * self.fullness * self.stageFac[wordStage] * self.gradeFac[wordGrade]
        if self.score > cost:
            self.score -= cost
            self.save_score()
            return True
        return False
        
    def on_solve(self) :
        self.score += 15 * self.fullness * self.inflectFac[useInflections] \
            * self.stageFac[wordStage] * self.gradeFac[wordGrade] * self.luckFac
        self.save_score()
        
    def on_hint(self) :
        self.score -= 1 * self.stageFac[wordStage] * self.gradeFac[wordGrade] * self.luckFac / self.inflectFac[useInflections]
        self.save_score()
        
    def save_score(self) :
        four_bytes = int(self.score).to_bytes(4, byteorder='big', signed=True)
        settingsDict["SCSCs"] = four_bytes
        x = threading.Thread(target=save_settings)
        x.start()
        
    
class Engine :

    def __init__(self, ddir, gameSize) :
        global datadir
        datadir = ddir   
        self.gameSize = gameSize
        self._gp = None
        self._game = None
        self._judge = JudgeClass()
        
        self.langChange = False
        self.engChange = False
        
    def nGrades(self) :
        return self._gp.nGrades
    
    def WordGrades(self) :
        return self._gp.WordGrades
    
    def WordStages(self) :
        return self._gp.WordStages

    def getLang1(self) :
        return self._gp.lang1
    
    def getLang2(self) :
        return self._gp.lang2
    
    def setLang1(self, lang) :
        self._gp.lang1 = lang
        self.langChange = True

    def setLang2(self, lang) :
        self._gp.lang2 = lang
        self.langChange = True
        
    def buildProvider(self) :
        self._gp = GameProvider()
        self.langChange = False
        self.engChange = False

    def isReady(self) :
        return self._gp.is_ready()
    
    def titleText(self) :
        text = self.getLang2() + ">>" + self.getLang1()
        ti = ''
        if useInflections:
            ti = 'I-'
        text += ": " + ti + str(wordGrade+1) + "-" + str(wordStage+1) + " *" + str(self._judge.luckFac) + "\n"
        text += str(int(self._judge.score))
        return text
    
    def saveSettings(self) :
        self._gp.save_settings()
        
    def listLangs(self) :
        langs = set()
        for f_name in os.listdir(datadir):
            if f_name.endswith('.pkl'):
                print(f_name[:-4])
                langs.add(f_name[:-4])
        return langs
    
    def deleteLangs(self, selected) :
        for fname in selected:
            data_file = datadir + "/" + fname + ".pkl"
            if os.path.isfile(data_file):
                # os.remove(data_file)
                print(data_file)
        
    def getPoints(self) :
        self._judge.score += 500
        
    def setStage(self, val) :
        global wordStage
        wordStage = val
        self.engChange = True
        self._gp.stats()

    def setGrade(self, val) :
        global wordGrade
        wordGrade = val
        self._gp.build_stages()
        self.engChange = True
        self._gp.stats()

    def setInflection(self, val) :
        global useInflections
        useInflections = val
        print("setInflection: ", useInflections)
        self._gp.build_stages()
        self.engChange = True
        self._gp.stats()

    def getWordPieces(self) :
        return self._game.selectPieces
        
    def getHint(self) :
        self._judge.on_hint()
        return self._game.get_hint()

    def buildNewGame(self) :
        self._game = Game(self.gameSize)
        words, clueLists = self._gp.get_words_clues(self.gameSize)
        numWords = self._game.prepare(words, clueLists)        
        self._judge.set_luck(1.)
        if self._judge.on_new_game(numWords/self.gameSize):
            self._game.chop()
            return True
        return False
    
    def setLuck(self, luck) :
        self._judge.set_luck(luck)
       
    def check(self, word) :
        checked = self._game.check(word)
        if self._game.is_solved():
            self._gp.wordsPlayed |= set(self._gp.gameWords)
            self._gp.stats()
            self._judge.on_solve()            
        return checked
    
    def getRatioPlayed(self) :
        return self._gp.ratioPlayed
        
    def updateClueFields(self) :
        clues = ''
        solutions = ''
        ii = 1
        for puzzle in self._game.puzzles:
            if clues != '':
                clues += '\n'
                solutions += '\n'
            clues += 'W' + str(ii) + ':  ' + puzzle.clue
            solutions += puzzle.solution
            ii += 1
        return clues, solutions
    
    def updateSolutions(self) :
        solutions = ''
        for puzzle in self._game.puzzles:
            solutions += puzzle.solution + '\n'
        return solutions[:-1]