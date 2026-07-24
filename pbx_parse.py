#!/usr/bin/env python3
import sys

with open('NewTerm.xcodeproj/project.pbxproj','rb') as f:
    data = f.read().decode('utf-8', errors='replace')

n = len(data)
RBRACE = chr(125)   # '}'
LBRACE = chr(123)   # '{'
RPAR   = chr(41)    # ')'
LPAR   = chr(40)    # '('
SEMI   = chr(59)    # ';'
COMMA  = chr(44)    # ','
EQ     = chr(61)    # '='
DQUOTE = chr(34)    # '"'
BSLASH = chr(92)    # '\\'
LT     = chr(60)    # '<'
GT     = chr(62)    # '>'

def err(i, msg):
    ln = data[:i].count("\n") + 1
    last_nl = data.rfind("\n", 0, i)
    cl = i - last_nl
    sys.stderr.write("ERROR at pos {} line {} col {}: {}\n".format(i, ln, cl, msg))
    s = max(0, i-120)
    e = min(n, i+120)
    sys.stderr.write("CONTEXT:\n")
    sys.stderr.write(data[s:e] + "\n")
    sys.stderr.write("    " + " "*(i-s) + "^\n")
    sys.exit(0)

def skip_ws(i):
    while i < n:
        c = data[i]
        if c in " \t\r\n":
            i += 1
        elif c == "/" and i+1 < n and data[i+1] == "/":
            while i < n and data[i] != "\n":
                i += 1
        elif c == "/" and i+1 < n and data[i+1] == "*":
            i += 2
            while i < n-1 and not (data[i] == "*" and data[i+1] == "/"):
                i += 1
            i += 2
        else:
            break
    return i

def parse_string(i):
    i += 1
    while i < n:
        c = data[i]
        if c == BSLASH:
            i += 2
        elif c == DQUOTE:
            return i + 1
        else:
            i += 1
    err(i, "unterminated string")

def parse_value(i):
    i = skip_ws(i)
    if i >= n:
        err(i, "unexpected EOF")
    c = data[i]
    if c == DQUOTE:
        i = parse_string(i)
    elif c == LBRACE:
        i = parse_dict(i)
    elif c == LPAR:
        i = parse_array(i)
    elif c == LT:
        i += 1
        while i < n and data[i] != GT:
            i += 1
        if i >= n:
            err(i, "unterminated hex data")
        i += 1
    else:
        while i < n and data[i] not in " \t\r\n" + SEMI + COMMA + RPAR + EQ:
            i += 1
    return i

def parse_dict(i):
    i += 1
    while True:
        i = skip_ws(i)
        if i >= n:
            err(i, "unterminated dict")
        if data[i] == RBRACE:
            return i + 1
        i = parse_value(i)
        i = skip_ws(i)
        if i >= n or data[i] != EQ:
            err(i, "expected '=' after key")
        i += 1
        i = parse_value(i)
        i = skip_ws(i)
        if i >= n:
            err(i, "unterminated dict (expected ; or })")
        c = data[i]
        if c == SEMI:
            i += 1
        elif c == RBRACE:
            return i + 1
        else:
            err(i, "expected ';' or '}' after dict entry, got " + repr(c))

def parse_array(i):
    i += 1
    while True:
        i = skip_ws(i)
        if i >= n:
            err(i, "unterminated array")
        if data[i] == RPAR:
            return i + 1
        i = parse_value(i)
        i = skip_ws(i)
        if i >= n:
            err(i, "unterminated array")
        c = data[i]
        if c == COMMA:
            i += 1
        elif c == RPAR:
            return i + 1
        else:
            err(i, "expected ',' or ')' in array, got " + repr(c))

try:
    i = skip_ws(0)
    print("start: pos={} char={}".format(i, repr(data[i])))
    if data[i] == LBRACE:
        i = parse_dict(i)
        print("OK, ended at pos {}, len {}".format(i, n))
    else:
        print("top-level not starting with {")
        while i < n:
            i = skip_ws(i)
            if i >= n:
                break
            i = parse_value(i)
            i = skip_ws(i)
            if i < n and data[i] == EQ:
                i += 1
                i = parse_value(i)
                i = skip_ws(i)
                if i < n and data[i] == SEMI:
                    i += 1
except SystemExit:
    pass
except Exception as e:
    print("Exception: {}".format(e))