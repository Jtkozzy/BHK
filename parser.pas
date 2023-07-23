unit parser;

{PASCAL- COMPILER : Parser
Copyright (c) 1984 Per Brinch Hansen
Free pascal adaptation (c) Jari Korhonen, 2023}

interface

uses
  Classes, SysUtils;

procedure Parse();


implementation

uses defs, util, main;

const
  MaxLabel = 1000;
  MaxLevel = 10;
  NoName = 0;

type
  Symbols = set of SymbolType;

  ClassX = (Constantx, StandardType, ArrayType,
    RecordType, Field, Variable, ValueParameter,
    VarParameter, Procedur, StandardProc,
    Undefined);
  ClassXes = set of ClassX;
  ObjPointer = ^ObjectRecord;

  ObjectRecord = record
    Name: integer;
    Previous: ObjPointer;
    case Kind: ClassX of
      Constantx: (ConstValue: integer;
        ConstType: ObjPointer);
      ArrayType: (LowerBound,
        UpperBound: integer;
        IndexType, ElementType: ObjPointer);
      RecordType: (RecordLength: integer;
        LastField: ObjPointer);
      Field: (FieldDispl: integer;
        FieldType: ObjPointer);
      Variable, ValueParameter, VarParameter: (VarLevel, VarDispl: integer;
        VarType: ObjPointer);
      Procedur: (ProcLevel, ProcLabel: integer;
        LastParam: ObjPointer)
  end;

  BlockRecord = record
    TempLength, MaxTemp: integer;
    LastObject: ObjPointer
  end;

  BlockTable = array [0..MaxLevel] of BlockRecord;

var
  LineNo: integer;
  Symbol: SymbolType;
  Argument: integer;
  AddSymbols, BlockSymbols, ConstantSymbols, ExpressionSymbols,
  FactorSymbols, LongSymbols, MultiplySymbols, ParameterSymbols,
  RelationSymbols, SelectorSymbols, SignSymbols, SimpleExprSymbols,
  StatementSymbols, TermSymbols: Symbols;
  Block: BlockTable;
  BlockLevel: integer;
  Types, Variables, Procedures: ClassXes;
  TypeUniversal, TypeInteger, TypeBoolean: objPointer;
  LabelNo: integer;


{ INPUT }
procedure NextSymbol;
begin
  Symbol := int2symbol(UtilReadInt);
  while Symbol = NewLine1 do
  begin
    LineNo := UtilReadInt();
    NewLine(LineNo);
    Symbol := int2symbol(UtilReadInt);
  end;
  if Symbol in LongSymbols then
    Argument := UtilReadInt();
end;


{ OUTPUT }
procedure Emit1(Op: OperationPart);
begin
  Emit(Ord(Op));
  //Writeln(opsString(Op));
end;

procedure Emit2(Op: OperationPart; Arg: integer);
begin
  Emit(Ord(Op));
  Emit(Arg);
  //Writeln(opsString(Op), ': ', Arg);
end;

procedure Emit3(Op: OperationPart; Arg1, Arg2: integer);
begin
  Emit(Ord(Op));
  Emit(Arg1);
  Emit(Arg2);
  //Writeln(opsString(Op), ': ', Arg1, ' ', Arg2);
end;

procedure Emit5(Op: OperationPart; Arg1, Arg2, Arg3, Arg4: integer);
begin
  Emit(Ord(Op));
  Emit(Arg1);
  Emit(Arg2);
  Emit(Arg3);
  Emit(Arg4);
  //Writeln(opsString(Op), ': ', Arg1, ' ', Arg2, ' ', Arg3, ' ', Arg4);
end;


{ SCOPE ANALYSIS }
procedure Search(Name, LevelNo: integer; var Found: boolean; var Obj: ObjPointer);
var
  More: boolean;
begin
  More := True;
  Obj := Block[LevelNo].LastObject;
  while More do
  begin
    if Obj = nil then
    begin
      More := False;
      Found := False;
    end
    else if Obj^.Name = Name then
    begin
      More := False;
      Found := True;
    end
    else
    begin
      Obj := Obj^.Previous;
    end;
  end;
end;

procedure Define(Name: integer; Kind: ClassX; var Obj: ObjPointer);
var
  Found: boolean;
  Other: ObjPointer;
begin
  Other := nil;
  Found := False;
  if Name <> NoName then
  begin
    Search(Name, BlockLevel, Found, Other);
    if Found then
      Error(Ambiguous3);
  end;
  New(Obj);
  Obj^.Name := Name;
  Obj^.Previous := Block[BlockLevel].LastObject;
  Obj^.Kind := Kind;
  Block[BlockLevel].LastObject := Obj;
end;

procedure Find(Name: integer; var Obj: ObjPointer);
var
  More, Found: boolean;
  LevelNo: integer;
begin
  Found := False;
  More := True;
  LevelNo := BlockLevel;
  while More do
  begin
    Search(Name, LevelNo, Found, Obj);
    if Found or (LevelNo = 0) then
    begin
      More := False;
    end
    else
    begin
      LevelNo := LevelNo - 1;
    end;
  end;
  if not Found then
  begin
    Error(Undefined3);
    Define(Name, Undefined, Obj);
  end;
end;

procedure NewBlock;
var
  Current: BlockRecord;
