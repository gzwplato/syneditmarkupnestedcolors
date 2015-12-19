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

    procedure DoMarkupRangeFoldAtRow(aRow: Integer);
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
  Forms {debug},
  SynEdit,SynEditTypes, SynEditFoldedView, SynEditMiscProcs;

  function CompareFI(Item1, Item2: Pointer): Integer;
  begin
    result := PMarkupFoldColorInfo(Item1)^.X - PMarkupFoldColorInfo(Item2)^.X;
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
        if (aStartCol.Logical >= x) and (aStartCol.Logical < X2) then
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
    if FHighlights[i].X  <= aStartCol.Logical then
      continue;
    if FHighlights[i].X2  < aStartCol.Logical then
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
      {if sfaOpen in ANode.FoldAction then begin
        lvl := ANode.FoldLvlStart;
        //lvl := ANode.NestLvlStart; //http://forum.lazarus.freepascal.org/index.php/topic,30122.msg194841.html#msg194841
        ColorIdx := lvl mod (length(Colors));
      end
      else
        if sfaClose in ANode.FoldAction then begin
          lvl := ANode.FoldLvlEnd;
          ColorIdx := lvl mod (length(Colors));
        end
      else
        ColorIdx := -1;
      }

      {if sfaOpen in ANode.FoldAction then
        lvl := ANode.NestLvlStart
      else
        lvl := ANode.NestLvlEnd;
      ColorIdx := lvl mod (length(Colors));
      }

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
        if not( sfaOutlineKeepColor in TmpNode.FoldAction) then
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
      {if ANode.LineIndex + 1 = aRow then //mean on open/close tag
      begin
        //X  := ANode.LogXStart + 1
        ColorIdx := -1;
        exit;
      end
      else
        X  := ANode.LogVertGuideX + 1;}

      X2 := X+1; //ANode.LogXEnd + 1;

      if not (sfaOutlineHidden in ANode.FoldAction) then
        ColorIdx := lvl mod (length(Colors))
      else
        ColorIdx := -1;

      {if sfaOpen in ANode.FoldAction then begin
        lvl := ANode.FoldLvlStart;
        ColorIdx := lvl mod (length(Colors));
      end
      else
        if sfaClose in ANode.FoldAction then begin
          lvl := ANode.FoldLvlEnd;
          ColorIdx := lvl mod (length(Colors));
        end
      else
      begin
        ColorIdx := -1;
        lvl := ANode.NestLvlStart;
        ColorIdx := lvl mod (length(Colors));
      end;
      }

      {
      if sfaOpen in ANode.FoldAction then
        lvl := ANode.NestLvlStart
      else
        lvl := ANode.NestLvlEnd;

      //ColorIdx := ANode.NodeIndex mod (length(Colors));

      lvl := ANode.NestLvlEnd;
      //lvl := Longint(ANode.FoldTypeCompatible);
      ColorIdx := lvl mod (length(Colors));
      }


    end;
  end;

{$define sfaOutlineforward}
var
  y, lvlB,lvlA: Integer;
  Nest : TLazSynEditNestedFoldsList;
  TmpNode: TSynFoldNodeInfo;
{$ifdef sfaOutlineforward}
  procedure Later(var J:integer);
  begin
    inc(J);
  end;
  function Allowed(J: integer):boolean;
  begin
    result := J < Nest.Count
  end;
{$else}
  procedure Later(var J:integer);
  begin
    dec(J);
  end;
  function Allowed(J: integer):boolean;
  begin
    result := J >= 0
  end;
{$endif}

