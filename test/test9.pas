{ Pascal- Test 9: Code Generation
  Correct output:
0 1 2 3 4 5 6 7 -8 9 10 11 12 13
1 0 1 1 0 0 1 1 0 14 15 16 17 }

program Test9;
  const two = 2;
type
  S = array [1..10] of integer;
  T = record f, g: integer end;
var a: integer; b, c: S; d, e: T;

procedure WriteBool(x: Boolean);
begin if x then Write(1) else Write(0) end;

procedure EchoOne;
begin Read(a); Write(a) end;

procedure P(u: integer; var v: integer);
var x: integer;
begin {u = 2, v is bound to a}
  EchoOne;
  Write(u);
  v := 3; Write(a);
  x := 4; Write(x)
end;

procedure Q;
begin Write(5) end;

begin
  Write(0);
  P(two, a);
  Q;
  b[10] := 6; c := b; Write(c[10]);
  d.g := 7; e := d; Write(e.g);
  Write(- 8); Write(8 + 1);
  Write(11 - 1); Write(22 div 2);
  Write(6 * 2); Write(27 mod 14);
  WriteBool(not false);
  WriteBool(false and true);
  WriteBool(false or true);
  WriteBool(1 < 2); WriteBool(1 = 2);
  WriteBool(1 > 2); WriteBool(1 <= 2);
  WriteBool(1 <> 2); WriteBool(1 >= 2);
  if true then Write(14);
  if false then Write(0) else Write(15);
  a := 16;
  while a <= 17 do
  begin 
    Write(a); a := a+ 1 
  end
end.