begin
  TestLimit(BlockLevel, MaxLevel);
  BlockLevel := BlockLevel + 1;
  Current.TempLength := 0;
  Current.MaxTemp := 0;
  Current.LastObject := nil;
  Block[BlockLevel] := Current;
end;

procedure EndBlock;
begin
  BlockLevel := BlockLevel - 1;
end;

procedure StandardBlock;
var
  Constx, Proc: objPointer;
begin
  Constx := nil;
  Proc := nil;
  BlockLevel := -1;
  NewBlock;
  Define(NoName, StandardType, TypeUniversal);
  Define(Integer0, StandardType, TypeInteger);
  Define(Boolean0, StandardType, TypeBoolean);
  Define(False0, Constantx, Constx);
  Constx^.ConstValue := Ord(False);
  Constx^.ConstType := TypeBoolean;
  Define(True0, Constantx, Constx);
  Constx^.ConstValue := Ord(True);
  Constx^.ConstType := TypeBoolean;
  Define(Read0, StandardProc, Proc);
  Define(Write0, StandardProc, Proc);
end;


{ TYPE ANALYSIS }
procedure CheckTypes(var Type1: objPointer; Type2: objPointer);
begin
  if Type1 <> Type2 then
  begin
    if (Type1 <> TypeUniversal) and (Type2 <> TypeUniversal) then
    begin
      Error(Type3);
    end;
    Type1 := TypeUniversal;
  end;
end;

procedure TypeError(var Typex: objPointer);
begin
  if Typex <> TypeUniversal then
  begin
    Error(Type3);
    Typex := TypeUniversal;
  end;
end;

procedure KindError(Obj: objPointer);
begin
  if Obj^.Kind <> Undefined then
  begin
    Error(Kind3);
  end;
end;


{ VARIABLE ADDRESSING }
function TypeLength(Typex: objPointer): integer;
begin
  if Typex^.Kind = StandardType then
    Result := 1
  else if Typex^.Kind = ArrayType then
    Result := (Typex^.UpperBound - Typex^.LowerBound + 1) *
      TypeLength(Typex^.ElementType)
  else { Typex^.Kind = RecordType }
    Result := Typex^.RecordLength;
end;

procedure FieldAddressing(RecordLength: integer; LastField: objPointer);
var
  Displ: integer;
begin
  Displ := RecordLength;
  while Displ > 0 do
  begin
    Displ := Displ - TypeLength(LastField^.FieldType);
    LastField^.FieldDispl := Displ;
    LastField := LastField^.Previous;
  end;
end;

procedure VariableAddressing(VarLength: integer; LastVar: objPointer);
var
  Displ: integer;
begin
  Displ := 3 + VarLength;
  while Displ > 3 do
  begin
    Displ := Displ - TypeLength(LastVar^.VarType);
    LastVar^.VarLevel := BlockLevel;
    LastVar^.VarDispl := Displ;
    LastVar := LastVar^.Previous;
  end;
end;

procedure ParameterAddressing(ParamLength: integer; LastParam: objPointer);
var
  Displ: integer;
begin
  Displ := 0;
  while Displ > -ParamLength do
  begin
    if LastParam^.Kind = VarParameter then
      Displ := Displ - 1
    else {LastParam^.Kind = ValueParameter}
      Displ := Displ - TypeLength(LastParam^.VarType);
    LastParam^.VarLevel := BlockLevel;
    LastParam^.VarDispl := Displ;
    LastParam := LastParam^.Previous;
  end;
end;


{ LABELS }
procedure NewLabel(var No: integer);
begin
  TestLimit(LabelNo, MaxLabel);
  LabelNo := LabelNo + 1;
  No := LabelNo;
end;


{ TEMPORARIES }
procedure Push(Length: integer);
begin
  Block[BlockLevel].TempLength := Block[BlockLevel].TempLength + Length;
  if Block[BlockLevel].MaxTemp < Block[BlockLevel].TempLength then
  begin
    Block[BlockLevel].MaxTemp := Block[BlockLevel].TempLength;
  end;
end;

procedure Pop(Length: integer);
begin
  Block[BlockLevel].TempLength := Block[BlockLevel].TempLength - Length;
end;


{ INITIALIZATION }
procedure Initialize;
begin
  AddSymbols := [Minus1, Or1, Plus1];
  BlockSymbols := [Begin1, Const1, Procedure1, Type1, Var1];
  ConstantSymbols := [Name1, Numeral1];
  ExpressionSymbols := [LeftParenthesis1, Minus1, Name1, Not1, Numeral1, Plus1];
  FactorSymbols := [LeftParenthesis1, Name1, Not1, Numeral1];
  LongSymbols := [Name1, Numeral1];
  MultiplySymbols := [And1, Asterisk1, Div1, Mod1];
  ParameterSymbols := [Name1, Var1];
  RelationSymbols := [Equal1, Greater1, Less1, NotEqual1, NotGreater1, NotLess1];
  SelectorSymbols := [LeftBracket1, Period1];
  SignSymbols := [Minus1, Plus1];
  StatementSymbols := [Begin1, If1, Name1, While1];
  TermSymbols := FactorSymbols;
  SimpleExprSymbols := SignSymbols + TermSymbols;
  Types := [StandardType, ArrayType, RecordType];
  Variables := [Variable, ValueParameter, VarParameter];
  Procedures := [Procedur, StandardProc];
  LabelNo := 0;
  InitPass(PASS2_PARSE);