begin
  y := aRow-1;
  Nest := TLazSynEditNestedFoldsList.Create(@GetFoldHighLighter);
  Nest.ResetFilter;
  Nest.Clear;
  Nest.Line := y;
  Nest.FoldGroup := FDefaultGroup;//1;//FOLDGROUP_PASCAL;
  Nest.FoldFlags :=  [];//[sfbIncludeDisabled]; //
  Nest.IncludeOpeningOnLine := False; //True; //

  try
  lvl := 0;
  {$ifdef sfaOutlineforward}
  i := 0; //while i <  Nest.Count do
  {$else}
  i := Nest.Count -1;  //while i >= 0 do  //from right to left
  {$endif}
  while Allowed(i) do
  begin
      TmpNode := Nest.HLNode[i];

      //find till valid
      while (sfaInvalid in TmpNode.FoldAction ) and Allowed(i) do //(i < Nest.Count) do
      begin
        Later(i);
        TmpNode := Nest.HLNode[i];
      end;
      //if not (sfaInvalid in TmpNode.FoldAction) then}
      if (sfaOutline in TmpNode.FoldAction ) then
      begin
        lvlB := lvl;

        if ( sfaOutlineForceIndent in TmpNode.FoldAction) then
          inc(lvl);
        if ( sfaOutlineMergeParent in TmpNode.FoldAction) then
          dec(lvl);

        AddVerticalLine(TmpNode);
        if not( sfaOutlineKeepColor in TmpNode.FoldAction) then
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
      if FHighlights[j].X = x then
       ;//exit; //

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
      if not (sfaOutlineHidden in ANode.FoldAction) then
         ColorIdx := lvl mod (length(Colors))
      else
         ColorIdx := -1;

      {if sfaOpen in ANode.FoldAction then begin
        lvl := ANode.FoldLvlStart;
        //lvl := ANode.NestLvlStart; //http://forum.lazarus.freepascal.org/index.php/topic,30122.msg194841.html#msg194841
        ColorIdx := lvl mod (length(Colors));
      end
      else
        if sfaClose in ANode.FoldAction then begin
          lvl := ANode.FoldLvlEnd;
          ColorIdx := lvl mod (length(Colors));
        end
      else
        ColorIdx := -1;
      }

      {if sfaOpen in ANode.FoldAction then
        lvl := ANode.NestLvlStart
      else
        lvl := ANode.NestLvlEnd;
      ColorIdx := lvl mod (length(Colors));
      }

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
      while (sfaInvalid in TmpNode.FoldAction) and (i < NodeList.Count) do
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
        if not( sfaOutlineKeepColor in TmpNode.FoldAction) then
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
                //AddHighlight(TmpNode);
                //lvl := lvlB;
                Found := True;
                break;
              end;
          end;
        end;
        if Found then begin
          AddHighlight(TmpNode);
          lvl := lvlB;
        end;

        //if not( sfaOutlineKeepColor in TmpNode.FoldAction) then
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


procedure TSynEditMarkupFoldColors.DoMarkupRangeFoldAtRow(aRow: Integer);
var
  HL: TSynCustomFoldHighlighter;
  p1,p2 : TPoint;
  //Fg : TSynFoldSign;
  C : integer;

  procedure AddHighlight(ABorder : Boolean; AX,AX2, Lev : integer );
  var x,lvl : integer;

  begin
    //exit; //debug
    //lvl := HL.CurrentCodeFoldBlockLevel;
    //lvl := HL.FoldSignLevel(aRow-1);
    //if lvl <= 0 then exit;

    //Fg := HL.CurrentFoldSigns[True];
    //Fg := HL.FoldSignAtLine(aRow-1, True);
    //if Fg.Y < 0 then exit;

    x := Length(FHighlights);
    SetLength(FHighlights, x+1);
    with FHighlights[x] do begin
      Border := ABorder;
      Y  := aRow;//P1.y + 1;
      X  := AX;// Fg.X1st ;
      X2 := AX2+1;//Fg.X2 +3 ;
      ColorIdx := (Lev-1) mod (length(Colors));
      //lvl := ANode.NestLvlEnd;
      //
      //ColorIdx := (lvl-1) mod (length(Colors));

      {if sfaOpen in ANode.FoldAction then begin
        lvl := ANode.FoldLvlStart;
        //lvl := ANode.NestLvlStart; //http://forum.lazarus.freepascal.org/index.php/topic,30122.msg194841.html#msg194841
        ColorIdx := lvl mod (length(Colors));}


    end;
  end;

var
  y,i,lvl,lvl2 : integer;
  NodeList: TLazSynFoldNodeInfoList;
  TmpNode: TSynFoldNodeInfo;
  p : pointer;
  HC : TSynCustomHighlighterRange;
  R : TRect;
  //Prev,Fg : TSynFoldSign;

begin
(*  y := aRow -1;

  HL := TCustomSynEdit(self.SynEdit).Highlighter as TSynCustomFoldHighlighter;
  HL.CurrentLines := Lines;
  //R := HL.CurrentFoldSigns[Y];

  lvl := HL.FoldSignLevel(y);
  if lvl <= 0 then exit;

  //1. check if it 'begin' or 'end',  elsewise draw nested
  Fg := HL.FoldSignAtLine(y, True);
  if Fg.Y < 0 then exit;
  if Fg.Y = y then //open tag
    AddHighlight(False, Fg.X, Fg.X2, lvl)
  else
  begin
    if y > 0 then
    begin
      Prev := HL.FoldSignAtLine(y-1, False); //previous range
      if Prev.Y = y then // current line is the closing tag
      begin
        lvl2 := HL.FoldSignLevel(y-1);
        AddHighlight(False, Prev.X, Prev.X2, lvl2);
      end
      else //not closing nor opening. draw parent
      begin
        AddHighlight(True, Fg.X1st, Fg.X2, lvl)
      end;
    end;
  end;



  begin
    //HC := TSynCustomHighlighterRange(p);
    P1 := R.TopLeft;
    P2 := R.BottomRight;
    C := 0;
     //HC.FoldRoot;
     //AddHighlight();

  end;
*)
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
  {$ifdef debug_FC_line_changed}
  with GetParentForm(self.SynEdit) do
    Caption:= Caret.LineText;
  {$endif}
end;



end.

