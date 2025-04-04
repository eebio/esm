# Experimental Simple Model (ESM)

![Tests](https://github.com/eebio/esm/actions/workflows/test.yml/badge.svg)

A data format and supporting tools to enable accessible and reproducible data processing for engineering biology.

# Installation

## Installing Julia

ESM is a command line tool, written in Julia. To install it, we first will install Julia, which we will then use to compile the source code and build the command line tool.

### For Linux and MacOS

Open the terminal and run the following command.

```bash
curl -fsSL https://install.julialang.org | sh
```

### For Windows

Open the command prompt (or PowerShell) and run the following command.

```bash
winget install julia -s msstore
```

Alternatively, an interactive installer is available on the [Julia website](https://julialang.org/downloads/#current_stable_release).

## Downloading the ESM source code

There are two ways to get the ESM source code to build the command line tool. If you are familiar with git, it is recommended to clone the repository (git is likely already installed if you are on Linux or MacOS!).

Alternatively, you can download a zip of the repository to install it, although downloading future updates will be more tiresome.

### Through Git

```bash
git clone https://github.com/eebio/esm.git
```

### Download a .zip

The zip of the code can be downloaded from [here](https://github.com/eebio/esm/archive/refs/heads/main.zip). Then un-zip the source code.

## Compiling ESM

Finally, we need to compile the ESM source code using Julia so that it can be used from the command line.

1. Open a terminal (Windows users should open Powershell for this step).
2. Navtigate to where you downloaded the source code (Useful commands for those unfamiliar: `pwd`: displays the path to the current folder, `cd [folder_name]`: move from the current folder to the one given by `[folder_name]`, `ls`: displays the files and folders inside the current folder).
3. Enter the source code directory (with `cd esm`).
4. Run `julia --project deps/build.jl`.

## Adding ESM to the PATH

ESM is now installed on the computer. But before we can use it, we need to make sure the computer knows where to find it by adding `~/.julia/bin` to the `PATH`.

Depending on your choice of terminal will determine which file you need to add the following line to.

```bash
export PATH=$PATH:~/.julia/bin
```

You can find out which terminal you are using with the command `echo $0`.

### ZSH (probably this for MacOS)

If you are using a zsh terminal (default on modern MacOS), then add the above line to the file `~/.zshenv`.

### Bash (probably this for Linux)

If you are using a Bash terminal (Linux and early MacOS, before Catalina), then add the above line to the startup file with `nano ~/.profile`.
Use `Ctrl+X` once you're done to close the file (remember to save).

### PowerShell (one possibility for Windows)

If you want to use the PowerShell terminal for Windows, then instead execute the following command.

```powershell
$PATH = [Environment]::GetEnvironmentVariable("PATH")
$julia_path = "~\.julia\bin"
[Environment]::SetEnvironmentVariable("PATH", "$PATH;$julia_path")
```

### Command Prompt (another possibility for Windows)

1. Right-click the Start button.
2. Select "System".
3. Then "Advanced system settings".
4. Navigate to "Environment Variables".
5. Locate "Path" under either "User variables" or "System variables" (depending on whether you want to install ESM for just one user or all users).
6. Click "Edit".
7. Add `;~/.julia/bin` to the end if the textbox and click "OK".

## Checking the installation

Restart the terminal.
If you now run `esm` from the command line, you should get a lovely view of the different commands you can run.
If you see this then congratulations, you have successfully installed esm.

If it didn't work, try running `echo $PATH`. If you can't see `~/.julia/bin` then go back to the step **Adding ESM to the PATH**.