end;


{ SYNTAX ANALYSIS }
procedure SyntaxError(Stop: Symbols);
begin
  Error(Syntax3);
  while not (Symbol in Stop) do
  begin
    NextSymbol;
  end;
end;

procedure SyntaxCheck(Stop: Symbols);
begin
  if not (Symbol in Stop) then
    SyntaxError(Stop);
end;

procedure Expect(s: SymbolType; Stop: Symbols);
begin
  if Symbol = s then
    NextSymbol
  else
    SyntaxError(Stop);
  SyntaxCheck(Stop);
end;

procedure ExpectName(var Name: integer; Stop: Symbols);
begin
  if Symbol = Name1 then
  begin
    Name := Argument;
    NextSymbol;
  end
  else
  begin
    Name := NoName;
    SyntaxError(Stop);
  end;
  SyntaxCheck(Stop);
end;


// TypeName = Name .
procedure TypeName(var Typex: objPointer; Stop: Symbols);
var
  obj: objPointer;
begin
  obj := nil;
  if Symbol = Name1 then
  begin
    Find(Argument, Obj);
    if Obj^.Kind in Types then
      Typex := Obj
    else
    begin
      KindError(Obj);
      Typex := TypeUniversal;
    end;
  end
  else
    Typex := TypeUniversal;

  Expect(Name1, Stop);
end;


// Constant = Numeral | ConstantName .
procedure Constant(var Value: integer; var Typex: objPointer; Stop: Symbols);
var
  obj: objPointer;
begin
  obj := nil;
  if Symbol = Numeral1 then
  begin
    Value := Argument;
    Typex := TypeInteger;
    Expect(Numeral1, Stop);
  end
  else if Symbol = Name1 then
  begin
    Find(Argument, Obj);
    if Obj^.Kind = Constantx then
    begin
      Value := Obj^.ConstValue;
      Typex := Obj^.ConstType;
    end
    else
    begin
      KindError(Obj);
      Value := 0;
      Typex := TypeUniversal;
    end;
    Expect(Name1, Stop);
  end
  else
  begin
    SyntaxError(Stop);
    Value := 0;
    Typex := TypeUniversal;
  end;
end;


// ConstantDefinition = ConstantName "=" Constant ";" .
procedure ConstantDefinition(Stop: Symbols);
var
  Name, Value: integer;
  Constx, Typex: objPointer;
begin
  Constx := nil;
  Typex := nil;
  Name := 0;
  Value := 0;
  ExpectName(Name, [Equal1, Semicolon1] + ConstantSymbols + Stop);
  Expect(Equal1, ConstantSymbols + [Semicolon1] + Stop);
  Constant(Value, Typex, [Semicolon1] + Stop);
  Define(Name, Constantx, Constx);
  Constx^.ConstValue := Value;
  Constx^.ConstType := Typex;
  Expect(Semicolon1, Stop);
end;


// ConstantDefinitionPart = "const" ConstantDefinition { ConstantDefinition } .
procedure ConstantDefinitionPart(Stop: Symbols);
var
  Stop2: Symbols;
begin
  Stop2 := [Name1] + Stop;
  Expect(Const1, Stop2);
  ConstantDefinition(Stop2);
  while Symbol = Name1 do
  begin
    ConstantDefinition(Stop2);
  end;
end;


// NewArrayType = "array" "[" IndexRange "]" "of" TypeName
// IndexRange = Constant ".." Constant .
procedure NewArrayType(Name: integer; Stop: Symbols);
var
  NewType, LowerType, UpperType, ElementType: objPointer;
  LowerBound, UpperBound: integer;
begin
  NewType := nil;
  LowerType := nil;
  UpperType := nil;
  ElementType := nil;
  LowerBound := 0;
  UpperBound := 0;
  Expect(Array1, [LeftBracket1, RightBracket1, Of1, Name1] + ConstantSymbols + Stop);
  Expect(LeftBracket1, [RightBracket1, Of1, Name1] + ConstantSymbols + Stop);
  Constant(LowerBound, LowerType, [DoubleDot1, RightBracket1, Of1, Name1] +
    ConstantSymbols + Stop);
  Expect(DoubleDot1, [RightBracket1, Of1, Name1] + ConstantSymbols + Stop);
  Constant(UpperBound, UpperType, [RightBracket1, Of1, Name1] + Stop);
  CheckTypes(LowerType, UpperType);
  if LowerBound > UpperBound then
  begin
    Error(Range3);
    LowerBound := UpperBound;
  end;
  Expect(RightBracket1, [Of1, Name1] + Stop);
  Expect(Of1, [Name1] + Stop);
  TypeName(ElementType, Stop);
  Define(Name, ArrayType, NewType);
  NewType^.LowerBound := LowerBound;
  NewType^.UpperBound := UpperBound;
  NewType^.IndexType := LowerType;
  NewType^.ElementType := ElementType;
end;


// RecordSection = FieldName SectionTail .
// SectionTail = "," RecordSection | ":" TypeName .
procedure RecordSection(var Number: integer; var LastField, Typex: objPointer;
  Stop: Symbols);
var
  Name: integer;
  Fieldx: objPointer;
