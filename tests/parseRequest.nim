import unittest
import shiori except Status

suite "parseRequest":
    test "GET SHIORI/3.0":
        let request = parseRequest("GET SHIORI/3.0\nCharset: UTF-8\nID: menu.background.color.b\n\n")
        check(request.id == "menu.background.color.b")
    test "NOTIFY SHIORI/3.0":
        let request = parseRequest("NOTIFY SHIORI/3.0\nCharset: UTF-8\nID: hwnd\n\n")
        check(request.id == "hwnd")
    test "GET Version SHIORI/2.6":
        let request = parseRequest("GET Version SHIORI/2.6\nCharset: UTF-8\n\n")
        check(request.`method` == GET_Version)
