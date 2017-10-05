# shiori

SHIORI Protocol Parser/Builder for Nim lang

## Install

```
nimble install shiori
```

## Usage

**[API Document](https://narazaka.github.io/shiori-nim/)**

```nim
import shiori

let request = parseRequest("GET SHIORI/3.0\nCharset: UTF-8\n\n")
echo $request

var response = newResponse(status: Status.OK, headers: {"Value": "foo"}.newOrderedTable)
response.version = "3.0"
response.charset = "UTF-8"
echo $response
```

## License

This is released under [MIT License](https://narazaka.net/license/MIT?2017).