begin
  Name := 0;
  Fieldx := nil;
  ExpectName(Name, [Comma1, Colon1] + Stop);
  Define(Name, Field, Fieldx);
  if Symbol = Comma1 then
  begin
    Expect(Comma1, [Name1] + Stop);
    RecordSection(Number, LastField, Typex, Stop);
    Number := Number + 1;
  end
  else
  begin
    Expect(Colon1, [Name1] + Stop);
    TypeName(Typex, Stop);
    LastField := Fieldx;
    Number := 1;
  end;
  Fieldx^.FieldType := Typex;
end;


// FieldList = RecordSection { ";" RecordSection } .
procedure FieldList(var LastField: objPointer; var Length: integer; Stop: Symbols);
var
  Stop2: Symbols;
  Number: integer;
  Typex: objPointer;
begin
  Typex := nil;
  Number := 0;
  Stop2 := [Semicolon1] + Stop;
  RecordSection(Number, LastField, Typex, Stop2);
  Length := Number * TypeLength(Typex);
  while Symbol = Semicolon1 do
  begin
    Expect(Semicolon1, [Name1] + Stop2);
    RecordSection(Number, LastField, Typex, Stop2);
    Length := Length + Number * TypeLength(Typex);
  end;
  FieldAddressing(Length, LastField);
end;


// NewRecordType = "record" FieldList "end" ,
procedure NewRecordType(Name: integer; Stop: Symbols);
var
  NewType, LastField: objPointer;
  Length: integer;
begin
  NewType := nil;
  LastField := nil;
  Length := 0;
  NewBlock;
  Expect(Record1, [Name1, End1] + Stop);
  FieldList(LastField, Length, [End1] + Stop);
  Expect(End1, Stop);
  EndBlock;
  Define(Name, RecordType, NewType);
  NewType^.RecordLength := Length;
  NewType^.LastField := LastField;
end;


// TypeDefinition = TypeName "=" NewType ";" .
// NewType = NewArrayType | NewRecordType .
procedure TypeDefinition(Stop: Symbols);
var
  Stop2: Symbols;
  Name: integer;
  obj: objPointer;
begin
  Name := 0;
  obj := nil;
  Stop2 := [Semicolon1] + Stop;
  ExpectName(Name, [Equal1, Array1, Record1] + Stop2);
  Expect(Equal1, [Array1, Record1] + Stop2);
  if Symbol = Array1 then
    NewArrayType(Name, Stop2)
  else if Symbol = Record1 then
    NewRecordType(Name, Stop2)
  else
  begin
    Define(Name, Undefined, obj);
    SyntaxError(Stop2);
  end;
  Expect(Semicolon1, Stop);
end;


// TypeDefinitionPart = "type" TypeDefinition {TypeDefinition} .
procedure TypeDefinitionPart(Stop: Symbols);
var
  Stop2: Symbols;
begin
  Stop2 := [Name1] + Stop;
  Expect(Type1, Stop2);
  TypeDefinition(Stop2);
  while Symbol = Name1 do
  begin
    TypeDefinition(Stop2);
  end;
end;


// VariableGroup = VariableName GroupTail .
// GroupTail = "," VariableGroup | ":" TypeName .
procedure VariableGroup(Kind: ClassX; var Number: integer;
  var LastVar, Typex: objPointer; Stop: Symbols);
var
  Name: integer;
  Varx: objPointer;
begin
  Name := 0;
  Varx := nil;
  ExpectName(Name, [Comma1, Colon1] + Stop);
  Define(Name, Kind, Varx);
  if Symbol = Comma1 then
  begin
    Expect(Comma1, [Name1] + Stop);
    VariableGroup(Kind, Number, LastVar, Typex, Stop);
    Number := Number + 1;
  end
  else
  begin
    Expect(Colon1, [Name1] + Stop);
    TypeName(Typex, Stop);
    LastVar := Varx;
    Number := 1;
  end;
  Varx^.VarType := Typex;
end;


// VariableDefinition = VariableGroup ";" .
procedure VariableDefinition(var LastVar: objPointer; var Length: integer;
  Stop: Symbols);
var
  Number: integer;
  Typex: objPointer;
begin
  Number := 0;
  TYpex := nil;
  VariableGroup(Variable, Number, LastVar,
    Typex, [Semicolon1] + Stop);
  Length := Number * TypeLength(Typex);
  Expect(Semicolon1, Stop);
end;


// VariableDefinitionPart = "var" VariableDefinition { VariableDefinition } .
procedure VariableDefinitionPart(var Length: integer; Stop: Symbols);
var
  Stop2: Symbols;
  LastVar: objPointer;
  More: integer;
begin
  LastVar := nil;
  More := 0;
  Stop2 := [Name1] + Stop;
  Expect(Var1, Stop2);
  VariableDefinition(LastVar, Length, Stop2);
  while Symbol = Name1 do
  begin
    VariableDefinition(LastVar, More, Stop2);
    Length := Length + More;
  end;
  VariableAddressing(Length, LastVar);
end;


// ParameterDefinition = [ "var" ] VariableGroup .
procedure ParameterDefinition(var LastParam: objPointer; var Length: integer;
  Stop: Symbols);
var
  Number: integer;
  Typex: objPointer;
