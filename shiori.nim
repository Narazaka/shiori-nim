## SHIORI Protocol Parser/Builder
##
## This is released under `MIT License <https://narazaka.net/license/MIT?2017>`_.
##
## .. code-block:: Nim
##
##    import shiori
##
##    let request = parseRequest("GET SHIORI/3.0\nCharset: UTF-8\n\n")
##    echo $request
##
##    var response = newResponse(status: Status.OK, headers: {"Value": "foo"}.newOrderedTable)
##    response.version = "3.0"
##    response.charset = "UTF-8"
##    echo $response

import tables
import sequtils
import strutils
import pegs
import macros

# header shortcut macro
proc genHeaderAccerror(typeName: string, symbolName: string, headerName: string): string {.compileTime.} =
  let useHeaderName =
    if headerName is "": capitalizeAscii(symbolName)
    else: headerName
  let code1 = "proc $1*(message: $2): string = message.headers[\"$3\"]\n" % [symbolName, typeName, useHeaderName]
  let code2 = "proc `$1=`*(message: $2, value: string): string {.discardable.} = message.headers[\"$3\"] = value\n" % [symbolName, typeName, useHeaderName]
  return code1 & code2

macro defineHeaderAccessor(typ: typed, symbolNameType: string, headerNameType: string = ""): untyped =
  return parseStmt(genHeaderAccerror($typ, symbolNameType.strVal, headerNameType.strVal))

const crlf = "\x0d\x0a"

# containers

type Protocol* = enum
  ## SHIORI protocol
  SHIORI

type Method* = enum
  ## SHIORI request method
  GET ## SHIORI/3.0 GET
  NOTIFY ## SHIORI/3.0 NOTIFY
  GET_Version ## SHIORI/2.x GET Version
  GET_Sentence ## SHIORI/2.x GET Sentence
  GET_Word ## SHIORI/2.x GET Word
  GET_Status ## SHIORI/2.x GET Status
  TEACH ## SHIORI/2.x TEACH
  GET_String ## SHIORI/2.x GET String
  NOTIFY_OwnerGhostName ## SHIORI/2.x NOTIFY OwnerGhostName
  NOTIFY_OtherGhostName ## SHIORI/2.x NOTIFY OtherGhostName
  TRANSLATE_Sentence ## SHIORI/2.x TRANSLATE Sentence

proc `$`*(meth: Method): string =
  case meth:
    of GET: return "GET"
    of NOTIFY: return "NOTIFY"
    of GET_Version: return "GET Version"
    of GET_Sentence: return "GET Sentence"
    of GET_Word: return "GET Word"
    of GET_Status: return "GET Status"
    of TEACH: return "TEACH"
    of GET_String: return "GET String"
    of NOTIFY_OwnerGhostName: return "NOTIFY OwnerGhostName"
    of NOTIFY_OtherGhostName: return "NOTIFY OtherGhostName"
    of TRANSLATE_Sentence: return "TRANSLATE Sentence"

type Status* = enum
  ## SHIORI response status
  OK = 200 ## 200 OK
  No_Content = 204 ## 204 No Content
  Not_Enough = 311 ## 311 Not Enough
  Advice = 312 ## 312 Advice
  Bad_Request = 400 ## 400 Bad Request
  Internal_Server_Error = 500 ## 500 Internal Server Error

proc `$`*(status: Status): string =
  case status:
    of OK: return "OK"
    of No_Content: return "No Content"
    of Not_Enough: return "Not Enough"
    of Advice: return "Advice"
    of Bad_Request: return "Bad Request"
    of Internal_Server_Error: return "Internal Server Error"

type Headers* = OrderedTableRef[string, string] ## SHIORI message headers

proc toShioriString*(headers: Headers): string =
  var headerLines: seq[string] = @[]
  for name, value in headers:
    headerLines.add(name & ": " & value & crlf)
  return headerLines.join("")

type Request* = ref object
  ## SHIORI request message
  `method`*: Method
  protocol*: Protocol
  version*: string
  headers*: Headers

proc newRequest*(`method` = Method.GET, protocol = Protocol.SHIORI, version: string = nil, headers = newOrderedTable[string, string]()): Request =
  return Request(`method`: `method`, protocol: protocol, version: version, headers: headers)

proc `$`*(request: Request): string =
  let requestLine = "$1 $2/$3" % [$request.`method`, $request.protocol, request.version] & crlf
  return requestLine & request.headers.toShioriString & crlf

defineHeaderAccessor(Request, "id", "ID")
defineHeaderAccessor(Request, "status")
defineHeaderAccessor(Request, "baseId")

type Response* = ref object
  ## SHIORI response message
  protocol*: Protocol
  version*: string
  status*: Status
  headers*: Headers

proc newResponse*(protocol = Protocol.SHIORI, version: string = nil, status = Status.OK, headers = newOrderedTable[string, string]()): Response =
  return Response(protocol: protocol, version: version, status: status, headers: headers)

proc `$`*(response: Response): string =
  let statusLine = "$1/$2 $3 $4" % [$response.protocol, response.version, $ord(response.status), $response.status] & crlf
  return statusLine & response.headers.toShioriString & crlf

