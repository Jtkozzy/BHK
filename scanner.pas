unit scanner;

{PASCAL- COMPILER : Scanner
Copyright (c) 1984 Per Brinch Hansen
Free pascal adaptation (c) Jari Korhonen, 2023}

interface

uses
  Classes, SysUtils;

procedure Scan(sourcefile: string);

implementation

uses main, util, defs;

const
  MaxChar = 5000;
  MaxKey = 631;
  MaxInt = 32767;


  NL = #10;
  SP = ' ';
  LeftBrace = #123;
  RightBrace = #125;
  LastStandardName = Write0;

type
  CharSet = set of char;
  SpellingTable = array [1..MaxChar] of char;
  WordPointer = ^WordRecord;

  WordRecord = record
    NextWord: WordPointer;
    IsName: boolean;
    Index, Length, LastChar: integer;
  end;

  HashTable = array
    [1..MaxKey] of WordPointer;

var
  LineNo: integer;
  ch: char;
  AlphaNumeric, CapitalLetters, Digits, EndComment, Invisible, Letters,
  Separators, SmallLetters: CharSet;
  Spelling: SpellingTable;
  Characters: integer;
  Hash: HashTable;
  Names: integer;

{ INPUT }
procedure NextChar;
begin
  if UtilEOF() then
    ch := ETX
  else
  begin
    UtilReadChar(ch);
    if ch in Invisible then
      NextChar;
  end;
end;

{ OUTPUT }
procedure Emit1(Symbol: SymbolType);
begin
  Emit(Ord(Symbol));
  //Writeln(symbolString1(Symbol));
end;

procedure Emit2(Symbol: SymbolType; Argument: integer);
begin
  Emit(Ord(Symbol));
  Emit(Argument);
  //Writeln(symbolString1(Symbol),': ', Argument);
end;

{ WORD SYMBOLS AND NAMES }

function Key(Text: string; Length: integer): integer;
const
  W = 32641 {32768 ~ 127};
  N = MaxKey;
var
  Sum, i: integer;
begin
  Sum := 0;
  i := 1;
  while i <= Length do
  begin
    Sum := (Sum + Ord(Text[i])) mod W;
    i := i + 1;
  end;
  Result := Sum mod N + 1;
end;

procedure Insert(IsName: boolean; Text: string; Length, Index, KeyNo: integer);
var
  Pointer: WordPointer;
  M, N: integer;
begin
  {Insert the word in the spelling table}
  Characters := Characters + Length;
  TestLimit(Characters, MaxChar);
  M := Length;
  N := Characters - M;
  while M > 0 do
  begin
    Spelling[M + N] := Text[M];
    M := M - 1;
  end;

  {Insert the word in a word list}
  New(Pointer);
  Pointer^.NextWord := Hash[KeyNo];
  Pointer^.IsName := IsName;
  Pointer^.Index := Index;
  Pointer^.Length := Length;
  Pointer^.LastChar := Characters;
  Hash[KeyNo] := Pointer;
end;

function Found(Text: string; Length: integer; Pointer: WordPointer): boolean;
var
  Same: boolean;
  M, N: integer;
begin
  if Pointer^.Length <> Length then
    Same := False
  else
  begin
    Same := True;
    M := Length;
    N := Pointer^.LastChar - M;
    while Same and (M > 0) do
    begin
      Same := Text[M] = Spelling[M + N];
      M := M - 1;
    end;
  end;
  Result := Same;
end;

procedure Define(IsName: boolean; Text: string; Length, Index: integer);
begin
  Insert(IsName, Text, Length, Index, Key(Text, Length));
end;

procedure Search(Text: string; Length: integer; var IsName: boolean;
  var Index: integer);
var
  KeyNo: integer;
  Pointer: WordPointer;
  Done: boolean;
begin
  KeyNo := Key(Text, Length);
  Pointer := Hash[KeyNo];
  Done := False;
  while not Done do
  begin
    if Pointer = nil then
    begin
      IsName := True;
      Names := Names + 1;
      Index := Names;
      Insert(True, Text, Length, Index, KeyNo);
      Done := True;
    end
    else if Found(Text, Length, Pointer) then
    begin
      IsName := Pointer^.IsName;
      Index := Pointer^.Index;
      Done := True;
    end
    else
    begin
      Pointer := Pointer^.NextWord;
    end;
  end;
end;

function SubSet(First, Last: char): CharSet;
var
  Value: CharSet;
  ch: char;
begin
  Value := [];
  ch := First;
  while
    ch <= Last do
  begin
    Value := Value + [ch];
    ch := chr(Ord(ch) + 1);
  end;
  Result := Value;
end;

procedure Initialize;
var
  KeyNo: integer;
