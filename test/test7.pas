{ Pascal- Test 7: Type Errors }
program Test7;
  type T = array [1..10] of integer;
  var x: integer; y: Boolean; z: T;

procedure P(x: integer);
begin end;

begin
  y := not 1 and 2 and 3;
  y := false * true div false;
  z := z mod z;
  x := 1 or 2 or 3;
  y := false + true - true;
  z := z - z;
  if z <> z then
    P(true)
end.