begin
  Number := 0;
  Typex := nil;
  SyntaxCheck([Var1, Name1] + Stop);
  if Symbol = Var1 then
  begin
    Expect(Var1, [Name1] + Stop);
    VariableGroup(VarParameter, Length, Lastparam, Typex, Stop);
  end
  else
  begin
    VariableGroup(ValueParameter, Number, LastParam, Typex, Stop);
    Length := Number * TypeLength(Typex);
  end;
end;


// FormalParameterList = ParameterDefinition { ";" ParameterDefinition } .
procedure FormalParameterList(var LastParam: objPointer; var Length: integer;
  Stop: Symbols);
var
  Stop2: Symbols;
  More: integer;
begin
  More := 0;
  Stop2 := [Semicolon1] + Stop;
  ParameterDefinition(LastParam, Length, Stop2);
  while Symbol = Semicolon1 do
  begin
    Expect(Semicolon1, ParameterSymbols + Stop2);
    ParameterDefinition(LastParam, More, Stop2);
    Length := Length + More;
  end;
  ParameterAddressing(Length, LastParam);
end;


// ProcedureDefinition = "procedure" ProcedureName ProcedureBlock ";" .
// ProcedureBlock = [ "(" FormalParameterList ")" ] ";" BlockBody .
procedure BlockBody(BeginLabel, VarLabel, Templabel: integer; Stop: Symbols); forward;

procedure ProcedureDefinition(Stop: Symbols);
var
  Name: integer;
  Proc: objPointer;
  ParamLength, VarLabel, TempLabel, BeginLabel: integer;
begin
  Name := 0;
  Proc := nil;
  ParamLength := 0;
  VarLabel := 0;
  TempLabel := 0;
  BeginLabel := 0;
  Expect(Procedure1, [Name1, LeftParenthesis1, Semicolon1] + BlockSymbols + Stop);
  ExpectName(Name, [LeftParenthesis1, Semicolon1] + BlockSymbols + Stop);
  Define(Name, Procedur, Proc);
  Proc^.ProcLevel := BlockLevel;
  NewLabel(Proc^.ProcLabel);
  NewBlock;
  if Symbol = LeftParenthesis1 then
  begin
    Expect(LeftParenthesis1, ParameterSymbols + [RightParenthesis1, Semicolon1] +
      BlockSymbols + Stop);
    FormalParameterList(Proc^.LastParam, ParamLength, [RightParenthesis1, SemiColon1] +
      BlockSymbols + Stop);
    Expect(RightParenthesis1, [Semicolon1] + BlockSymbols + Stop);
  end
  else {no parameter list}
  begin
    Proc^.LastParam := nil;
    ParamLength := 0;
  end;
  NewLabel(VarLabel);
  NewLabel(TempLabel);
  NewLabel(BeginLabel);
  Emit2(DefAddr2, Proc^.ProcLabel);
  Emit5(Procedure2, VarLabel, TempLabel, BeginLabel, LineNo);
  Expect(Semicolon1, [Semicolon1] + BlockSymbols + Stop);
  BlockBody(BeginLabel, VarLabel, TempLabel, [Semicolon1] + Stop);
  Expect(Semicolon1, Stop);
  Emit2(EndProc2, ParamLength);
  EndBlock;
end;


// IndexedSelector = "[" Expression "]" .
procedure Expression(var Typex: objPointer; Stop: Symbols); forward;

procedure IndexedSelector(var Typex: objPointer; Stop: Symbols);
var
  ExprType: objPointer;
begin
  ExprType := nil;
  Expect(LeftBracket1, ExpressionSymbols + [RightBracket1] + Stop);
  Expression(ExprType, [RightBracket1] + Stop);
  if Typex^.Kind = ArrayType then
  begin
    CheckTypes(ExprType, Typex^.IndexType);
    Emit5(Index2, Typex^.LowerBound, Typex^.UpperBound,
      TypeLength(Typex^.ElementType), LineNo);
    Pop(1);
    Typex := Typex^.ElementType;
  end
  else
  begin
    KindError(Typex);
    Typex := TypeUniversal;
  end;
  Expect(RightBracket1, Stop);
end;


// FieldSelector = "." FieldName .
procedure FieldSelector(var Typex: objPointer; Stop: Symbols);
var
  Found: boolean;
  Fieldx: objPointer;
begin
  Expect(Period1, [Name1] + Stop);
  if Symbol = Name1 then
  begin
    if Typex^.Kind = RecordType then
    begin
      Found := False;
      Fieldx := Typex^.LastField;
      while not Found and (Fieldx <> nil) do
      begin
        if Fieldx^.Name <> Argument then
          Fieldx := Fieldx^.Previous
        else
          Found := True;
      end;

      if Found then
      begin
        Typex := Fieldx^.FieldType;
        Emit2(Field2, Fieldx^.FieldDispl);
      end
      else
      begin
        Error(Undefined3);
        Typex := TypeUniversal;
      end;
    end
    else
    begin
      KindError(Typex);
      Typex := TypeUniversal;
    end;
    Expect(Name1, Stop);
  end
  else
  begin
    SyntaxError(Stop);
    Typex := TypeUniversal;
  end;
end;


// VariableAccess = VariableName { Selector } .
// Selector = IndexedSelector | FieldSelector .
procedure VariableAccess(var Typex: objPointer; Stop: Symbols);
var
  Stop2: Symbols;
  obj: objPointer;
  Level, Displ: integer;
