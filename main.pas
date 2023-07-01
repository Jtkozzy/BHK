unit main;

{PASCAL- COMPILER : Administration
Copyright (c) 1984 Per Brinch Hansen
Free pascal adaptation (c) Jari Korhonen, 2023}

interface

uses
  Classes, SysUtils, defs;

procedure Emit(Value: integer);
procedure ReRun;
procedure NewLine(Number: integer);
procedure Error(Kind: ErrorKind);
procedure TestLimit(Length, Maximum: integer);
procedure admin();

var
  Source, Code: string;
  LineNo: integer;
  Emitting, Errors, CorrectLine: boolean;

implementation

uses util, scanner, parser, assembly, interpreter;

procedure Emit(Value: integer);
begin
  if Emitting then
    UtilWrite(Value);
end;

procedure ReRun;
begin
  Emitting := True;
  InitPass(PASS3_ASSEMBLE);
end;

procedure NewLine(Number: integer);
begin
  LineNo := Number;
  CorrectLine := True;
end;

procedure Error(Kind: ErrorKind);
var
  Text: string;
begin
  if not (Errors) then
  begin
    Emitting := False;
    Errors := True;
  end;

  if Kind = Ambiguous3 then
    Text := 'Ambiguous Name'
  else if Kind = Comment3 then
    Text := 'Invalid Comment'
  else if Kind = Kind3 then
    Text := 'Invalid Name Kind'
  else if Kind = Numeral3 then
    Text := 'Invalid Numeral'
  else if Kind = Range3 then
    Text := 'Invalid Index Range'
  else if Kind = Syntax3 then
    Text := 'Invalid Syntax'
  else if Kind = Type3 then
    Text := 'Invalid Type'
  else if Kind = Undefined3 then
    Text := 'Undefined Name';

  if CorrectLine then
  begin
    UtilWriteStr('Line ');
    UtilWriteInt(LineNo, 4);
    UtilWriteStr('  ');
    UtilWriteStr(Text);
    Writeln();
    CorrectLine := False;
  end;
end;



procedure TestLimit(Length, Maximum: integer);
begin
  if Length >= Maximum then
  begin
    Writeln();
    UtilWriteStr('Program Too Big');
    Writeln();
    Halt(1);
  end;
end;

procedure Info;
begin
  Writeln('BHK (Brinch-Hansen Kompiler), Pascal- compiler of');
  Writeln('Per Brinch-Hansen''s Book "On Pascal Compilers"');
  Writeln('Moderately refactored for modern Free Pascal by Jari Korhonen');
  Writeln;
end;

procedure admin();
begin
  if ParamCount <> 1 then
  begin
    Info;
    Writeln('Usage: Bhk pasfile');
    Writeln('Pasfile is Pascal- file, which is compiled to VM binary.');
    Writeln('Binary is then run in interpreter');
    Halt(1);
  end
  else
  begin
    Info;
    Source := ParamStr(1);
    Errors := False;
    Emitting := True;
    Scan(Source);
    if not (Errors) then
    begin
      Parse();
      if not (Errors) then
      begin
        Emitting := False;
        Assemble();
      end;

      if Errors then
      begin
        Writeln();
        Writeln('Compilation Errors');
      end
      else
      begin
        Interpret();
      end;
    end;
  end;
end;

end.
