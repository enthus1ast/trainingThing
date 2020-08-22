import times, strutils, sequtils, os
import sound.sound
import illwill, illwillWidgets

const updateTimeout = 100
const ascii = @[
"""
  o
 /|\
 / \""",
"""
\ o /
  |
 / \"""
]

type
  ExerciseKind = enum
    TRAIN, REST
  Training = ref object
    paused: bool
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
    musicNextRound: Sound
    elapsed: float
    exercises: seq[TrainingExercise]
    repetitions: int
    totalTrainingSeconds: float
    asciiArt: InfoBox
    defaultBackgroundColor: BackgroundColor
    defaultForegroundColor: ForegroundColor
    currentTerminalSize: tuple[w: int, h: int]
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
    of "nextroundmusic":
      echo "LOAD NEXTROUNDMUSIC", line[1]
      training.musicNextRound = newSoundWithURL("file://" & getAppDir() / line[1])
    of "train":
      echo "ADD EXERCISE", line[2]
      let elem = TrainingExercise(
        duration: line[1].parseFloat,
        name: line[2..^1].join(" "),
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
    of "repetitions":
      training.repetitions = line[1].parseInt

proc fillChoosebox(training: Training) =
  for exercise in training.exercises:
    training.chooseBox.add ($exercise.duration).align(6) & " " & exercise.name

proc currentExcersice(training: Training): TrainingExercise =
  return training.exercises[training.currentExcerciseIdx]

proc stopAllMusic(training: Training) =
  training.musicDone.stop()
  training.musicTrain.stop()
  training.musicRest.stop()
  training.musicNextRound.stop()

proc next(training: Training) =
  training.stopAllMusic()
  if training.currentExcerciseIdx == training.exercises.len - 1:
    if training.repetitions > 0:
      training.musicNextRound.play()
      ## Is playing is not exported :(
      # while training.musicNextRound.isPlaying():
      #   sleep(10)
      sleep(2500) # TODO find a way to test if musicNextRound still plays
      training.currentExcerciseIdx = -1
      training.repetitions -= 1
    else:
      training.paused = true
      training.musicDone.play()
      return
  training.currentExcerciseIdx += 1
  training.chooseBox.choosenidx = training.currentExcerciseIdx
  training.elapsed = 0.0
  training.progressBar.maxValue = training.currentExcersice().duration
  training.progressBar.value = 0.0
  training.progressBar.text = training.currentExcersice().name
  case training.currentExcersice().kind
  of TRAIN: training.musicTrain.play()
  of REST: training.musicRest.play()

proc newTraining(path: string): Training =
  if not path.fileExists:
    echo "Training script file not exist: ", path
    quit()
  result = Training()
  result.currentTerminalSize = terminalSize()
  result.repetitions = 0
  result.currentExcerciseIdx = -1
  result.elapsed = 0.0
  result.paused = false
  result.trainingScript = lex(path)
  result.parse(result.trainingScript)
  result.tb = newTerminalBuffer(terminalWidth(), terminalHeight())
  result.defaultBackgroundColor = result.tb.getBackgroundColor()
  result.defaultForegroundColor = result.tb.getForegroundColor()
  result.infoBox = newInfoBox("", 0 ,0, terminalWidth())
  result.durationBox = newInfoBox("", 0 ,terminalHeight() - 2, terminalWidth())
  result.chooseBox = newChooseBox(@[], 0, 1, terminalWidth() - 2, terminalHeight() - 4)
  result.progressBar = newProgressBar("", 0, terminalHeight() - 1, terminalWidth(), 50, 100)
  result.asciiArt = newInfoBox("", terminalWidth()-5, 0, 5, 0)
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

proc startCorrectMusic(training: Training) =
  case training.currentExcersice.kind
  of REST: training.musicRest.play()
  of TRAIN: training.musicTrain.play()

proc input(training: Training) =
  var key = getKey()
  case key
  of Key.Escape:
    training.tb.setBackgroundColor(training.defaultBackgroundColor)
    training.tb.setForegroundColor(training.defaultForegroundColor)
    training.tb.clear(" ")
    training.tb.display()
    exitProc()
  of Key.Space:
    training.paused = not training.paused
    if training.paused:
      training.stopAllMusic()
    else:
      training.startCorrectMusic()
  of Key.Enter:
    training.next()
  of Key.Backspace:
    training.currentExcerciseIdx = clamp(-1, training.currentExcerciseIdx - 2, int.high)
    training.next()
  else: discard

proc resizeHandler(training: Training) =
  if terminalSize() != training.currentTerminalSize:
    training.tb = newTerminalBuffer(terminalWidth(), terminalHeight())
    training.progressBar.y = terminalHeight() - 1
    training.progressBar.l = terminalWidth()
    training.chooseBox.w = terminalWidth() - 2
    training.asciiArt.x = terminalWidth()- 5
    training.durationBox.y = terminalHeight() - 2
    training.durationBox.w = terminalWidth()
    # terminalWidth()

proc formatDuration(training: Training): string =
  return
    $training.elapsed.int & " / " &
    $training.currentExcersice().duration.int &
    "   REPETITIONS: " & $training.repetitions &
    "   TOTAL TRAINING TIME: " & $initDuration(seconds=training.totalTrainingSeconds.int)

proc render(training: Training) =
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
  training.tb.render(training.asciiArt)
  training.tb.display()

proc main() =
  illwillInit(fullscreen=true)
  setControlCHook(exitProc)
  hideCursor()
  var scriptPath = getAppDir() / "mockup.txt"
  if paramCount() > 0:
    scriptPath = paramStr(1)
  var training = newTraining(scriptPath)
  while true:
    let loopStartTime = epochTime()
    training.input()
    training.resizeHandler()
    try:
      training.render()
    except:
      echo "could not render, maybe terminal to small?"
      sleep(2000)
      continue
    sleep(updateTimeout)
    if training.paused:
      continue
    let loopTime = epochTime() - loopStartTime
    training.elapsed += loopTime
    training.totalTrainingSeconds += loopTime
    if training.isExcersiseDone():
      training.next()
    training.progressBar.value = training.elapsed.float.clamp(0, float.high)
    if training.currentExcersice.kind == TRAIN:
      if training.totalTrainingSeconds.int mod 2 == 0:
        training.asciiArt.text = ascii[0]
      else:
        training.asciiArt.text = ascii[1]
    else:
      training.asciiArt.text = ""

when isMainModule:
  main()