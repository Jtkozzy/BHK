unit interpreter;

{PASCAL- COMPILER : Interpreter
Copyright (c) 1984 Per Brinch Hansen
Free pascal adaptation (c) Jari Korhonen, 2023}

interface

uses
  Classes, SysUtils;

procedure Interpret();

implementation

uses defs, util;

const
  Min = 0;
  Max = 8191;

type
  Store = array [Min..Max] of integer;

var
  St: Store;
  p, b, s: integer;
  StackBottom: integer;
  Running: boolean;

procedure Error(LineNo: integer; Text: string);
begin
  UtilWriteStr('Line');
  UtilWriteInt(LineNo, 5);
  UtilWriteStr(' ');
  UtilWriteStr(Text);
  Writeln;
  Running := False;
end;


//VariableAccess = VariableName { Selector }
//VariableName = "Variable" | "VarParam" .
//Selector = Expression "Index" | "Field" .
procedure Variable(Level, Displ: integer);
var
  x: integer;
begin
  s := s + 1;
  x := b;
  while Level > 0 do
  begin
    x := St[X];
    Level := Level - 1;
  end;
  St[s] := x + Displ;
  p := p + 3;
end;

procedure VarParam(Level, Displ: integer);
var
  x: integer;
begin
  s := s + 1;
  x := b;
  while Level > 0 do
  begin
    x := St[x];
    Level := Level - 1;
  end;
  St[s] := St[x + Displ];
  p := p + 3;
end;

procedure Index(Lower, Upper, Length, LineNo: integer);
var
  i: integer;
begin
  i := St[s];
  s := s - 1;
  if (i < Lower) or (i > Upper) then
    Error(LineNo, 'Range Error')
  else
    St[s] := St[s] + (i - Lower) * Length;
  p := p + 5;
end;

procedure Field(Displ: integer);
begin
  St[s] := St[s] + Displ;
  p := p + 2;
end;


//Factor = "Constant" | VariableAccess "Value" |
// Expression | Factor "Not" .
procedure Constant(Value: integer);
begin
  s := s + 1;
  St[s] := Value;
  p := p + 2;
end;

procedure Value(Length: integer);
var
  x, i: integer;
begin
  x := St[s];
  i := 0;
  while i < Length do
  begin
    St[s + i] := St[x + i];
    i := i + 1;
  end;
  s := s + Length - 1;
  p := p + 2;
end;

procedure Notx;
begin
  if St[s] = Ord(True) then
    St[s] := Ord(False)
  else
    St[s] := Ord(True);

  p := p + 1;
end;


// Term = Factor { Factor MultiplyingOperator } .
// MultiplyingOperator = "Multiply" | "Divide" | "Modulo"| "And" ,
procedure Multiply;
begin
  s := s - 1;
  St[s] := St[s] * St[s + 1];
  p := p + 1;
end;

procedure Divide;
begin
  s := s - 1;
  St[s] := St[s] div St[s + 1];
  p := p + 1;
end;

procedure Modulo;
begin
  s := s - 1;
  St[s] := St[s] mod St[s + 1];
  p := p + 1;
end;

procedure Andx;
begin
  s := s - 1;
  if St[s] = Ord(True) then
    St[s] := St[s + 1];

  p := p + 1;
end;


// SimpleExpression = Term [ SignOperator ] { Term AddingOperator } .
// SignOperator = Empty | "Minus" .
// AddingOperator = "Add" | "Subtract" | "Or" .
procedure Minus;
begin
  St[s] := -St[s];
  p := p + 1;
end;

procedure Add;
begin
  s := s - 1;
  St[s] := St[s] + St[s + 1];
  p := p + 1;
end;

procedure Subtract;
begin
  s := s - 1;
  St[s] := St[s] - St[s + 1];
  p := p + 1;
end;

procedure Orx;
begin
  s := s - 1;
  if St[s] = Ord(False) then
    St[s] := St[s + 1];

  p := p + 1;
end;


