unit util;

{PASCAL- COMPILER : Utilities
Copyright (c) 1984 Per Brinch Hansen
Free pascal adaptation (c) Jari Korhonen, 2023}

interface

uses
  Classes, SysUtils;

const
  MAX_BUFLEN = 128 * 1024;

type
  COMPILER_BUF = record
    num_ints: integer;
    buf: array[0..MAX_BUFLEN - 1] of integer;
  end;
  PCOMPILER_BUF = ^COMPILER_BUF;

function UtilEOF(): boolean;
function UtilEOFReadbuf: boolean;
procedure UtilOpenSourceFile(sourcefile: string);
procedure UtilReadChar(var ch: char);
procedure InitPass(pass: integer);
procedure UtilWriteStr(str: string);
procedure UtilWriteInt(n: integer; Width: integer);
procedure UtilWrite(Value: integer);
function UtilReadInt: integer;
procedure DbgOutputPass1();
procedure DbgOutputPass2();
procedure DbgOutputPass3();

const
  SIZE_INT = 4;
  SIZE_CHAR = 1;
  ETX = #3;
  PASS1_SCAN = 1;
  PASS2_PARSE = 2;
  PASS3_ASSEMBLE = 3;
  PASS4_RUN = 4;

implementation

uses defs, main;

var
  src: string;
  src_ind: integer;

  bufpass1: COMPILER_BUF;
  bufpass2: COMPILER_BUF;
  bufpass3: COMPILER_BUF;

  gReadbuf: PCOMPILER_BUF;
  gWritebuf: PCOMPILER_BUF;
  gRead: integer;

procedure InitPass(pass: integer);
begin
  case pass of
    PASS1_SCAN:
    begin
      gReadbuf := nil;             //reads from source text
      bufpass1.num_ints := 0;
      gWritebuf := addr(bufpass1);
      gRead := 0;
    end;
    PASS2_PARSE:
    begin
      gReadbuf := addr(bufpass1);
      bufpass2.num_ints := 0;
      gWritebuf := addr(bufpass2);
      gRead := 0;
    end;
    PASS3_ASSEMBLE:
    begin
      gReadbuf := addr(bufpass2);
      bufpass3.num_ints := 0;
      gWritebuf := addr(bufpass3);
      gRead := 0;
    end;
    PASS4_RUN:
    begin
      gReadbuf := addr(bufpass3);
      gWritebuf := nil;
      gRead := 0;
    end;
  end;
end;


procedure DbgOutput(pcb: PCOMPILER_BUF);
var
  i: integer;
  num: integer;
  sum: integer;
  n: integer;
begin
  num := pcb^.num_ints;
  sum := 0;
  Writeln('num_ints :', num);
  for i := 0 to num - 1 do
  begin
    if (i > 0) and (i mod 8 = 0) then
    begin
      Writeln;
    end;
    n := pcb^.buf[i];
    Write(n: 10);
    sum := (sum + n mod 8191) mod 8191;
  end;

  Writeln(#10, 'chksum: ', sum);
  Writeln('Errors: ', Errors);
end;

procedure DbgOutputPass1();
begin
  DbgOutput(@bufpass1);
end;

procedure DbgOutputPass2();
begin
  DbgOutput(@bufpass2);
end;

procedure DbgOutputPass3();
begin
  DbgOutput(@bufpass3);
end;

procedure UtilOpenSourceFile(sourcefile: string);
var
  l: TStringList;
begin
  l := TStringList.Create;
  l.LoadFromFile(sourcefile);
  src := l.Text;
  src_ind := 0;
end;

function UtilEOF(): boolean;
begin
  Result := src_ind >= src.length;
end;

function UtilEOFReadbuf: boolean;
begin
  Result := gRead >= gReadbuf^.num_ints;
end;

procedure UtilReadChar(var ch: char);
begin
  if UtilEOF then
  begin
    ch := ETX;
  end
  else
  begin
    ch := src[src_ind + 1];  //one-based indexing
    src_ind := src_ind + 1;
  end;
end;

procedure UtilWrite(Value: integer);
var
  ind: integer;
begin
  if gWritebuf <> nil then
  begin
    ind := gWritebuf^.num_ints;
    gWritebuf^.buf[ind] := Value;
    gWritebuf^.num_ints := ind + 1;
  end;
end;

function UtilReadInt: integer;
begin
  if gReadbuf <> nil then
  begin
    if gRead < gReadbuf^.num_ints then
    begin
      Result := gReadbuf^.buf[gRead];
      gRead := gRead + 1;
    end
    else
    begin
      Result := endSymbol();
    end;
  end;
end;

procedure UtilWriteStr(str: string);
begin
  Write(str);
end;

procedure UtilWriteInt(n: integer; Width: integer);
begin
  Write(n: Width);
end;

function UtilReadStr: string;
var
  s: string;
begin
  Readln(s);
  Result := s;
end;

initialization
  src_ind := 0;
  src := '';

end.
