import cligen
import illwill
import illwillWidgets
import times

import sound.sound
import strutils
import os

const updateTimeout = 100

type
  ExerciseKind = enum
    TRAIN, REST
  Training = ref object
    paused: bool
    # train: bool
    trainingScript: TrainingScript
    tb: TerminalBuffer
    infoBox: InfoBox
    durationBox: InfoBox
    chooseBox: ChooseBox
    currentExcerciseIdx: int
    progressBar: ProgressBar
    musicTrain: Sound
    musicRest: Sound
    musicDone: Sound
    elapsed: float
    exercises: seq[TrainingExercise]
  TrainingScriptLine = seq[string]
  TrainingExercise = object
    name: string
    duration: float
    kind: ExerciseKind
  TrainingScript = object
    lines: seq[TrainingScriptLine]
    scriptPath: string

proc lex(str: string): TrainingScript =
  result.scriptPath = str
  for rawLine in lines(result.scriptPath):
    let line = rawLine.strip(leading = true, trailing = true)
    if line.len == 0: continue
    if line.startsWith("#"): continue
    let trainingScriptLine: TrainingScriptLine = line.split(" ")
    result.lines.add trainingScriptLine

proc parse(training: Training, script: TrainingScript) =
  for line in script.lines:
    case line[0]
    of "trainmusic":
      echo "LOAD TRAINMUSIC", line[1]
      training.musicTrain = newSoundWithURL("file://" & getAppDir() / line[1])
    of "restmusic":
      echo "LOAD RESTMUSIC", line[1]
      training.musicRest = newSoundWithURL("file://" & getAppDir() / line[1])
    of "donemusic":
      echo "LOAD DONEMUSIC", line[1]
      training.musicDone = newSoundWithURL("file://" & getAppDir() / line[1])
    of "train":
      echo "ADD EXERCISE", line[2]
      let elem = TrainingExercise(
        duration: line[1].parseFloat,
        name: line[2],
        kind: TRAIN
      )
      training.exercises.add elem
    of "rest":
      echo "ADD REST", line[1]
      let elem = TrainingExercise(
        duration: line[1].parseFloat,
        name: "rest",
        kind: REST
      )
      training.exercises.add elem

proc fillChoosebox(training: Training) =
  for exercise in training.exercises:
    training.chooseBox.add exercise.name & " ===>  " & $exercise.duration

proc currentExcersice(training: Training): TrainingExercise =
  return training.exercises[training.currentExcerciseIdx]

proc stopAllMusic(training: Training) =
  training.musicDone.stop()
  training.musicTrain.stop()
  training.musicRest.stop()

proc next(training: Training) =
  training.stopAllMusic()
  if training.currentExcerciseIdx == training.exercises.len - 1:
    training.paused = true
    training.musicDone.play()
    return
  training.currentExcerciseIdx += 1
  training.chooseBox.choosenidx = training.currentExcerciseIdx
  training.elapsed = 0.0
  training.progressBar.maxValue = training.currentExcersice().duration
  training.progressBar.value = 0.0
  case training.currentExcersice().kind
  of TRAIN: training.musicTrain.play()
  of REST: training.musicRest.play()

proc newTraining(str: string): Training =
  result = Training()
  result.currentExcerciseIdx = -1
  result.elapsed = 0.0
  result.paused = false
  # result.train = false
  result.trainingScript = lex(str)
  result.parse(result.trainingScript)
  result.tb = newTerminalBuffer(terminalWidth(), terminalHeight())
  result.infoBox = newInfoBox("", 0 ,0, terminalWidth())
  result.durationBox = newInfoBox("FOO", 0 ,terminalHeight() - 2, terminalWidth())
  result.chooseBox = newChooseBox(@[], 0, 1, terminalWidth() - 2, terminalHeight() - 4)
  result.progressBar = newProgressBar("FOO", 0, terminalHeight() - 1, terminalWidth(), 50, 100)
  result.musicRest.setLooping(true)
  result.musicTrain.setLooping(true)
  result.fillChoosebox()
  result.next()

proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

proc isExcersiseDone(training: Training): bool =
  return training.elapsed >= training.exercises[training.currentExcerciseIdx].duration

proc input(training: Training) =
  var key = getKey()
  case key
  of Key.Escape: exitProc()
  of Key.Space: training.paused = not training.paused
  # of Key.Enter: training.train = not training.train
  else: discard

proc formatDuration(training: Training): string =
  return $training.elapsed.int & " / " & $training.currentExcersice().duration.int

proc render(training: Training) =
  # if training.train:
  #   training.tb.setBackgroundColor(bgRed)
  # else:
  #   training.tb.setBackgroundColor(bgGreen)
  training.tb.clear(" ")
  if training.paused:
    training.infoBox.text = "PAUSED " & training.formatDuration()
  else:
    training.infoBox.text = "RUNNING " & training.formatDuration()
  training.durationBox.text = training.formatDuration()
  training.tb.render(training.infoBox)
  training.tb.render(training.durationBox)
  training.tb.render(training.chooseBox)
  training.tb.render(training.progressBar)
  training.tb.display()

illwillInit(fullscreen=true)
setControlCHook(exitProc)
hideCursor()
var training = newTraining(getAppDir() / "mockup.txt")

while true:
  let loopStartTime = epochTime()
  training.input()
  training.render()
  sleep(updateTimeout)
  if training.paused:
    continue
  training.elapsed += epochTime() - loopStartTime
  if training.isExcersiseDone():
    training.next()
  training.progressBar.value = training.elapsed.float



