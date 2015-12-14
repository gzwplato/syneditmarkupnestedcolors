unit unit2;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, SynEdit, Forms, Controls,
  Graphics, Dialogs, ExtCtrls, ComCtrls,
  SynEditMarkupWordGroup,
  SynEditHighlighter,
  SynHighlighterPas,
  SynHighlighterLFM,
  SynHighlighterPython,
  SynHighlighterHTML,
  SynHighlighterXML,
  SynHighlighterJScript;

type

  TMarkupWordGroupAccess = class(TSynEditMarkupWordGroup)
  end;

  { TForm1 }


  TForm1 = class(TForm)
    PageControl1: TPageControl;
    Panel1: TPanel;
    SynEditPas: TSynEdit;
    SynEditLFM: TSynEdit;
    SynEditDemoFold: TSynEdit;
    SynEditPython: TSynEdit;
    SynEditXML: TSynEdit;
    SynEditJS: TSynEdit;
    SynEditColorFold: TSynEdit;
    SynFreePascalSyn1: TSynFreePascalSyn;
    SynHTMLSyn1: TSynHTMLSyn;
    SynJScriptSyn1: TSynJScriptSyn;
    SynLFMSyn1: TSynLFMSyn;
    SynPythonSyn1: TSynPythonSyn;
    SynXMLSyn1: TSynXMLSyn;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    TabSheet4: TTabSheet;
    TabSheet5: TTabSheet;
    TabSheet6: TTabSheet;
    TabSheet7: TTabSheet;
    procedure FormCreate(Sender: TObject);
  private
    { private declarations }
    procedure AddMarkupFoldColors;
    procedure FillLfmToSynEdit2;
    procedure LeaveOnly(ASynEdit:TSynEdit);
    procedure SetHighlighter(ASynEdit:TSynEdit; HLClass: TSynCustomHighlighterClass);
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  SynGutterFoldDebug,
  SynEditHighlighterFoldBase,
  SynEditMarkupFoldColoring,
  foldhl, SynHighlighterBracket
  ;

{$R *.lfm}

function ComponentToStringProc(Component: TComponent): string;
var
  BinStream:TMemoryStream;
  StrStream: TStringStream;
  //s: string;
begin
  BinStream := TMemoryStream.Create;
  try
    StrStream := TStringStream.Create('');
    try
      BinStream.WriteComponent(Component);
      BinStream.Seek(0, soFromBeginning);
      ObjectBinaryToText(BinStream, StrStream);
      StrStream.Seek(0, soFromBeginning);
      Result:= StrStream.DataString;
    finally
      StrStream.Free;
    end;
  finally
    BinStream.Free
  end;
end;

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  if self <> Form1 then
    exit; // avoid infinite loop

  LeaveOnly(SynEditDemoFold); //=========== INDIVIDUAL CHECK ===================

  FillLfmToSynEdit2();

  SetHighlighter(SynEditColorFold, TSynHighlighterBracket);

  SetHighlighter(SynEditDemoFold, TSynDemoHlFold);

  AddMarkupFoldColors();
end;

procedure TForm1.AddMarkupFoldColors;
var
  M : TSynEditMarkupFoldColors;
  i : integer;
  S : TSynEdit;
begin
  for i := 0 to Pred(ComponentCount) do
  begin
    if Components[i] is TSynEdit then
    begin
      S := TSynEdit(Components[i]);
      if not (S.Highlighter is TSynCustomFoldHighlighter) then
        continue;

      S.LineHighlightColor.Background:=panel1.Color;
      TSynGutterFoldDebug.Create(S.RightGutter.Parts);

      //continue; //debug
      M := TSynEditMarkupFoldColors.Create(S);
      M.DefaultGroup := 0;
      S.MarkupManager.AddMarkUp(M);
    end;
  end;
end;

procedure TForm1.FillLfmToSynEdit2;
var F : TForm1;
var
  i : integer;
  S : TSynEdit;
begin
  if self <> Form1 then
    exit; // avoid infinite loop
  if SynEditLFM = nil then
    exit;
  F := TForm1.Create(nil);
  for i := 0 to Pred(F.ComponentCount) do
  begin
    if F.Components[i] is TSynEdit then
    begin
      S := TSynEdit(F.Components[i]);
      S.Lines.Text := S.Name;
    end;
  end;
  SynEditLFM.Lines.Text := ComponentToStringProc(F);
  F.Free;
  //SynEditLFM.Highlighter := SynHighlighterLFM2.TSynLFMSyn.Create(self);
end;

procedure TForm1.LeaveOnly(ASynEdit: TSynEdit);
var
  i : integer;
  S : TSynEdit;
begin
  for i := Pred(ComponentCount) downto 0 do
  begin
    if Components[i] is TSynEdit then
    begin
      S := TSynEdit(Components[i]);
      if S <> ASynEdit then
      FreeAndNil(s);
    end;
  end;
  PageControl1.ActivePage := TTabSheet(ASynEdit.Parent);
end;

procedure TForm1.SetHighlighter(ASynEdit: TSynEdit;
  HLClass: TSynCustomHighlighterClass);
begin
  if Assigned(ASynEdit) then
    ASynEdit.Highlighter := HLClass.Create(self);
end;

end.