begin
  obj := nil;
  if Symbol = Name1 then
  begin
    Stop2 := SelectorSymbols + Stop;
    Find(Argument, obj);
    Expect(Name1, Stop2);
    if Obj^.Kind in Variables then
    begin
      Typex := Obj^.VarType;
      Level := BlockLevel - Obj^.VarLevel;
      Displ := Obj^.VarDispl;
      if Obj^.Kind = VarParameter then
        Emit3(VarParam2, Level, Displ)
      else
        Emit3(Variable2, Level, Displ);
      Push(1);
    end
    else
    begin
      KindError(obj);
      Typex := TypeUniversal;
    end;

    while Symbol in SelectorSymbols do
    begin
      if Symbol = LeftBracket1 then
        IndexedSelector(Typex, Stop2)
      else {Symbol = Period1}
        FieldSelector(Typex, Stop2);
    end;
  end
  else
  begin
    SyntaxError(Stop);
    Typex := TypeUniversal;
  end;
end;


// Factor = Constant | VariableAccess | "(" Expression ")" | "not" Factor .
procedure Factor(var Typex: objPointer; Stop: Symbols);
var
  obj: objPointer;
  Value, Length: integer;
begin
  Value := 0;
  obj := nil;
  if Symbol = Numeral1 then
  begin
    Constant(Value, Typex, Stop);
    Emit2(Constant2, Value);
    Push(1);
  end
  else if Symbol = Name1 then
  begin
    Find(Argument, obj);
    if obj^.Kind = Constantx then
    begin
      Constant(Value, Typex, Stop);
      Emit2(Constant2, Value);
      Push(1);
    end
    else if Obj^.Kind in Variables then
    begin
      VariableAccess(Typex, Stop);
      Length := TypeLength(Typex);
      Emit2(Value2, Length);
      Push(Length - 1);
    end
    else
    begin
      KindError(obj);
      Typex := TypeUniversal;
      Expect(Name1, Stop);
    end;
  end
  else if Symbol = LeftParenthesis1 then
  begin
    Expect(LeftParenthesis1, ExpressionSymbols + [RightParenthesis1] + Stop);
    Expression(Typex, [RightParenthesis1] + Stop);
    Expect(RightParenthesis1, Stop);
  end
  else if Symbol = Not1 then
  begin
    Expect(Not1, FactorSymbols + Stop);
    Factor(Typex, Stop);
    CheckTypes(Typex, TypeBoolean);
    Emit1(Not2);
  end
  else
  begin
    SyntaxError(Stop);
    Typex := TypeUniversal;
  end;
end;


// Term = Factor {MultiplyingOperator Factor } .
// MultiplyingOperator = "*" | "div" | "mod" | "and" .
procedure Term(var Typex: objPointer; Stop: Symbols);
var
  Stop2: Symbols;
  Oper: SymbolType;
  Type2: objPointer;
begin
  Type2 := nil;
  Stop2 := MultiplySymbols + Stop;
  Factor(Typex, Stop2);
  while Symbol in MultiplySymbols do
  begin
    Oper := Symbol;
    Expect(Symbol, FactorSymbols + Stop2);
    Factor(Type2, Stop2);
    if Typex = TypeInteger then
    begin
      CheckTypes(Typex, Type2);
      if Oper = Asterisk1 then
        Emit1(Multiply2)
      else if Oper = Div1 then
        Emit1(Divide2)
      else if Oper = Mod1 then
        Emit1(Modulo2)
      else { Operator = And1 }
        TypeError(Typex);
      Pop(1);
    end
    else if Typex = TypeBoolean then
    begin
      CheckTypes(Typex, Type2);
      if Oper = And1 then
        Emit1(And2)
      else { Arithmetic Operator }
        TypeError(Typex);
      Pop(1);
    end
    else
    begin
      TypeError(Typex);
    end;
  end;
end;


// SimpleExpression = [ SignOperator ] Term { AddingOperator Term } .
// SignOperator = "+" | "-" .
// AddingOperator = "+" | "-" | "or" .
procedure SimpleExpression(var Typex: objPointer; Stop: Symbols);
var
  Stop2: Symbols;
  Oper: SymbolType;
  Type2: objPointer;
begin
  Type2 := nil;
  Stop2 := AddSymbols + Stop;
  SyntaxCheck(SignSymbols + TermSymbols + Stop2);
  if Symbol in SignSymbols then
  begin
    Oper := Symbol;
    Expect(Symbol, TermSymbols + Stop2);
    Term(Typex, Stop2);
    CheckTypes(Typex, TypeInteger);
    if Oper = Minus1 then
      Emit1(Minus2);
  end
  else
  begin
    Term(Typex, Stop2);
  end;

  while Symbol in AddSymbols do
  begin
    Oper := Symbol;
    Expect(Symbol, TermSymbols + Stop2);
    Term(Type2, Stop2);
    if Typex = TypeInteger then
    begin
      CheckTypes(Typex, Type2);
      if Oper = Plus1 then
        Emit1(Add2)
      else if Oper = Minus1 then
        Emit1(Subtract2)
      else { Operator = Or1 }
        TypeError(Typex);
      Pop(1);
    end
    else if Typex = TypeBoolean then
    begin
      CheckTypes(Typex, Type2);
      if Oper = Or1 then
        Emit1(Or2)
      else { Arithmetic Operator }
        TypeError(Typex);
      Pop(1);
    end
    else
      TypeError(Typex);
  end;
