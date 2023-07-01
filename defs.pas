unit defs;

interface

uses
  Classes, SysUtils;

const
  Integer0 = 1;
  Boolean0 = 2;
  False0 = 3;
  True0 = 4;
  Read0 = 5;
  Write0 = 6;

  NUM_SYMBOLS = 44;
  NUM_OPS = 40;

type
  ErrorKind = (Ambiguous3, Comment3, Kind3, Numeral3,
    Range3, Syntax3, Type3, Undefined3);

  OperationPart = (Add2, And2, Assign2,
    Constant2, Divide2, Do2, EndProc2, EndProg2,
    Equal2, Field2, Goto2, Greater2, Index2,
    Less2, Minus2, Modulo2, Multiply2, Not2,
    NotEqual2, NotGreater2, NotLess2, Or2,
    ProcCall2, Procedure2, Program2, Subtract2,
    Value2, Variable2, VarParam2, Read2,
    Write2, DefAddr2, DefArg2, GlobalCall2,
    GlobalValue2, GlobalVar2, LocalValue2,
    LocalVar2, SimpleAssign2, SimpleValue2);

  SymbolType =
    (And1, Array1, Asterisk1, Becomes1,
    Begin1, Colon1, Comma1, Const1, Div1, Do1,
    DoubleDot1, Else1, End1, EndText1, Equal1,
    Greater1, If1, LeftBracket1, LeftParenthesis1,
    Less1, Minus1, Mod1, Name1, NewLine1, Not1,
    NotEqual1, NotGreater1, NotLess1, Numeral1,
    Of1, Or1, Period1, Plus1, Procedure1, Program1,
    Record1, RightBracket1, RightParenthesis1,
    Semicolon1, Then1, Type1, Var1, While1,
    Unknown1);

function int2op(n: integer): OperationPart;
function int2symbol(n: integer): SymbolType;
function endSymbol: integer;
function symbolString(s: SymbolType): string;
function opsString(o: OperationPart): string;

implementation

const
  globalSymbolNames: array[0..NUM_SYMBOLS - 1] of string =
    ('And1', 'Array1', 'Asterisk1', 'Becomes1', 'Begin1',
    'Colon1', 'Comma1', 'Const1', 'Div1', 'Do1', 'DoubleDot1', 'Else1',
    'End1', 'EndText1', 'Equal1', 'Greater1', 'If1', 'LeftBracket1',
    'LeftParenthesis1', 'Less1', 'Minus1', 'Mod1', 'Name1', 'NewLine1',
    'Not1', 'NotEqual1', 'NotGreater1', 'NotLess1', 'Numeral1', 'Of1',
    'Or1', 'Period1', 'Plus1', 'Procedure1', 'Program1', 'Record1',
    'RightBracket1', 'RightParenthesis1', 'Semicolon1', 'Then1',
    'Type1', 'Var1', 'While1', 'Unknown1');

  globalOpsNames: array[0..NUM_OPS - 1] of string =
    ('Add2', 'And2', 'Assign2',
    'Constant2', 'Divide2',
    'Do2', 'EndProc2', 'EndProg2',
    'Equal2', 'Field2', 'Goto2', 'Greater2', 'Index2',
    'Less2', 'Minus2', 'Modulo2', 'Multiply2', 'Not2',
    'NotEqual2', 'NotGreater2', 'NotLess2', 'Or2',
    'ProcCall2', 'Procedure2', 'Program2', 'Subtract2',
    'Value2', 'Variable2', 'VarParam2', 'Read2',
    'Write2', 'DefAddr2', 'DefArg2', 'GlobalCall2',
    'GlobalValue2', 'GlobalVar2', 'LocalValue2',
    'LocalVar2', 'SimpleAssign2', 'SimpleValue2');

var
  endSymb: SymbolType;

function endSymbol: integer;
begin
  Result := integer(endSymb);
end;

function int2op(n: integer): OperationPart;
begin
  Result := OperationPart(n);
end;

function int2symbol(n: integer): SymbolType;
begin
  Result := SymbolType(n);
end;

function symbolString(s: SymbolType): string;
var
  n: integer;
begin
  n := integer(s);
  Result := globalSymbolNames[n];
end;

function opsString(o: OperationPart): string;
var
  n: integer;
begin
  n := integer(o);
  Result := globalOpsNames[n];
end;



initialization
  endSymb := EndText1;

end.
