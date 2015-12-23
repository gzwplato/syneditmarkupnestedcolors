unit SynEditMarkupFoldColoring;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,Graphics, SynEditMarkup, SynEditMiscClasses, Controls,
  LCLProc, SynEditHighlighter, SynEditHighlighterFoldBase;

type

  PMarkupFoldColorInfo = ^TMarkupFoldColorInfo;
  TMarkupFoldColorInfo = record
    Y, X, X2: Integer;
    ColorIdx: Integer;
    Border  : Boolean;
    Ignore  : Boolean; //no color no line
    SrcNode : TSynFoldNodeInfo;
    LevelBefore, LevelAfter : integer;//needed by non nest nodes
  end;

  TMarkupFoldColorInfos = array of TMarkupFoldColorInfo;
  TSynFoldNodeInfos     = array of TSynFoldNodeInfo; //for quick compare detection

  { TSynEditMarkupFoldColors }

  TSynEditMarkupFoldColors = class(TSynEditMarkup)
  private
    FDefaultGroup: integer;
     // Physical Position
    FHighlights : TMarkupFoldColorInfos; //array of TMarkupFoldColorInfo;
    Colors : array of TColor;
    CurrentY : integer;  //??
    FCaretY : integer;    // flag identify for refresh begin______
    FPrevCaretText : string;  // flag identify for refresh begin______

    procedure DoMarkupFoldAtRow(aRow: Integer);
    procedure DoMarkupParentFoldAtRow(aRow: Integer);
    procedure DoMarkupParentCloseFoldAtRow(aRow: Integer);

    function GetFoldHighLighter: TSynCustomFoldHighlighter;
  protected
    // Notifications about Changes to the text
    procedure DoTextChanged({%H-}StartLine, EndLine, {%H-}ACountDiff: Integer); override; // 1 based
    procedure DoCaretChanged(Sender: TObject); override;
  public
    constructor Create(ASynEdit : TSynEditBase);
    function GetMarkupAttributeAtRowCol(const aRow: Integer;
                                        const aStartCol: TLazSynDisplayTokenBound;
                                        const {%H-}AnRtlInfo: TLazSynDisplayRtlInfo): TSynSelectedColor; override;
    procedure GetNextMarkupColAfterRowCol(const aRow: Integer;
                                         const aStartCol: TLazSynDisplayTokenBound;
                                         const {%H-}AnRtlInfo: TLazSynDisplayRtlInfo;
                                         out   ANextPhys, ANextLog: Integer); override;

    procedure PrepareMarkupForRow(aRow : Integer); override;
    property DefaultGroup : integer read FDefaultGroup write FDefaultGroup;
  end;

implementation
uses
  SynEdit,SynEditTypes, SynEditFoldedView, SynEditMiscProcs;

  function CompareFI(Item1, Item2: Pointer): Integer;
  begin
    result := PMarkupFoldColorInfo(Item1)^.X - PMarkupFoldColorInfo(Item2)^.X;
    if result = 0 then
        result := PMarkupFoldColorInfo(Item1)^.X2 - PMarkupFoldColorInfo(Item2)^.X2;

  end;

  function SortLeftMostFI(a: TMarkupFoldColorInfos): TMarkupFoldColorInfos;
  var
    l : TFpList;
    i : integer;
  begin
    l := TFpList.Create;
    for i := 0 to Pred(Length(a)) do
      l.Add( PMarkupFoldColorInfo(@a[i]) );
    l.Sort(@CompareFI);

    SetLength(result, Length(a));
    for i := 0 to Pred(l.Count) do
      result[i] := PMarkupFoldColorInfo(l[i])^;
     l.Free;
  end;

{ TSynEditMarkupFoldColors }

constructor TSynEditMarkupFoldColors.Create(ASynEdit: TSynEditBase);
begin
  inherited Create(ASynEdit);
  MarkupInfo.Foreground := clGreen;
  MarkupInfo.Background := clNone; //clFuchsia;
  MarkupInfo.Style := [];
  MarkupInfo.StyleMask := [];
  MarkupInfo.FrameEdges:= sfeLeft;//sfeAround;//sfeBottom;//

  SetLength(Colors, 6);
  Colors[0] := clRed;
  Colors[1] := $000098F7; //orange
  Colors[2] := $0022CC40; //green
  Colors[3] := $00D5D500;//$0098CC42; //$00D1D54A; // teal
  Colors[4] := $00FF682A; //blue
  Colors[5] := $00CF00C4; //purple
