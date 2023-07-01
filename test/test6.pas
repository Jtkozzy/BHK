{ Pascal- Test 6: Type Analysis }
program Test6;
const
  a = 10; b = false;
type
  T1 = array [a..a] of integer;
  T2 = record f, g: integer; h: Boolean end;
var
  x, y: integer; z: Boolean;

procedure Q(var x: T1; z: T2);
begin
  x[10] := 1;
  z.f := 1;
  Q(x, z)
end;

procedure P;
begin Read(x); Write(x + 1) end;

begin
  P;
  x := 1;
  x := a;
  x := y;
  x := - (x + 1) * (y - 1) div 9 mod 9;
  z := not b;
  x := z or z and z;
  if x <> y then
    while x < y do {Empty}
end.

