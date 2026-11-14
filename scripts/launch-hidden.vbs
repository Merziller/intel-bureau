' Start the Intel Bureau workbench with no console window (double-click, or called from the .bat).
' ASCII only on purpose: this file is parsed by Windows Script Host under any code page.
Option Explicit
Dim sh, fso, here, args, i, cmd
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
here = fso.GetParentFolderName(WScript.ScriptFullName)
args = ""
For i = 0 To WScript.Arguments.Count - 1
  args = args & " " & WScript.Arguments(i)
Next
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & here & "\start.ps1"" -Gui" & args
sh.Run cmd, 0, False