end;

function TSynEditMarkupFoldColors.GetMarkupAttributeAtRowCol(
  const aRow: Integer; const aStartCol: TLazSynDisplayTokenBound;
  const AnRtlInfo: TLazSynDisplayRtlInfo): TSynSelectedColor;
var
  i : integer;
begin
  Result := nil;
  if (CurrentY = aRow) then
    for i := 0 to length(FHighlights)-1 do
      with FHighlights[i] do
        if not Ignore and (X <> X2) and (aStartCol.Logical >= x) and (aStartCol.Logical < X2) then
        begin
          if ColorIdx >= 0 then
          begin
            MarkupInfo.FrameColor:= clNone;
            MarkupInfo.Foreground:= clNone;
            MarkupInfo.Background:= clNone;
            MarkupInfo.FrameEdges:= sfeNone;
            //MarkupInfo.FrameColor:= clGreen; //debug

            Result := MarkupInfo;
            MarkupInfo.SetFrameBoundsLog(x, x2);
            if Border then
            begin
              MarkupInfo.FrameColor:= Colors[ColorIdx];
              MarkupInfo.FrameEdges:= sfeLeft;//sfeAround;//
            end
            else
              MarkupInfo.Foreground := Colors[ColorIdx];

            //MarkupInfo.FrameEdges:= sfeAround; //debug

            //2nd debug
            if x > x2 then
            begin
              MarkupInfo.Background:= clYellow;
              MarkupInfo.SetFrameBoundsLog(x-1, x2+20);
              MarkupInfo.FrameColor:= clBlue; //debug
            end;

          end;

          break;
        end
end;

procedure TSynEditMarkupFoldColors.GetNextMarkupColAfterRowCol(
  const aRow: Integer; const aStartCol: TLazSynDisplayTokenBound;
  const AnRtlInfo: TLazSynDisplayRtlInfo; out ANextPhys, ANextLog: Integer);
var i : integer;
begin
  ANextLog := -1;
  ANextPhys := -1;
  if (CurrentY = aRow) then
  for i := 0 to length(FHighlights)-1 do begin
    if FHighlights[i].X  = FHighlights[i].X2 then
      continue;
    if FHighlights[i].X  <= aStartCol.Logical then
      continue;
    if FHighlights[i].X2  < aStartCol.Logical then
      continue;
    if FHighlights[i].Ignore then
      continue;
    ANextLog := FHighlights[i].X;
    break;
  end;
end;

procedure TSynEditMarkupFoldColors.DoMarkupFoldAtRow(aRow: Integer);
var
  lvl : integer;

  procedure AddHighlight( ANode: TSynFoldNodeInfo );
  var x : integer;
  begin
    //exit; //debug
    x := Length(FHighlights);
    SetLength(FHighlights, x+1);
    with FHighlights[x] do begin
      Border := False;
      Y  := ANode.LineIndex + 1;
      X  := ANode.LogXStart + 1;
      X2 := ANode.LogXEnd + 1;
      ColorIdx := lvl;
    end;
  end;

var
  y,i : integer;
  HL: TSynCustomFoldHighlighter;
  NodeList: TLazSynFoldNodeInfoList;
  TmpNode: TSynFoldNodeInfo;

begin
  y := aRow -1;

  HL := TCustomSynEdit(self.SynEdit).Highlighter as TSynCustomFoldHighlighter;
  HL.CurrentLines := Lines;
  HL.FoldNodeInfo[y].ClearFilter; // only needed once, in case the line was already used

  NodeList := HL.FoldNodeInfo[y];
  NodeList.AddReference;
  try
    NodeList.ActionFilter := [
        {sfaMarkup,}
//        sfaFold
      sfaOutline
      ,sfaClose
        //sfaFoldFold
        //sfaFoldHide
        //sfaSingleLine
        //sfaMultiLine
        //sfaOpen
        ];
    //NodeList.FoldFlags:= [sfbIncludeDisabled];
    lvl := 0;
    i := 0;
    repeat
      TmpNode := NodeList[i];

      //find till valid
      while (sfaInvalid in TmpNode.FoldAction) and (i < NodeList.Count) do
      begin
        inc(i);
        TmpNode := NodeList[i];
      end;
      if not (sfaInvalid in TmpNode.FoldAction) then
      begin
        AddHighlight(TmpNode);
        if not( sfaOutlineKeepLevel in TmpNode.FoldAction) then
          inc(lvl);
      end;


      inc(i);
    until i >= NodeList.Count;

  finally
    NodeList.ReleaseReference;
  end;
