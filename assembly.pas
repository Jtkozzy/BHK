unit assembly;

{PASCAL- COMPILER : Assembly
Copyright (c) 1984 Per Brinch Hansen
Free pascal adaptation (c) Jari Korhonen, 2023}

interface

uses
  Classes, SysUtils;

procedure Assemble;

implementation

uses defs, main, util;

const
  MaxLabel = 1000;

type
  Operations = set of OperationPart;
  AssemblyTable = array [1..MaxLabel] of integer;


var
  NoArguments, OneArgument, TwoArguments, {FourArguments,} Blocks, Jumps: Operations;
  Op: OperationPart;
  Arg1, Arg2, Arg3, Arg4: integer;
  Address: integer;
  Table: AssemblyTable;

procedure NextInstruction;
var
  n: integer;
begin
  n := utilReadInt();
  Op := int2op(n);
  if Op in NoArguments then { skip }
  else if Op in OneArgument then
    Arg1 := UtilReadInt()
  else if Op in TwoArguments then
  begin
    Arg1 := UtilReadInt();
    Arg2 := UtilReadInt();
  end
  else {Op in FourArguments}
  begin
    Arg1 := UtilReadInt();
    Arg2 := UtilReadInt();
    Arg3 := UtilReadInt();
    Arg4 := UtilReadInt();
  end;
end;

procedure Emit1(Op: Operationpart);
begin
  Emit(Ord(Op));
  //if Emitting then
  //   Writeln(Address, ': ', opsString(Op));
  Address := Address + 1;
end;

procedure Emit2(Op: OperationPart; Arg: integer);
begin
  Emit(Ord(Op));
  Emit(Arg);
  //if Emitting then
  //   Writeln(Address, ': ', opsString(Op), ' ', Arg);
  Address := Address + 2;
end;

procedure Emit3(Op: OperationPart; Arg1, Arg2: integer);
begin
  Emit(Ord(Op));
  Emit(Arg1);
  Emit(Arg2);
  //if Emitting then
  //   Writeln(Address, ': ', opsString(Op), ' ', Arg1, ' ', Arg2);
  Address := Address + 3;
end;

procedure Emit5(Op: OperationPart; Arg1, Arg2, Arg3, Arg4: integer);
begin
  Emit(Ord(Op));
  Emit(Arg1);
  Emit(Arg2);
  Emit(Arg3);
  Emit(Arg4);
  //if Emitting then
  //   Writeln(Address, ': ', opsString(Op), ' ', Arg1, ' ', Arg2, ' ', Arg3, ' ', Arg4);
  Address := Address + 5;
end;

function Optimize(SpecialCase: boolean): boolean;
begin
  Result := SpecialCase;
end;

function JumpDispl(LabelNo: integer): integer;
begin
  Result := Table[LabelNo] - Address;
end;

procedure Assign(Length: integer);
begin
  if Optimize(Length = 1) then
    Emit1(SimpleAssign2)
  else
    Emit2(Assign2, Length);
  NextInstruction;
end;

procedure Block(Op: OperationPart; VarLabel, TempLabel, BeginLabel, LineNo: integer);
begin
  {Op in Operations[Procedure2, Program2 ]}
  Emit5(Op, Table[VarLabel], Table[TempLabel],
    JumpDispl(BeginLabel), LineNo);
  NextInstruction;
end;

procedure DefAddr(LabelNo: integer);
begin
  Table[LabelNo] := Address;
  NextInstruction;
end;

procedure DefArg(LabelNo, Value: integer);
begin
  Table[LabelNo] := Value;
  NextInstruction;
end;

procedure Field(Displ: integer);
begin
  if Optimize(Displ = 0) then { Empty }
  else
    Emit2(Field2, Displ);
  NextInstruction;
end;

procedure Jump(Op: OperationPart; LabelNo: integer);
begin
  {Op in Operations[Do2, Goto2]}
  Emit2(Op, JumpDispl(LabelNo));
  NextInstruction;
end;

procedure ProcCall(Level, LabelNo: integer);
var
  Displ: integer;
begin
  Displ := JumpDispl(LabelNo);
  if Optimize(Level = 1) then
    Emit2(GlobalCall2, Displ)
  else
    Emit3(ProcCall2, Level, Displ);
  NextInstruction;
end;

procedure Value(Length: integer);
begin
  if Optimize(Length = 1) then
    Emit1(SimpleValue2)
  else
    Emit2(Value2, Length);
  NextInstruction;
end;

procedure Variable(Level, Displ: integer);
begin
  Nextinstruction;
  while Optimize(Op = Field2) do
  begin
    Displ := Displ + Arg1;
    NextInstruction;
  end;

  if Optimize(Level = 0) then
    if (Op = Value2) and (Arg1 = 1) then
    begin
      Emit2(LocalValue2, Displ);
      NextInstruction;
    end
    else
      Emit2(LocalVar2, Displ)
  else if Optimize(Level = 1) then
    if (Op = Value2) and (Arg1 = 1) then
    begin
      Emit2(GlobalValue2, Displ);
      NextInstruction;
    end
    else
      Emit2(GlobalVar2, Displ)
  else
    Emit3(Variable2, Level, Displ);
end;

procedure CopyInstruction;
begin
  if Op in NoArguments then
    Emit1(Op)
  else if Op in OneArgument then
    Emit2(Op, Arg1)
  else if Op in TwoArguments then
    Emit3(Op, Arg1, Arg2)
  else {Op in FourArguments}
    Emit5(Op, Arg1, Arg2, Arg3, Arg4);
  NextInstruction;
end;

procedure Assemble2;
begin
  Address := 0;
  NextInstruction;
  while Op <> EndProg2 do
    if Op = Assign2 then
      Assign(Arg1)
    else if Op in Blocks then
      Block(Op, Arg1, Arg2, Arg3, Arg4)
    else if Op = DefAddr2 then
      DefAddr(Arg1)
    else if Op = DefArg2 then
      DefArg(Arg1, Arg2)
    else if Op = Field2 then
      Field(Arg1)
    else if Op in Jumps then
      Jump(Op, Arg1)
    else if Op = ProcCall2 then
      ProcCall(Arg1, Arg2)
    else if Op = Value2 then
      Value(Arg1)
    else if Op = Variable2 then
      Variable(Arg1, Arg2)
    else
      CopyInstruction;
  Emit1(EndProg2);
end;

procedure Initialize;
var
  LabelNo: integer;
begin
  NoArguments := [Add2, And2, Divide2, EndProg2, Equal2, Greater2,
    Less2, Minus2, Modulo2, Multiply2, Not2, NotEqual2, NotGreater2,
    NotLess2, Or2, Subtract2, Read2, Write2];

  OneArgument := [Assign2, Constant2, Do2, EndProc2, Field2, Goto2, Value2, DefAddr2];

  TwoArguments := [ProcCall2, Variable2, VarParam2, DefArg2];

  //FourArguments := [Index2, Procedure2, Program2];

  Blocks := [Procedure2, Program2];
  Jumps := [Do2, Goto2];

  LabelNo := 1;
  while LabelNo <= MaxLabel do
  begin
    Table[LabelNo] := 0;
    LabelNo := labelNo + 1;
  end;
  InitPass(PASS3_ASSEMBLE);
end;

procedure Assemble;
begin
  Initialize;
  Assemble2;
  Rerun;
  Assemble2;
  //DbgOutputPass3();
end;

end.
