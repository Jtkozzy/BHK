{ Pascal- Test 5: Scope Errors }
program Test5;
const
  {a} = 1;
  b = b;
type
  T = array [1..10] of T;
  U = record f, g: U end;
var
  x, y, x : integer;
begin
  x := a;
  y := a
end.