end;

procedure TSynEditMarkupFoldColors.DoMarkupParentFoldAtRow(aRow: Integer);
var
  i,lvl,z : integer; //iterate parents fold

  procedure AddVerticalLine( ANode: TSynFoldNodeInfo );
  var x,j : integer;
  begin

    //don't replace; don't add when already found
    x  := ANode.LogXStart + 1;
    for j := 0 to Pred(length(FHighlights)) do
      if FHighlights[j].X = x then
       ;//exit; //

    z := Length(FHighlights);
    SetLength(FHighlights, z+1);
    with FHighlights[z] do begin
      SrcNode:= ANode; //needed by close node
      Border := ANode.LineIndex + 1 <> aRow;
      X  := ANode.LogXStart + 1;
      Y  := aRow;//ANode.LineIndex + 1;
      X2 := X+1; //ANode.LogXEnd + 1;
      Ignore := False;

      if Border and (sfaOutlineNoLine in ANode.FoldAction) then
        Ignore := True;
      if not Border and (sfaOutlineNoColor in ANode.FoldAction) then
        Ignore := True;
      //else
        ColorIdx := lvl mod (length(Colors))
    end;
  end;

var
  y, lvlB,lvlA: Integer;
  Nest : TLazSynEditNestedFoldsList;
  TmpNode: TSynFoldNodeInfo;
  NestCount : integer;
  procedure Later(var J:integer);
  begin
    inc(J);
  end;
  function Allowed(J: integer):boolean;
  begin
    result := J < NestCount;
  end;

begin
  y := aRow-1;
  Nest := TLazSynEditNestedFoldsList.Create(@GetFoldHighLighter);
  Nest.ResetFilter;
  Nest.Clear;
  Nest.Line := y;
  Nest.FoldGroup := FDefaultGroup;//1;//FOLDGROUP_PASCAL;
  Nest.FoldFlags :=  [];//[sfbIncludeDisabled]; //
  Nest.IncludeOpeningOnLine := True; //False; //
  NestCount := Nest.Count;

  try
    lvl := 0;
    i := 0;
    while Allowed(i) do
    begin

      TmpNode := Nest.HLNode[i];
      //find till valid
      while (sfaInvalid in TmpNode.FoldAction ) and Allowed(i+1) do //(i < Nest.Count) do
      begin
        Later(i);
        TmpNode := Nest.HLNode[i];
      end;
      //if not (sfaInvalid in TmpNode.FoldAction) then}

      if (sfaOutline in TmpNode.FoldAction ) then
      //avoid bug of IncludeOpeningOnLine := False;
      if (sfaOpen in TmpNode.FoldAction)  and (TmpNode.LineIndex + 1 = aRow) then
      begin {do nothing here} end
      else
      begin
        lvlB := lvl;

        if ( sfaOutlineForceIndent in TmpNode.FoldAction) then
          inc(lvl);
        if ( sfaOutlineMergeParent in TmpNode.FoldAction) then
          dec(lvl);

        AddVerticalLine(TmpNode);
        if not( sfaOutlineKeepLevel in TmpNode.FoldAction) then
          inc(lvl);

        lvlA := lvl;

        with FHighlights[z] do begin
          LevelBefore := lvlB;
          LevelAfter  := lvlA;
        end;
      end;

      Later(i);
      //dec(i);
      //break; //debug
    end;

  finally
    Nest.Free;
  end;
end;

procedure TSynEditMarkupFoldColors.DoMarkupParentCloseFoldAtRow(aRow: Integer);
var
  lvl,z : integer;

  procedure AddHighlight( ANode: TSynFoldNodeInfo );
  var x,j : integer;
  begin
        //don't replace; don't add when already found
    x  := ANode.LogXStart + 1;
    for j := 0 to Pred(length(FHighlights)) do
      if (FHighlights[j].X = x) and (FHighlights[j].Border) then begin
       FHighlights[j].X2 := ANode.LogXEnd+1 ;//exit; //
       FHighlights[j].Border := False

      end;

    //exit; //debug
    z := Length(FHighlights);
    SetLength(FHighlights, z+1);
    with FHighlights[z] do begin
      Border := False;
      SrcNode:= ANode; //needed by close node
      Y  := ANode.LineIndex + 1;
      X  := ANode.LogXStart + 1;
      X2 := ANode.LogXEnd + 1;
      //ColorIdx := lvl;
      if not (sfaOutlineNocolor in ANode.FoldAction) then
         ColorIdx := lvl mod (length(Colors))
      else
         ColorIdx := -1;
    end;
  end;