// Expression = SimpleExpression [ SimpleExpression RelationalOperator ] .
// RelationalOperator = "Less" | "Equal" | "Greater"
//  | "NotGreater" | "NotEqual" | "NotLess" .
procedure Less;
begin
  s := s - 1;
  St[s] := Ord(St[s] < St[s + 1]);
  p := p + 1;
end;

procedure Equal;
begin
  s := s - 1;
  St[s] := Ord(St[s] = St[s + 1]);
  p := p + 1;
end;

procedure Greater;
begin
  s := s - 1;
  St[s] := Ord(St[s] > St[s + 1]);
  p := p + 1;
end;

procedure NotGreater;
begin
  s := s - 1;
  St[s] := Ord(St[s] <= St[s + 1]);
  p := p + 1;
end;

procedure NotEqual;
begin
  s := s - 1;
  St[s] := Ord(St[s] <> St[s + 1]);
  p := p + 1;
end;

procedure NotLess;
begin
  s := s - 1;
  St[s] := Ord(St[s] >= St[s + 1]);
  p := p + 1;
end;


// I0Statement = VariableAccess "Read" | Expression "Write" .
procedure Readx;
begin
  Read(St[St[s]]);
  s := s - 1;
  p := p + 1;
end;

procedure Writex;
begin
  Writeln(St[s]: 6);
  s := s - 1;
  p := p + 1;
end;


// ProcedureStatement = I0Statement | ActualParameterList ] "ProecCall" .
// ActualParameterList = ActualParameter { ActualParameter } .
// ActualParameter = Expression | VariableAccess .
procedure ProcCall(Level, Displ: integer);
var
  x: integer;
begin
  s := s + 1;
  x := b;
  while Level > 0 do
  begin
    x := St[x];
    Level := Level - 1;
  end;
  St[s] := x;
  St[s + 1] := b;
  St[s + 2] := p + 3;
  b := s;
  s := b + 2;
  p := p + Displ;
end;


// AssignmentStatement = VariableAccess Expression "Assign" .
procedure Assign(Length: integer);
var
  x, y, i: integer;
begin
  s := s - Length - 1;
  x := St[s + 1];
  y := s + 2;
  i := 0;
  while i < Length do
  begin
    St[x + i] := St[y + i];
    i := i + 1;
  end;
  p := p + 2;
end;


// IfStatement = Expression "Do" Statement [ "Goto" Statement ] .
// WhileStatement = Expression "Do" Statement "Goto" .
procedure Dox(Displ: integer);
begin
  if St[s] = Ord(True) then
    p := p + 2
  else
    p := p + Displ;
  s := s - 1;
end;

procedure Gotox(Displ: integer);
begin
  p := p + Displ;
end;


// Statement = AssignmentStatement | ProcedureStatement
//  | IfStatement | WhileStatement | CompoundStatement | Empty .
// CompoundStatement = Statement { Statement } .
// BlockBody = { ProcedureDefinition } CompoundStatement .
// ProcedureDefinition = "Procedure" BlockBody "EndProc" .
procedure Procedurex(VarLength, TempLength, Displ, LineNo: integer);
begin
  s := s + VarLength;
  if s + TempLength > Max then
    Error(LineNo, 'Stack Limit')
  else
    p := p + Displ;
end;

procedure EndProc(ParamLength: integer);
begin
  s := b - ParamLength - 1;
  p := St[b + 2];
  b := St[b + 1];
end;


// Program = "Program" BlockBody "EndProg" .
procedure Programx(VarLength, TempLength, Displ, Lineno: integer);
begin
  b := StackBottom;
  S := b + 2 + VarLength;
  if s + TempLength > Max then
    Error(LineNo, 'Stack Limit')
  else
    p := p + Displ;
end;

procedure EndProg;
begin
  Running := False;
end;

// LocalVar(Displ) = Variable(0, Displ) .
procedure LocalVar(Displ: integer);
begin
  s := s + 1;
  St[s] := b + Displ;
  p := p + 2;
end;

// LocalValue(Displ) = LocalVar(Displ) Value(1) .
procedure LocalValue(Displ: integer);
begin
  s := s + 1;
  St[s] := St[b + Displ];
  p := p + 2;
end;

