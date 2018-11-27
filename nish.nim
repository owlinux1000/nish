import os
import posix
import system
import ospaths
import tables
from strutils import split

echo "Welcome to nish :)"

const PATH = ["bin", "sbin", ospaths.joinPath("usr", "bin"), ospaths.joinPath("usr", "local", "bin")]

proc cmd_cd(path:string) =
  # If path is null, change the current directory to $HOME
  if path == "":
    let uid = posix.getuid()
    let me = posix.getpwuid(uid)
    discard posix.chdir(me.pw_dir)
    if posix.errno != 0:
      echo me.pw_dir
      echo posix.strerror(posix.errno)
      posix.errno = 0
  elif os.dirExists(path):
    discard posix.chdir(path)
    if posix.errno != 0:
      echo posix.strerror(posix.errno)
      posix.errno = 0

proc cmd_exit(_: string) =
  posix.exitnow(0)

const BUILTIN_COMMANDS = {
  "cd": cmd_cd,
  "exit": cmd_exit
}.toTable

proc make_prompt():cstring =
  
  let uid = posix.getuid()
  let me = posix.getpwuid(uid)
  
  var cwd_buf: cstring
  posix.errno = 0
  let cwd = posix.getcwd(cwd_buf, 100)
  if posix.errno != 0:
    echo posix.strerror(posix.errno)
  
  var prompt: string = ""
  prompt &= me.pw_name
  prompt &= "@"
  prompt &= " "
  prompt &= cwd
  prompt &= ": "

  return prompt
  

while true:

  posix.errno = 0
  
  stdout.write make_prompt()
  let input = readLine(stdin)
  
  # Just only send '\n'
  if input == "":
    continue
    
  var not_found = true    
  let input_splited = input.split(" ")
  
  if BUILTIN_COMMANDS.hasKey(input_splited[0]):
    case input_splited[0]:
      of "cd":
        if len(input_splited) == 1:
          BUILTIN_COMMANDS[input_splited[0]]("")
        else:
          BUILTIN_COMMANDS[input_splited[0]](input_splited[1])
      of "exit":
        BUILTIN_COMMANDS[input_splited[0]]("")
        
  else:
    for path in PATH:
      let cmd = ospaths.joinPath("/", path, input_splited[0])
      if os.fileExists(cmd):
        not_found = false
        let pid = posix.fork()
        if pid < 0:
          echo posix.strerror(posix.errno)
        elif pid > 0:
          var status: cint = 1
          var ret = waitpid(pid, status, 0)
          echo ret
        else:
          let arg = system.allocCStringArray(input_splited[0..len(input_splited)-1])
          discard posix.execv(cmd, arg)
          deallocCStringArray(arg)
        break
      
  if not_found:
    echo input_splited[0], ": command not found"