var
  y,i,j,lvlB,lvlA : integer;
  HL: TSynCustomFoldHighlighter;
  NodeList: TLazSynFoldNodeInfoList;
  TmpNode: TSynFoldNodeInfo;
  Found : boolean;
begin
  y := aRow -1;

  HL := TCustomSynEdit(self.SynEdit).Highlighter as TSynCustomFoldHighlighter;
  HL.CurrentLines := Lines;
  HL.FoldNodeInfo[y].ClearFilter; // only needed once, in case the line was already used

  NodeList := HL.FoldNodeInfo[y];
  NodeList.AddReference;
  try
    NodeList.ActionFilter := [
        {sfaMarkup,}
//        sfaFold
      sfaOutline
//      ,sfaClose
        //sfaFoldFold
        //sfaFoldHide
        //sfaSingleLine
        //sfaMultiLine
        //sfaOpen
        ];
    //NodeList.FoldFlags:= [sfbIncludeDisabled];
    lvl := 0;
    J := Length(FHighlights)-1;
    if J >=0 then
      lvl := max(0,FHighlights[J].LevelAfter);
    i := 0;
    repeat
      TmpNode := NodeList[i];

      //find till valid
      while (sfaInvalid in TmpNode.FoldAction) and (i + 1 < NodeList.Count) do
      begin
        inc(i);
        TmpNode := NodeList[i];
      end;
      if not (sfaInvalid in TmpNode.FoldAction) and (sfaOutline in TmpNode.FoldAction) then begin
        if sfaOpen in TmpNode.FoldAction then
        begin
          lvlB := lvl;

          if ( sfaOutlineForceIndent in TmpNode.FoldAction) then
            inc(lvl);
          if ( sfaOutlineMergeParent in TmpNode.FoldAction) then
            dec(lvl);



          AddHighlight(TmpNode);
          if not( sfaOutlineKeepLevel in TmpNode.FoldAction) then
            inc(lvl);
          lvlA := lvl;

          with FHighlights[z] do begin
            LevelBefore := lvlB;
            LevelAfter  := lvlA;
          end;


        end
        else
        if sfaClose in TmpNode.FoldAction then
        begin
          Found := False;
          for j := Length(FHighlights)-1 downto 0 do begin
            with FHighlights[j].SrcNode do begin
              if  (FoldType = TmpNode.FoldType) and
                (FoldGroup = TmpNode.FoldGroup) and
                (sfaOpen in FoldAction) and
                // (FoldLvlEnd = TmpNode.FoldLvlStart)
                (NestLvlEnd = TmpNode.NestLvlStart)

                then begin
                  lvl := FHighlights[j].ColorIdx;
                  lvlB := FHighlights[j].LevelBefore;
                  Found := True;
                  break;
                end;
            end;
          end;
          if Found then begin
            AddHighlight(TmpNode);
            lvl := lvlB;
          end;

          //if not( sfaOutlineKeepLevel in TmpNode.FoldAction) then
            //inc(lvl);
        end;

      end;


      inc(i);
    until i >= NodeList.Count;

  finally
    NodeList.ReleaseReference;
  end;
end;

procedure TSynEditMarkupFoldColors.PrepareMarkupForRow(aRow: Integer);
begin
  CurrentY := aRow;
  SetLength(FHighlights,0); //reset needed to prevent using of invalid area

  if not (TCustomSynEdit(self.SynEdit).Highlighter is TSynCustomFoldHighlighter) then
    exit;

  //DoMarkupFoldAtRow(aRow);
  DoMarkupParentFoldAtRow(aRow);
  DoMarkupParentCloseFoldAtRow(aRow);
  //DoMarkupRangeFoldAtRow(aRow);

  FHighlights := SortLeftMostFI(FHighlights);
end;

function TSynEditMarkupFoldColors.GetFoldHighLighter: TSynCustomFoldHighlighter;
begin
  result := TCustomSynEdit(self.SynEdit).Highlighter as TSynCustomFoldHighlighter;
end;