// GlobalVar(Displ) = Variable(1, Displ) .
procedure GlobalVar(Displ: integer);
begin
  s := s + 1;
  St[s] := St[b] + Displ;
  p := p + 2;
end;

// GlobalValue(Displ) = GlobalVar(Displ) Value(1) .
procedure GlobalValue(Displ: integer);
begin
  s := s + 1;
  St[s] := St[St[b] + Displ];
  p := p + 2;
end;

// SimpleValue = Value(1) .
procedure SimpleValue;
begin
  St[s] := St[St[s]];
  p := p + 1;
end;

// SimpleAssign = Assign(1) .
procedure SimpleAssign;
begin
  St[St[s - 1]] := St[s];
  s := s - 2;
  p := p + 1;
end;


// GlobalCall(Displ) = ProcCall(1, Displ) .
procedure GlobalCall(Displ: integer);
begin
  St[s + 1] := St[b];
  St[s + 2] := b;
  St[s + 3] := p + 2;
  b := s + 1;
  s := b + 2;
  p := p + Displ;
end;

procedure LoadProgram();
var
  x: integer;
begin
  InitPass(PASS4_RUN);
  x := Min;
  while not UtilEOFReadbuf do
  begin
    St[x] := UtilReadInt();
    x := x + 1;
  end;
  StackBottom := x;
end;

procedure RunProgram;
var
  op: OperationPart;
begin
  Running := True;
  p := Min;
  while Running do
  begin
    op := int2op(St[p]);
    if op <= Do2 then
      if op = Add2 then
        Add
      else if op = And2 then
        Andx
      else if op = Assign2 then
        Assign(St[p + 1])
      else if op = Constant2 then
        Constant(St[p + 1])
      else if op = Divide2 then
        Divide
      else { op = Do2 }
        Dox(St[p + 1])
    else if op <= Greater2 then
      if op = EndProc2 then
        EndProc(St[p + 1])
      else if op = EndProg2 then
        EndProg
      else if op = Equal2 then
        Equal
      else if op = Field2 then
        Field(St[p + 1])
      else if op = Goto2 then
        Gotox(St[p + 1])
      else   { op = Greater2 }
        Greater
    else if op <= Not2 then
      if op = Index2 then
        Index(St[p + 1], St[p + 2], St[p + 3], St[p + 4])
      else if op = Less2 then
        Less
      else if op = Minus2 then
        Minus
      else if op = Modulo2 then
        Modulo
      else if op = Multiply2 then
        Multiply
      else { op = Not2 }
        Notx
    else if op <= Procedure2 then
      if op = NotEqual2 then
        NotEqual
      else if op = NotGreater2 then
        NotGreater
      else if op = NotLess2 then
        NotLess
      else if op = Or2 then
        orx
      else if op = ProcCall2 then
        ProcCall(St[p + 1], St[p + 2])
      else { op = Procedure2 }
        Procedurex(St[p + 1], St[p + 2], St[p + 3], St[p + 4])
    else if op <= Read2 then
      if op = Program2 then
        Programx(St[p + 1], St[p + 2], St[p + 3], St[p + 4])
      else if op = Subtract2 then
        Subtract
      else if op = Value2 then
        Value(St[p + 1])
      else if op = Variable2 then
        Variable(St[p + 1], St[p + 2])
      else if op = VarParam2 then
        VarParam(St[p + 1], St[p + 2])
      else { op = Read2 }
        Readx
    else if op <= LocalVar2 then
      if op = Write2 then
        Writex
      else if op = GlobalCall2 then
        GlobalCall(St[p + 1])
      else if op = GlobalValue2 then
        GlobalValue(St[p + 1])
      else if op = GlobalVar2 then
        GlobalVar(St[p + 1])
      else if op = LocalValue2 then
        LocalValue(St[p + 1])
      else { op = LocalVar2 }
        LocalVar(St[p + 1])
    else if op = SimpleAssign2 then
      SimpleAssign
    else { op = SimpleValue2 }
      SimpleValue;
  end;
end;

procedure OpenProg;
begin
  LoadProgram();
end;

procedure Interpret();
begin
  OpenProg;
  RunProgram;
end;

end.
