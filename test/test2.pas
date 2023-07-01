{ Pascal- Test 2: Syntax Analysis }
program Test2;

const
  a = 1;
  b = a;
type
  T = array [1..2] of integer;

  U = record
    f, g: integer;
    h: boolean
  end;

  V = record
    f: integer
  end;
var
  x, y: T;
  z: U;

  procedure P(var x: integer; y: boolean);
  const
    a = 1;
  type
    T = array [1..2] of integer;

    procedure Q(x: integer);
    type
      T = array [1..2] of integer;
    begin
      x := -1;
      x := x;
      x := (2 - 1) * (2 + 1) div 2 mod 2;
      if x < x then
        while x = x do
          Q(x);
      if x > x then
        while x <= x do
          P(x, False)
      else
      if not (x <> x) then; {Empty}
    end;

  begin
    if x >= x then
      y := True;
  end;

  procedure R;
  var
    x: T;
  begin
    x[1] := 5;
  end;

  { Main program }
begin
  z.f := 6;
end.