{.$define debug_FC_line_changed}
procedure TSynEditMarkupFoldColors.DoTextChanged(StartLine, EndLine,
  ACountDiff: Integer);
{$ifdef debug_FC_line_changed}
var F : TCustomForm;
begin
  F := GetParentForm(self.SynEdit);
  if F <> nil then
    //F.Caption := Format('Start:%d Endline:%d  Diff:%d',[StartLine, EndLIne, ACountDiff]);
  F.Caption := F.Caption +  Caret.LineText
{$else}



  function GetPairCloseFold(aRow, X : integer  ): Integer;
  var
    y,i,LCnt : integer;
    HL: TSynCustomFoldHighlighter;
    NodeList: TLazSynFoldNodeInfoList;
    TmpNode, CloseNode: TSynFoldNodeInfo;

    function FindEndNode(StartNode: TSynFoldNodeInfo;
                       {var} YIndex, NIndex: Integer): TSynFoldNodeInfo;
      function SearchLine(ALineIdx: Integer; var ANodeIdx: Integer): TSynFoldNodeInfo;
      begin
        NodeList.Line := ALineIdx;
        repeat
          inc(ANodeIdx);
          Result := NodeList[ANodeIdx];
        until (sfaInvalid in Result.FoldAction)
           or (Result.NestLvlEnd <= StartNode.NestLvlStart);
      end;

    begin
      Result := SearchLine(YIndex, NIndex);
      if not (sfaInvalid in Result.FoldAction) then
        exit;

      inc(YIndex);
      while (YIndex < LCnt) and
            (HL.FoldBlockMinLevel(YIndex, StartNode.FoldGroup, [sfbIncludeDisabled])
             > StartNode.NestLvlStart)
      do
        inc(YIndex);
      if YIndex = LCnt then
        exit;

      NIndex := -1;
      Result := SearchLine(YIndex, NIndex);

      if (Result.LogXEnd = 0) or (sfaLastLineClose in Result.FoldAction) then
        Result.FoldAction := [sfaInvalid]; // LastLine closed Node(maybe force-closed?)
    end;

  begin
    Result := -1;
    y := aRow -1;

    HL := TCustomSynEdit(self.SynEdit).Highlighter as TSynCustomFoldHighlighter;
    HL.CurrentLines := Lines;
    LCnt := Lines.Count;
    HL.FoldNodeInfo[y].ClearFilter; // only needed once, in case the line was already used

    NodeList := HL.FoldNodeInfo[y];
    NodeList.AddReference;
    try
      NodeList.ActionFilter := [sfaOpen];
      i := 0;
      repeat
        TmpNode := NodeList[i];

        if TmpNode.LogXStart < X-1 then
        begin
          inc(i);
          continue;
        end;

        //find till valid
        while (sfaInvalid in TmpNode.FoldAction) and (i < NodeList.Count) do
        begin
          inc(i);
          TmpNode := NodeList[i];
        end;
        if not (sfaInvalid in TmpNode.FoldAction) then
        begin
          CloseNode := FindEndNode(TmpNode, y, i);
          //AddHighlight(TmpNode);
          Result := CloseNode.LineIndex;
          exit;
        end;

        inc(i);
      until i >= NodeList.Count;

    finally
      NodeList.ReleaseReference;
    end;
  end;


  function IsFoldMoved( aRow: Integer ): integer;
  var S : string;
    i,n : integer;
  begin
    Result := -1;
    n := -1;

    S := Caret.LineText;
    for i := 1 to Min(Length(S), Length(FPrevCaretText)) do
    begin
      if S[i] <> FPrevCaretText[i] then
      begin
        n := i;
        break;
      end;
    end;

    if n < 0 then exit;

    Result := GetPairCloseFold(aRow, n);
    //limit to screen bottom
    if Result > 0 then
    begin
      inc(Result);//because sometime 'end' has trailing vertical line
      with TCustomSynEdit(SynEdit) do
        Result := min(Result, TopLine +LinesInWindow);// . .RowToScreenRow(i);
    end;

  end;
var
  EndFoldLine,y : integer;
begin
  if EndLine < 0 then exit; //already refreshed by syn

  y := Caret.LineBytePos.y;
  EndFoldLine := IsFoldMoved(y);
  if EndFoldLine > 0 then
  begin
    InvalidateSynLines(y+1, EndFoldLine);
  end;

  FPrevCaretText := Caret.LineText;
  // I found that almost anything has been repaint by the SynEdit,
  // except the trailing space editing: we should repaint them here.
{$endif}
end;

procedure TSynEditMarkupFoldColors.DoCaretChanged(Sender: TObject);
var Y : integer;
begin
  Y := Caret.LineBytePos.y;
  if Y = FCaretY then exit;

  FCaretY := Y;
  FPrevCaretText := Caret.LineText;
end;



end.

