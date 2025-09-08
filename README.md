# DUNK

A cross platform (WIP) recylce bin manager written in zig. 

## HOW TO GET STARTED

Please make sure you have a zig compiler downloaded at at least version 0.14.0. We are making sure that the code used is up to date with the
latest version of the compiler as we develop this tool.

1. Clone a this project
```bash
git clone https://github.com/anjyakind/dunk.git
```

2. Run zig build command at the root of the project
```bash
cd ./dunk 
zig build
```

3. A binary called dunk will be generated in {PROJECT_ROOT}/zig-out/bin/ where you can add this binary to your path

## USAGE

There are four subcommands used in this tool. 

### REMOVE

This subcommand is used to remove a file/folder from the current/suggested path to the recycle bin.
```bash
dunk remove [files]
```

### DELETE

This subcommand is used to permanently delete an already trashed folder from the recylce bin.
```bash 
dunk delete [trashed_files]
```

### RESTORE

This subcommand is used to restore a trashed file from the recyle bin to its original location.
```bash
dunk restore [trashed_files]
```

Adding a directory path with the --dir command can be used to restore the trashed file in that specified path. 
```bash
dunk restore [trashed_files] --dir .
```


### LIST

This subcommand is used to list the files present in the recycle bin

```bash
dunk list
```

In order to filter through arguments wildcards can be given

```bash
dunk list -f file.*.txt
```