end;


// Expression = SimpleExpression [ RelationalOperator SimpleExpression ] .
// RelationalOperator = "<" | "=" | ">" | "<=" | "<>" | ">=" .
procedure Expression(var Typex: objPointer; Stop: Symbols);
var
  oper: SymbolType;
  Type2: objPointer;
begin
  Type2 := nil;
  SimpleExpression(Typex, RelationSymbols + Stop);
  if Symbol in RelationSymbols then
  begin
    oper := Symbol;
    Expect(Symbol, SimpleExprSymbols + Stop);
    SimpleExpression(Type2, Stop);
    if Typex^.Kind = StandardType then
    begin
      CheckTypes(Typex, Type2);
      if oper = Less1 then
        Emit1(Less2)
      else if oper = Equal1 then
        Emit1(Equal2)
      else if oper = Greater1 then
        Emit1(Greater2)
      else if oper = NotGreater1 then
        Emit1(NotGreater2)
      else if oper = NotEqual1 then
        Emit1(NotEqual2)
      else { Operator = NotLess1 }
        Emit1(NotLess2);
      Pop(1);
    end
    else
    begin
      TypeError(Typex);
    end;
    Typex := TypeBoolean;
  end;
end;


// IOStatement = "Read" "(" VariableAccess ")" | "Write" "(" Expression ")" .
procedure IOStatement(Stop: Symbols);
var
  Stop2: Symbols;
  Name: integer;
  Typex: objPointer;
begin
  Typex := nil;
  {Symbol = (Standard Procedure) Namet1}
  Stop2 := [RightParenthesis1] + Stop;
  Name := Argument;
  Expect(Name1, ExpressionSymbols + Stop2);
  Expect(LeftParenthesis1, ExpressionSymbols + Stop2);
  if Name = Read0 then
  begin
    VariableAccess(Typex, Stop2);
    Emit1(Read2);
  end
  else {Name = Write0}
  begin
    Expression(Typex, Stop2);
    Emit1(Write2);
  end;
  Pop(1);
  CheckTypes(Typex, Typeinteger);
  Expect(RightParenthesis1, Stop);
end;


// ActualParameterList = [ActualParameterList "," ] ActualParameter
// ActualParameter = Expression | VariableAccess .
procedure ActualParameterList(LastParam: objPointer; var Length: integer; Stop: Symbols);
var
  Typex: objPointer;
  More: integer;
begin
  Typex := nil;
  More := 0;
  {LastParam <> nil}
  if LastParam^.Previous <> nil then
  begin
    ActualParameterList(LastParam^.Previous, More,
      [Comma1] + ExpressionSymbols + Stop);
    Expect(Comma1, ExpressionSymbols + Stop);
  end
  else
    More := 0;

  if LastParam^.Kind = ValueParameter then
  begin
    Expression(Typex, Stop);
    Length := TypeLength(Typex) + More;
  end
  else {LastParam^.Kind = VarParameter}
  begin
    VariableAccess(Typex, Stop);
    Length := 1 + More;
  end;
  CheckTypes(Typex, LastParam^.VarType);
end;


//ProcedureStatement = IO0Statement | ProcedureName [ "(" ActualParameterList ")" ] .
procedure ProcedureStatement(Stop: Symbols);
var
  Stop2: Symbols;
  Proc: objPointer;
  ParamLength: integer;
begin
  Proc := nil;
  ParamLength := 0;
  {Symbol = (Procedure) Name1}
  Find(Argument, Proc);
  if Proc^.Kind = StandardProc then
    IOStatement(Stop)
  else
  begin
    if Proc^.LastParam <> nil then
    begin
      Stop2 := [RightParenthesis1] + Stop;
      Expect(Name1, [LeftParenthesis1] + ExpressionSymbols + Stop2);
      Expect(LeftParenthesis1, ExpressionSymbols + Stop2);
      ActualParameterList(Proc^.LastParam, ParamLength, Stop2);
      Expect(RightParenthesis1, Stop);
    end
    else {no parameter list}
    begin
      Expect(Name1, Stop);
      ParamLength := 0;
    end;
    Emit3(ProcCall2,
      BlockLevel - Proc^.ProcLevel,
      Proc^.ProcLabel);
    Push(3);
    Pop(ParamLength + 3);
  end;
end;


// AssignmentStatement = VariableAccess ":=" Expression .
procedure AssignmentStatement(Stop: Symbols);
var
  VarType, ExprType: objPointer;
  Length: integer;
begin
  VarType := nil;
  ExprType := nil;
  VariableAccess(VarType, [Becomes1] + ExpressionSymbols + Stop);
  Expect(Becomes1, ExpressionSymbols + Stop);
  Expression(ExprType, Stop);
  CheckTypes(VarType, ExprType);
  Length := TypeLength(ExprType);
  Emit2(Assign2, Length);
  Pop(1 + Length);
end;


// IfStatement = "if" Expression "then" Statement [ "else" Statement ] .
procedure Statement(Stop: Symbols); forward;

procedure IfStatement(Stop: Symbols);
var
  ExprType: objPointer;
  Label1, Label2: integer;
