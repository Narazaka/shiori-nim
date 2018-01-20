# Package

version       = "1.2.0"
author        = "Narazaka"
description   = "SHIORI Protocol Parser/Builder"
license       = "MIT"

# Dependencies

requires "nim >= 0.17.2"

task test, "test":
    exec "nim c -r tests/parseRequest"