type ErrorLevel* = enum
  ## SHIORI ErrorLevel header value
  info
  notice
  warning
  error
  critical

defineHeaderAccessor(Response, "value")
defineHeaderAccessor(Response, "marker")
defineHeaderAccessor(Response, "requestCharset")
proc errorLevel*(request: Response): ErrorLevel = parseEnum[ErrorLevel](request.headers["ErrorLevel"])
proc `errorLevel=`*(request: Response, value: ErrorLevel): string = request.headers["ErrorLevel"] = $value
defineHeaderAccessor(Response, "errorDescription")

type SecurityLevel* = enum
  ## SHIORI SecurityLevel header value
  local
  external

defineHeaderAccessor(Request, "charset")
defineHeaderAccessor(Response, "charset")
defineHeaderAccessor(Request, "sender")
defineHeaderAccessor(Response, "sender")
proc securityLevel*(request: Response): SecurityLevel = parseEnum[SecurityLevel](request.headers["SecurityLevel"])
proc `securityLevel=`*(request: Response, value: SecurityLevel): string = request.headers["SecurityLevel"] = $value


proc reference*(request: Request or Response, index: int): string = request.headers["Reference" & $index] ## Reference* accessor

# separated value helper

proc separated*(str: string, sep = "\x01"): seq[string] =
  ## separate string into seq[string] for some header values
  return str.split(sep)

proc separated2*(str: string, sep1 = "\x02", sep2 = "\x01"): seq[seq[string]] =
  ## separate string into seq[seq[string]] for some header values
  return str.split(sep1).map(proc (chunk: string): seq[string] = chunk.split(sep2))

proc combined*(list: seq[string], sep = "\x01"): string =
  ## join seq[string] into string for some header values
  return list.join(sep)

proc combined2*(list: seq[seq[string]], sep1 = "\x02", sep2 = "\x01"): string =
  ## join seq[seq[string]] into string for some header values
  return list.map(proc (chunk: seq[string]): string = chunk.join(sep2)).join(sep1)

# parser

#[
let requestPeg = peg("""
grammar <- ^ requestLine headerLines crlf $
crlf <- "\x0d\x0a"

requestLine <- method " " protocolVersion crlf
method <- { "GET" / "NOTIFY" }
protocolVersion <- protocol "/" version
protocol <- { "SHIORI" }
version <- { \d+ "." \d+ }

headerLines <- headerLine*
headerLine <- name ": " value crlf
name <- { [A-Za-z0-9.]+ }
value <- { [^\13\10]* }
""")
]#

let requestLinePeg = peg("""
requestLine <- ^ method " " protocolVersion $
method <- { "GET" / "NOTIFY" }
protocolVersion <- protocol "/" version
protocol <- { "SHIORI" }
version <- { \d+ "." \d+ }
""")

let statusLinePeg = peg("""
statusLine <- ^ protocolVersion " " status $
protocolVersion <- protocol "/" version
protocol <- { "SHIORI" }
version <- { \d+ "." \d+ }
status <- statusCode " " statusMessage
statusCode <- { \d+ }
statusMessage <- { .* }
""")

let headerLinePeg = peg("""
headerLine <- ^ name ": " value $
name <- { [A-Za-z0-9.]+ }
value <- { .* }
""")

# pegsがキャプチャ上限20個とかいう謎の制限を設けてクソなので行ごと解釈にする
proc parseRequest*(requestStr: string): Request =
  ## SHIORI request parser
  var request = newRequest()
  var isRequestLine = true
  var emptyLineLen = 0
  var lineIndex = 0
  for line in requestStr.splitLines:
    if isRequestLine:
      if line =~ requestLinePeg:
        request.`method` = parseEnum[Method](matches[0])
        request.protocol = parseEnum[Protocol](matches[1])
        request.version = matches[2]
      else:
        raise newException(ValueError, "invalid request line: line $# [$#]" % [$lineIndex, line])
      isRequestLine = false
    else:
      if line.len() == 0:
        emptyLineLen += 1
      elif line =~ headerLinePeg:
        request.headers[matches[0]] = matches[1]
      else:
        raise newException(ValueError, "invalid header line: line $# [$#]" % [$lineIndex, line])
    lineIndex += 1
  if emptyLineLen != 2:
    raise newException(ValueError, "message has wrong number of trailing crlf")
  return request

proc parseResponse*(responseStr: string): Response =
  ## SHIORI response parser
  var response = newResponse()
  var isStatusLine = true
  var emptyLineLen = 0
  var lineIndex = 0
  for line in responseStr.splitLines:
    if isStatusLine:
      if line =~ statusLinePeg:
        response.protocol = parseEnum[Protocol](matches[0])
        response.version = matches[1]
        response.status = Status(parseInt(matches[2]))
      else:
        raise newException(ValueError, "invalid status line: line $# [$#]" % [$lineIndex, line])
      isStatusLine = false
    else:
      if line.len() == 0:
        emptyLineLen += 1
      elif line =~ headerLinePeg:
        response.headers[matches[0]] = matches[1]
      else:
        raise newException(ValueError, "invalid header line: line $# [$#]" % [$lineIndex, line])
    lineIndex += 1
  if emptyLineLen != 2:
    raise newException(ValueError, "message has wrong number of trailing crlf")
  return response
