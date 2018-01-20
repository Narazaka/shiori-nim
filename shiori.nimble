# Package

version       = "1.3.0"
author        = "Narazaka"
description   = "SHIORI Protocol Parser/Builder"
license       = "MIT"

skipDirs = @["tests"]

# Dependencies

requires "nim >= 0.17.2"

task test, "test":
    exec "nim c -r -p:. tests/parseRequest"
