# DUNK

**DUNK** is a cross-platform recycle bin manager written in [Zig](https://ziglang.org/).

⚠️ **Note:** This project is a **work in progress (WIP)**.

## TABLE OF CONTENTS

- [Features](#features)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## FEATURES

- Cross-platform recycle bin management
- Remove files/folders to the recycle bin
- Permanently delete trashed files
- Restore trashed files to their original or custom location
- List and filter files currently in the recycle bin
- Library API for use in other Zig projects (Maybe)

## REQUIREMENTS

- Zig compiler **v0.14.0** or higher
  > I aim to keep the codebase up to date with the latest Zig compiler versions.

---

## GETTING STARTED

1. Clone this project:

   ```bash
   git clone https://github.com/anjyakind/dunk.git

   ```

2. Navigate into the project:

```bash
cd dunk
```

3. Build the project:

```bash
zig build
```

4. The binary will be generated at:

```bash
./zig-out/bin/dunk
```

You can add this directory to your system PATH for easier access.

## USAGE

DUNK provides the following subcommands.

### REMOVE

Move a file or folder to the recycle bin:

```bash
dunk remove [files...]
```

### DELETE

Permanently delete a file/folder from the recycle bin:

```bash
dunk delete [trashed_files]
```

### RESTORE

Restore a trashed file/folder to its original location:

```bash
dunk restore [trashed_files]
```

Optionally restore to a custom directory with --dir:

```bash
dunk restore [trashed_files] --dir .
```

### LIST

List files currently in the recycle bin:

```bash
dunk list
```

Filter files using wildcards:

```bash
dunk list -f file.*.txt
```

## ROADMAP

- [ ] Windows support

- [ ] macOS support

- [ ] Linux support (partial)

- [ ] Configuration file for default behavior

- [ ] Improved filtering and searching

- [ ] Integration tests

- [ ] Library support: expose DUNK’s core logic as a reusable Zig package (Maybe)

## CONTRIBUTING

Contributions are welcome!

If you’d like to help improve DUNK, please fork the repository and submit a pull request.

## LICENSE

This project is licensed under the [MIT License](README.md).