begin
  InitPass(PASS1_SCAN);
  Digits := SubSet('0', '9');
  CapitalLetters := SubSet('A', 'Z');
  SmallLetters := SubSet('a', 'z');
  Letters := CapitalLetters + SmallLetters;
  AlphaNumeric := Letters + Digits;
  EndComment := [RightBrace, ETX];
  Invisible := SubSet(#0, #31) + [#127] - [NL, ETX];
  Separators := [SP, NL, LeftBrace];
  KeyNo := 1;
  while KeyNo <= MaxKey do
  begin
    Hash[KeyNo] := nil;
    KeyNo := KeyNo + 1;
  end;
  Characters := 0;
  {Insert the word symbols}
  Define(False, 'and', 3, Ord(And1));
  Define(False, 'array', 5, Ord(Array1));
  Define(False, 'begin', 5, Ord(Begin1));
  Define(False, 'const', 5, Ord(Const1));
  Define(False, 'div', 3, Ord(Div1));
  Define(False, 'do', 2, Ord(Do1));
  Define(False, 'else', 4, Ord(Else1));
  Define(False, 'end', 3, Ord(End1));
  Define(False, 'if', 2, Ord(If1));
  Define(False, 'mod', 3, Ord(Mod1));
  Define(False, 'not', 3, Ord(Not1));
  Define(False, 'of', 2, Ord(Of1));
  Define(False, 'or', 2, Ord(Or1));
  Define(False, 'procedure', 9, Ord(Procedure1));
  Define(False, 'program', 7, Ord(Program1));
  Define(False, 'record', 6, Ord(Record1));
  Define(False, 'then', 4, Ord(Then1));
  Define(False, 'type', 4, Ord(Type1));
  Define(False, 'var', 3, Ord(Var1));
  Define(False, 'while', 5, Ord(While1));
  {Insert the standard names}
  Define(True, 'integer', 7, Integer0);
  Define(True, 'boolean', 7, Boolean0);
  Define(True, 'false', 5, False0);
  Define(True, 'true', 4, True0);
  Define(True, 'read', 4, Read0);
  Define(True, 'write', 5, Write0);
  Names := LastStandardName;
end;

{ LEXICAL ANALYSIS }

procedure BeginLine(Number: integer);
begin
  LineNo := Number;
  NewLine(LineNo);
  Emit2(NewLine1, LineNo);
end;

procedure EndLine;
begin
  BeginLine(LineNo + 1);
end;

procedure Comment;
begin {ch = LeftBrace}
  NextChar;
  while not (ch in EndComment) do
  begin
    if ch = LeftBrace then
      Comment
    else
    begin
      if ch = NL then
        EndLine;
      NextChar;
    end;
  end;

  if ch = RightBrace then
  begin
    NextChar;
  end
  else
  begin
    Error(Comment3);
  end;
end;

procedure NextSymbol;
var
  IsName: boolean;
  Text: string;
  Length, Index, Value, Digit: integer;
begin
  Text := '';
  IsName := False;
  Index := 0;
  while ch in Separators do
    if ch = SP then
      NextChar
    else if ch = NL then
    begin
      EndLine;
      NextChar;
    end
    else
    begin
      {ch = LeftBrace} Comment;
    end;
  if ch in Letters then
  begin
    Length := 0;
    while ch in AlphaNumeric do
    begin
      if ch in CapitalLetters then
        ch := chr(Ord(ch) + Ord('a') - Ord('A'));
      Length := Length + 1;
      Text := Text + ch;
      NextChar;
    end;
    Search(Text, Length, IsName, Index);
    if IsName then
      Emit2(Name1, Index)
    else
      Emit(Index);
  end
  else if ch in Digits then
  begin
    Value := 0;
    while ch in Digits do
    begin
      Digit := Ord(ch) - Ord('0');
      if Value <= (MaxInt - Digit) div 10 then
      begin
        Value := 10 * Value + Digit;
        NextChar;
      end
      else
      begin
        Error(Numeral3);
        while ch in Digits do
          NextChar;
      end;
    end;
    Emit2(Numeral1, Value);
  end
  else if ch = '+' then
  begin
    Emit1(Plus1);
    NextChar;
  end
  else if ch = '-' then
  begin
    Emit1(Minus1);
    NextChar;
  end
  else if ch = '*' then
  begin
    Emit1(Asterisk1);
    NextChar;
  end
  else if ch = '<' then
  begin
    NextChar;
    if ch = '=' then
    begin
      Emit1(NotGreater1);
      NextChar;
    end
    else if ch = '>' then
    begin
      Emit1(NotEqual1);
      NextChar;
    end
    else
      Emit1(Less1);
  end
  else if ch = '=' then
  begin
    Emit1(Equal1);
    NextChar;
  end
  else if ch = '>' then
  begin
    NextChar;
    if ch = '=' then
    begin
      Emit1(NotLess1);
      NextChar;
    end
    else
      Emit1(Greater1);
  end
  else if ch = ':' then
  begin
    NextChar;
    if ch = '=' then
    begin
      Emit1(Becomes1);
      NextChar;
    end
    else
      Emit1(Colon1);
  end
  else if ch = '(' then
  begin
    Emit1(LeftParenthesis1);
    NextChar;
  end
  else if ch = ')' then
  begin
    Emit1(RightParenthesis1);
    NextChar;
  end
  else if ch = '[' then
  begin
    Emit1(LeftBracket1);
    NextChar;
  end
  else if ch = ']' then
  begin
    Emit1(RightBracket1);
    NextChar;
  end
  else if ch = ',' then
  begin
    Emit1(Comma1);
    NextChar;
  end
  else if ch = '.' then
  begin
    NextChar;
    if ch = '.' then
    begin
      Emit1(DoubleDot1);
      NextChar;
    end
    else
      Emit1(Period1);
  end
  else if ch = ';' then
  begin
    Emit1(Semicolon1);
    NextChar;
  end
  else if ch <> ETX then
  begin
    Emit1(Unknown1);
    NextChar;
  end;
end;

procedure Scan(sourcefile: string);
begin
  Initialize;
  BeginLine(1);
  UtilOpenSourceFile(sourcefile);
  NextChar;
  while ch <> ETX do
    NextSymbol;
  Emit1(EndText1);
  //DbgOutputPass1();
end;

end.
