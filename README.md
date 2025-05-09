# Fix for steam launch on Windows 10.

If you're having trouble with Steam can't wait for SteamWebHelper processes and failing to start, you can use this simple script.

TLDR: In some cases Steam timeout is not enough for waiting SteamWebHelper processes. It cuts out waiting and shows error message. This fix can help you do the trick for operating Steam and SteamWebHelper processes to get Steam launch without troubles.

Files:
- start-steam.bat - main script for launching powershell code. You should put it in one folder with steam_manager.ps1 or change path SCRIPT_DIR variable.
- steam_manager.ps1 - main logic for launching Steam. It launches Steam.exe, waiting for 3 processes of SteamWebHelper.exe, then suspending Steam.exe process until fourth SteamWebHelper is present, then it resumes Steam.exe process and Steam launches normally
