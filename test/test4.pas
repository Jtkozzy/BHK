{ Pascal- Test 4: Scope Analysis }
program Test4;

type
  S = record
    f, g: boolean
  end;
var
  v: S;


  procedure P(x: integer);
  const
    n = 10;
  type
    T = array [1..n] of integer;
  var
    y, z: T;

    procedure Q;
    begin
      Read(x);
      v.g := False;
    end;

  begin
    y := z;
    Q;
    P(5);
    Write(x);
  end;

begin
  v.f := True;
  P(5);
end.