begin
  Label1 := 0;
  Label2 := 0;
  ExprType := nil;
  Expect(If1, ExpressionSymbols + [Then1, Else1] + StatementSymbols + Stop);
  Expression(ExprType, [Then1, Else1] + StatementSymbols + Stop);
  CheckTypes(ExprType, TypeBoolean);
  Expect(Then1, StatementSymbols + [Else1] + Stop);
  NewLabel(Label1);
  Emit2(Do2, Label1);
  Pop(1);
  Statement([Else1] + Stop);
  if Symbol = Else1 then
  begin
    Expect(Else1, StatementSymbols + Stop);
    NewLabel(Label2);
    Emit2(Goto2, Label2);
    Emit2(DefAddr2, Label1);
    Statement(Stop);
    Emit2(DefAddr2, Label2);
  end
  else
  begin
    Emit2(DefAddr2, Label1);
  end;
end;


// WhileStatement = "while" Expression "do" Statement .
procedure WhileStatement(Stop: Symbols);
var
  Label1, Label2: integer;
  ExprType: objPointer;
begin
  Label1 := 0;
  Label2 := 0;
  ExprType := nil;
  NewLabel(Label1);
  Emit2(DefAddr2, Label1);
  Expect(While1, ExpressionSymbols + [Do1] + StatementSymbols + Stop);
  Expression(ExprType, [Do1] + StatementSymbols + Stop);
  CheckTypes(ExprType, TypeBoolean);
  Expect(Do1, StatementSymbols + Stop);
  NewLabel(Label2);
  Emit2(Do2, Label2);
  Pop(1);
  Statement(Stop);
  Emit2(Goto2, Label1);
  Emit2(DefAddr2, Label2);
end;


// Statement = AssignmentStatement | ProcedureStatement
// | IfStatement | WhileStatement | CompoundStatement | Empty .
procedure CompoundStatement(Stop: Symbols); forward;

procedure Statement(Stop: Symbols);
var
  obj: objPointer;
begin
  obj := nil;
  if Symbol = Name1 then
  begin
    Find(Argument, obj);
    if obj^.Kind in Variables then
    begin
      AssignmentStatement(Stop);
    end
    else if obj^.Kind in Procedures then
    begin
      ProcedureStatement(Stop);
    end
    else
    begin
      KindError(obj);
      Expect(Name1, Stop);
    end;
  end
  else if Symbol = If1 then
  begin
    IfStatement(Stop);
  end
  else if Symbol = While1 then
  begin
    WhileStatement(Stop);
  end
  else if Symbol = Begin1 then
  begin
    CompoundStatement(Stop);
  end
  else
  begin {Empty}
    SyntaxCheck(Stop);
  end;
end;


// CompoundStatement = "begin" Statement { ";" Statement } "end" .
procedure CompoundStatement(Stop: Symbols);
begin
  Expect(Begin1, StatementSymbols + [Semicolon1, End1] + Stop);
  Statement([Semicolon1, End1] + Stop);
  while Symbol = Semicolon1 do
  begin
    Expect(Semicolon1, StatementSymbols + [Semicolon1, End1] + Stop);
    Statement([Semicolon1, End1] + Stop);
  end;
  Expect(End1, Stop);
end;

// BlockBody = [ ConstantDefinitionPart ] [ TypeDefinitionPart ]
// [ VariableDefinitionPart ] { ProcedureDefinition }
// CompoundStatement .
procedure BlockBody(BeginLabel, VarLabel, Templabel: integer; Stop: Symbols);
var
  VarLength: integer;
begin
  VarLength := 0;
  SyntaxCheck(BlockSymbols + Stop);
  if Symbol = Const1 then
    ConstantDefinitionPart([Type1, Var1, Procedure1, Begin1] + Stop);
  if Symbol = Type1 then
    TypeDefinitionPart([Var1, Procedure1, Begin1] + Stop);
  if Symbol = Var1 then
    VariableDefinitionPart(VarLength, [Procedure1, Begin1] + Stop)
  else
    VarLength := 0;

  while Symbol = Procedure1 do
  begin
    ProcedureDefinition([Procedure1, Begin1] + Stop);
  end;

  Emit2(DefAddr2, BeginLabel);
  CompoundStatement(Stop);
  Emit3(DefArg2, VarLabel, VarLength);
  Emit3(DefArg2, TempLabel, Block[BlockLevel].MaxTemp);
end;


// Program = "program" ProgramName ";" BlockBody "." .
procedure Programx(Stop: Symbols);
var
  VarLabel, TempLabel, BeginLabel: integer;
begin
  VarLabel := 0;
  TempLabel := 0;
  BeginLabel := 0;
  Expect(Program1, [Name1, Semicolon1, Period1] + BlockSymbols + Stop);
  Expect(Name1, [Semicolon1, Period1] + BlockSymbols + Stop);
  NewLabel(VarLabel);
  NewLabel(TempLabel);
  NewLabel(BeginLabel);
  Emit5(Program2, VarLabel, TempLabel, BeginLabel, LineNo);
  Expect(Semicolon1, [Period1] + BlockSymbols + Stop);
  NewBlock;
  BlockBody(BeginLabel, VarLabel, TempLabel, [Period1] + Stop);
  Emit1(EndProg2);
  EndBlock;
  Expect(Period1, Stop);
end;


procedure Parse();
begin
  Initialize;
  NextSymbol;
  StandardBlock;
  Programx([EndText1]);
  //DbgOutputPass2();
end;

end.
