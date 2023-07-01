{ Pascal- Test 10: Program Example }
program Test10;
const max = 10;
type T = array [1..max] of integer;
var A: T; k: integer;

procedure Quicksort(m, n: integer);
var i,j: integer;
  procedure Partition;
  var r, w: integer;
  begin
    r := A[(m + n) div 2];
    i := m; j := n;
    while i <= j do
    begin
      while A[i] < r do i := i + 1;
      while r < A[j] do j := j - 1;
      if i <= j then
      begin
        w := A[i]; A[i] := A[j];
        A[j] := w; i := i + 1;
        j := j - 1; 
      end
    end
  end;

  begin
    if m < n then
    begin
      Partition;
      Quicksort(m, j);
      Quicksort(i, n)
    end
  end;

begin
  k := 1;
  while k <= max do
  begin Read(A[k]); k := k + 1 end;
  Quicksort(1, max);
  k := 1;
  while k <= max do
  begin 
    Write(A[k]); 
    k := k + 1 
  end
end.
