# AutoHotkey Release

This script handles most of the work of preparing [AutoHotkey](https://github.com/Lexikos/AutoHotkey_L) for release:

  - Bump version number
  - Build the binaries
  - Update documentation (changelog and version number)
  - Compile latest Ahk2Exe
  - Build the installer and zips
  - Create GitHub release and upload installer

This script currently runs only on AutoHotkey v1.1.

## Setting it up

The script depends on a specific directory structure, which can be replicated by creating a directory, making it the current directory and then running the following commands:
```
git clone https://github.com/Lexikos/AutoHotkey_L.git AutoHotkey_L
git clone https://github.com/Lexikos/AutoHotkey_L-Docs.git Docs\v1
git clone https://github.com/Lexikos/AutoHotkey_L-Docs.git -b v2 Docs\v2
git clone https://github.com/fincs/Ahk2Exe.git Ahk2Exe
git clone https://github.com/Lexikos/AutoHotkey-Release.git release
```
If you want the script to submit releases to GitHub, you should clone from your own fork of the AutoHotkey_L repository. The script will attempt to push changes to "origin" or the default remote (of AutoHotkey_L and AutoHotkey_L-Docs), which will fail if you clone someone else's repositories.

### Dependencies

This script utilises the following tools:

  - [Visual Studio 2015](https://www.visualstudio.com/vs/community/) for building AutoHotkey (Community Edition is fine) 
    Other versions could be used by replacing the VS140COMNTOOLS env var used in Build.ahk, or perhaps by setting it to the equivalent variable of a different version.
  - [Git](https://git-scm.com/): Must be in PATH. This is probably done by the Git installer. The version of Git installed by Visual Studio also works.
  - [7-zip](http://www.7-zip.org/download.html): Either install it or set its path in release.ini (see *Configuring*). If absent, no zips will be created.
  - [PSFTP](http://www.chiark.greenend.org.uk/~sgtatham/putty/) for uploading the installer and zips (see *Configuring*). PuTTY.exe is probably also required for configuring the connection settings, but isn't used directly. If PSFTP is absent, an FTP script will be created but nothing will be uploaded.
  - hhc.exe for compiling the help file.  This file is expected to be in `Program Files\HTML Help Workshop`.  It is probably installed there by Visual Studio.

For building the installer, the following are also required:

  - [7-zip Extra](http://www.7-zip.org/download.html) package extracted to `release\installer\tools\7z`
  - [Resource Hacker](http://www.angusj.com/resourcehacker/) (ResourceHacker.exe) in `release\installer\tools` or `Program Files\Resource Hacker`.


### Configuring

`release.ini` in the same directory as `_RELEASE.ahk` may contain the following settings:
```
[Tools]
Editor=
PSFTP=
SevenZip=

[GitHub]
owner=
repo=
token=

[FTP]
Prefix=
```
Editor is the command line for an external HTML or text editor. It defaults to notepad.exe. The path of the temporary HTML file containing the changelog entry is appended to this.

PSFTP is the path of PSFTP.exe, used to execute FTP scripts. It defaults to `%A_ProgramFiles%\PuTTY\psftp.exe`. This script currently doesn't specify the remote server; it should be configured in the default PuTTY session, which is also used by PSFTP. 

SevenZip is the path of 7z.exe, used for making zips. It defaults to the path read from `HKLM\Software\7-Zip`.

GitHub contains your GitHub username, repository name and authentication token for submitting GitHub releases. If not set, the GitHub release step will be skipped.

FTP Prefix becomes the prefix of all remote paths when uploading files.

## Using the script

AutoHotkey_L should contain source files in the desired state for building, with no unstaged changes (i.e. if you made changes, commit them first).

Once you've read up on what the script does, just run `_RELEASE.ahk`.

If a setup exe or zip is created, it is put into `release\files\%version%`.

If any files are to be uploaded, the FTP script is written to `release\files\%version%\ftp.txt`. If PSFTP is found, the FTP script is executed automatically and renamed.

### Branches

This script currently performs different actions depending on which branch is checked out.

**master**: This is the v1 branch.

  - The script optionally executes all release steps.
  - `Docs\v1` optionally contains the v1 documentation repository. If absent, the documentation and installer will not be built.
  - `Ahk2Exe` contains the Ahk2Exe repository. If absent, Ahk2Exe will not be updated. The installer will fail to build if `release\installer\include\Compiler\Ahk2Exe.exe` is also absent.
  - The version number is updated in `ahkversion.h` and committed.

**alpha**: This is the v2-alpha branch.

  - The script builds and zips the Unicode binaries and the help file.
  - `Docs\v2` optionally contains the v2 documentation repository. The script merely updates the version number and builds the offline help file for inclusion in the zips. If the documentation is not found, zipping will probably fail.
  - The version number is set in `ahkversion.h` temporarily and reverted when the script exits. 
  - Ahk2Exe itself is omitted, but Ahk2Exe v1 can be used with v2 binaries.
  - No installer is built.
  - No GitHub release is created.

**edge**: This is the "for-testing" v1 branch.

  - The script builds and zips all binaries.
  - The version number is generated automatically based on `git describe`.
  - The version number is set in `ahkversion.h` temporarily and reverted when the script exits. 
  - Ahk2Exe itself is omitted.
  - No installer is built.
  - No GitHub release is created.

### Commit?

If there are new commits since the last tag (and this isn't the *edge* branch), running the script will show a *Commit?* prompt. Select *Yes* to bump the version number and proceed with the full release process.

**Note:** This entire step will be skipped if the HEAD commit is already tagged.

A prompt is shown to enter the version number. The default version number is calculated by incrementing the last group of digits in the last tag. For the *alpha* branch, a dash and the first 7 characters of the commit ID are appended to the version number.

For the *master* branch, the version number change is committed automatically. For the *master* branch and *alpha* branch, a tag is created with the letter `v` followed by the version number.

If `Docs\v1` (for *master*) or `Docs\v2` (for *alpha*) exists, the version number in `AutoHotkey.htm` is updated. For *master*, changelog entries are generated based on `git log`, and an editor (see *Configuring*) is launched for making final touches. The script waits for the editor process to close before inserting the changelog entries into the documentation.

The script writes the version number to `release\temp\version.txt` and adds it to the FTP script for upload to `/download/1.1/version.txt` or `/download/2.0/version.txt`.

If `index.htm` and/or `.htaccess` exist in `release\files\web`, they are updated with the version number and rewrite rules for the download URLs. See _RELEASE.ahk for the specific markers it looks for.

For the *edge* branch, the script executes `git push -f origin edge:edge`, which force-updates the remote *edge* branch. For other branches, the script executes `git push` and (if a tag was created) `git push origin tag v%version%`.

### Build?

This is done automatically if the script is *committing*.

If the script is not committing, you may enter a version number. The default version number is based on the last tag name or `git describe`. `ahkversion.h` is modified temporarily for the build and reverted when the script exits.

The Release and Self-contained project configurations are built for both platforms. For v1.x, the mbcs configurations for Win32 are also built. The binaries are copied into `release\installer\include` (the self-contained bin files are put in the `Compiler` subdirectory).

### Update help file?

This is done only if `Docs\v1` (for *master*) or `Docs\v2` (for *alpha*) exists.

This is done automatically if the script is *committing*.

AutoHotkey.chm is compiled and copied into `release\installer\include`.

### Update Ahk2Exe?

This is done automatically if the script is *committing* or *building*.

The script executes `git pull origin master` to retrieve the latest Ahk2Exe source, then compiles it by running Ahk2Exe.ahk with the current AutoHotkey executable.

### Update installer?

This is done automatically if the script is *committing* or *building*, or updating the help file or Ahk2Exe.

The script calls `release\installer\tools\UPDATE.bat` to build the setup exe.

The filename takes the format `AutoHotkey_%version%_setup.exe`.

The script adds the setup exe to the FTP script for upload to `/download/1.1/` or `/download/2.0/`.

### Update zip.

This is done only if 7-zip is found (see *Configuring*) and `release\zip-files-branchname.txt` exists, where *branchname* is the current branch. This txt file contains the list of files to include in the zip (paths are relative to `release\installer\include`).

This is done automatically if the script is *building*, or updating the help file or Ahk2Exe. Otherwise, there is no prompt (the zip is not updated).

The filename takes the format `AutoHotkey_%version%.zip`.

The script adds the zip file to the FTP script for upload to `/download/1.1/` or `/download/2.0/`.

### GitHub release?

This is done only if GitHub details are configured (see *Configuring*), and only for the *master* branch.

This is done automatically if the script is *committing*.

The script creates a new GitHub release and attaches the setup exe.

As in the *commit* step, an editor is shown for editing the release description. By default, it contains the changelog from the *commit* step with a few automated changes.
