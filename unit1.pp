unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls
  //, LMessages, LCLIntf
  , Windows
  , Spin, JSONPropStorage, Buttons, SynEdit, ZConnection
  , WinSock;

type

  TPingResult = record
    timems: integer
  end;

  TPingData = record
    Description: string;
    SystemStatus: string;
    iMaxSockets: word;
    iMaxUdpDg: word;
    lpVendorInfo: string;
    PingOK: boolean;
    StartTime, EndTime, TimeDifference: TDateTime;

  end;


  TPingResultEvent = procedure(PingData: TPingData) of object;

type

  { TPingThread }

  TPingThread = class(TThread)
  private
    FHost: string;
    FPingData: TPingData;
    FOnPingResult: TPingResultEvent;
    FPort: integer;
    FRetries: integer;
    iCount: integer;
    FDelay: integer;
    procedure PingResult;
  protected
    procedure Execute; override;
  public
    constructor Create(CreateSuspended: boolean; AHost: string; APort, Quant, Delay: integer);
    destructor Destroy; override;
    property OnPingResult: TPingResultEvent read FOnPingResult write FOnPingResult;
  private

  end;

  { TForm1 }

  TForm1 = class(TForm)
    btnPing: TButton;
    cbxLimpar: TCheckBox;
    cbxIgnora: TCheckBox;
    edtCommand: TEdit;
    edtAddress: TComboBox;
    JSONPropStorage1: TJSONPropStorage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Panel1: TPanel;
    panelCLI: TPanel;
    Panel3: TPanel;
    ProgressBar1: TProgressBar;
    Shape1: TShape;
    speDelay: TSpinEdit;
    SpeedButton1: TSpeedButton;
    spePort: TSpinEdit;
    spePacotes: TSpinEdit;
    StatusBar1: TStatusBar;
    edtResult: TSynEdit;
    Timer1: TTimer;
    procedure btnPingClick(Sender: TObject);
    procedure edtCommandKeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    //PingData: TPingData;
    PingThread: TPingThread;
    PingCount: integer;
    Pingando: boolean;
    history: TStringArray;
    procedure AtualizaTexto(sText: string; Clear, InsLineEnd: boolean);
    procedure ShowHelp;
    procedure ShowPingResult(APingData: TPingData);
    procedure startPing(addr: string; port, pkts, delay: integer);
    procedure ThreadFinalizada(Sender: TObject);
    function TraduzComando(sCmd: string): boolean;
  public
  end;

const

  BR = #13#10;
  FOptionChar = '-';
  CaseSensitiveOptions = True;

var
  Form1: TForm1;

  strTimeDifference: string;



implementation

{$R *.lfm}

function PortTCPIsOpen(ipAddressStr: string; dwPort: word): boolean;
var
  client: sockaddr_in;//sockaddr_in is used by Windows Sockets to specify a local or remote endpoint address
  sock: integer;
begin
  client.sin_family := AF_INET;
  client.sin_port := htons(dwPort);//htons converts a u_short from host to TCP/IP network byte order.
  client.sin_addr.s_addr := inet_addr(PChar(ipAddressStr)); //the inet_addr function converts a string containing an IPv4 dotted-decimal address into a proper address for the IN_ADDR structure.
  sock := socket(AF_INET, SOCK_STREAM, 0);//The socket function creates a socket
  Result := connect(sock, client, SizeOf(client)) = 0;//establishes a connection to a specified socket.
end;

constructor TPingThread.Create(CreateSuspended: boolean; AHost: string; APort, Quant, Delay: integer);
begin
  FHost := AHost;
  FPort := APort;
  FRetries := Quant;
  FDelay := Delay;
  FreeOnTerminate := True;
  inherited Create(CreateSuspended);
end;

destructor TPingThread.Destroy;
begin
  //RTLeventDestroy(fRTLEvent);
  inherited Destroy;
end;

procedure TPingThread.PingResult;
begin
  if Assigned(FOnPingResult) then
  begin
    FOnPingResult(FPingData);
  end;
end;

procedure TPingThread.Execute;
var
  i: integer;
  ret: integer;
  wsdata: WSAData;
begin
  FreeOnTerminate := True;
  iCount := 1;
  while (not Terminated) and (iCount < FRetries + 1) do
  begin
    Sleep(FDelay);
    Inc(iCount);
    FPingData.StartTime := Now;
    FPingData.PingOK := False;
    FPingData.Description := '';
    FPingData.SystemStatus := '';
    ret := WSAStartup($0002, wsdata);
    if ret <> 0 then Exit;
    try
      FPingData.Description := wsData.szDescription;
      FPingData.SystemStatus := wsData.szSystemStatus;

      if PortTCPIsOpen(FHost, FPort) then
      begin
        FPingData.PingOK := True;
      end
      else
      begin
        FPingData.PingOK := False;
      end;
      FPingData.EndTime := Now;
      FPingData.TimeDifference := FPingData.EndTime - FPingData.StartTime;
      Synchronize(@PingResult);
    finally
      //Result := PingData;
      WSACleanup; //terminates use of the Winsock
    end;



    //if WmiPing(Computer, Buffer, Timeout) = 0 then Inc(k);

  end;
  //Dec(ActiveThreads);
end;

{ TForm1 }

function FindOptionIndex(const cmd, S: string; var Longopt: boolean; StartAt: integer = -1): integer;
var
  SO, O: string;
  I, P: integer;
  iParamCount: integer;
  Parametros: TStringArray;
begin
  Parametros := cmd.split(' ');
  iParamCount := Length(Parametros);

  if not CaseSensitiveOptions then
    SO := UpperCase(S)
  else
    SO := S;
  Result := -1;
  I := StartAt;
  if (I = -1) then
    I := iParamCount;
  while (Result = -1) and (I > 0) do
  begin
    O := Parametros[i];  /// params[i]
    // - must be seen as an option value
    if (Length(O) > 1) and (O[1] = FOptionChar) then
    begin
      Delete(O, 1, 1);
      LongOpt := (Length(O) > 0) and (O[1] = FOptionChar);
      if LongOpt then
      begin
        Delete(O, 1, 1);
        P := Pos('=', O);
        if (P <> 0) then
          O := Copy(O, 1, P - 1);
      end;
      if not CaseSensitiveOptions then
        O := UpperCase(O);
      if (O = SO) then
        Result := i;
    end;
    Dec(i);
  end;
end;

function HasOption(const cmd: string; const C: char; const S: string): boolean;
var
  B: boolean;
begin
  Result := (FindOptionIndex(cmd, C, B) <> -1) or (FindOptionIndex(cmd, S, B) <> -1);
end;

function GetOptionAtIndex(cmd: string; AIndex: integer; IsLong: boolean): string;

var
  P: integer;
  O: string;

  iParamCount: integer;
  Parametros: TStringArray;
begin
  Parametros := cmd.split(' ');
  iParamCount := Length(Parametros);

  Result := '';
  if (AIndex = -1) then
    Exit;
  if IsLong then
  begin // Long options have form --option=value
    O := Parametros[AIndex];
    P := Pos('=', O);
    if (P = 0) then
      P := Length(O);
    Delete(O, 1, P);
    Result := O;
  end
  else
  begin // short options have form '-o value'
    if (AIndex < iParamCount) then
      if (Copy(Parametros[AIndex + 1], 1, 1) <> FOptionChar) then
        Result := Parametros[AIndex + 1];
  end;
end;

function GetOptionValue(const cmd: string; const C: char; S: string): string;
var
  B: boolean;
  I: integer;
begin
  Result := '';
  I := FindOptionIndex(cmd, c, B);
  if (I = -1) then
    I := FindOptionIndex(cmd, S, B);
  if I <> -1 then
    Result := GetOptionAtIndex(cmd, I, B);
end;

function TForm1.TraduzComando(sCmd: string): boolean; // Parser, REPL, etc
var
  sVar, sAddress, sPort: string;
  iParamCount, iPort: integer;
  Parametros: TStringArray;
begin
  Result := False;
  try
    Parametros := sCmd.split(' ');
    iParamCount := Length(Parametros);
    if iParamCount > 1 then
      sAddress := Parametros[1];

    if sCmd.Contains('help') then
      ShowHelp
    else if sCmd.Contains('cls') then
    else if sCmd.Contains('pingp') then
    begin
      edtAddress.Text := sAddress;
      if (HasOption(sCmd, 'p', 'port')) then
      begin
        iPort := StrToIntDef(GetOptionValue(sCmd, 'p', 'port'), spePort.Value);
        spePort.Value := iPort;
      end
      else
        iPort := spePort.Value;

      startPing(sAddress, iPort, spePacotes.Value, speDelay.Value);
      //AtualizaTexto(sCmd + ' - ' + sVar, False, True);
    end;
    Result := True;

  except
    Result := False;

  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin

  {  if cbxCanPing.Checked then
  begin
    Shape1.Brush.Color := clYellow;
    Application.ProcessMessages;
    Sleep(100);
    Shape1.Brush.Color := clYellow;
    Application.ProcessMessages;
    //StartTime := Now;
    sRet := edtAddress.Text;
    //RetPing := TestPort(edtAddress.Text, spePort.Value);
    sRet += ' ' + RetPing.Description;
    sRet += ' ' + RetPing.SystemStatus;
    if RetPing.PingOK then
    begin
      Shape1.Brush.Color := clYellow;
      sRet += ' Pingou';
    end
    else
    begin
      Shape1.Brush.Color := clRed;
      sRet += ' Falhou';
    end;
    //TimeDifference := EndTime - StartTime;
    //strTimeDifference := FormatDateTime('n" min, "s" sec, "z" ms"', TimeDifference);
    Memo1.Lines.Add('----------------');

    Memo1.Lines.Add(sRet);

    Memo1.Lines.Add(strTimeDifference);
    Application.ProcessMessages;
    Shape1.Brush.Color := clGreen;
    Sleep(400);
    Application.ProcessMessages;

  end;
}
end;

procedure TForm1.ShowPingResult(APingData: TPingData);
var
  sResult: string;
begin
  if cbxIgnora.Checked then
    PingThread.Terminate;

  Inc(PingCount);
  ProgressBar1.Position := PingCount;
  Application.ProcessMessages;
  strTimeDifference := FormatDateTime('n" min, "s" sec, "z" ms"', APingData.TimeDifference);
  sResult := '[' + PingCount.ToString + ']';
  if APingData.PingOK then
  begin
    Shape1.Brush.Color := clSilver;
    sResult += 'SUCESSO ✓';
  end
  else
  begin
    sResult += 'FALHOU ✕';

  end;
  AtualizaTexto(sResult + ' - ' + strTimeDifference, False, False);
end;

procedure TForm1.AtualizaTexto(sText: string; Clear, InsLineEnd: boolean);
begin
  if Clear then edtResult.Lines.Clear;
  edtResult.Lines.Add(sText);
  if InsLineEnd then edtResult.Lines.Add('');
  SendMessage(edtResult.handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TForm1.ThreadFinalizada(Sender: TObject);
begin
  btnPing.Caption := 'Pingar';
  Pingando := False;
  AtualizaTexto('ThreadTerminatedo: ' + FormatDateTime('hh:mm:ss', now), False, True);
end;

procedure TForm1.btnPingClick(Sender: TObject);
begin
  startPing(edtAddress.Text, spePort.Value, spePacotes.Value, speDelay.Value);
end;

procedure TForm1.startPing(addr: string; port, pkts, delay: integer);

  function startThread: boolean;
  begin
    ProgressBar1.Max := spePacotes.Value;
    PingCount := 0;
    ProgressBar1.Position := PingCount;
    btnPing.Caption := 'Parar';
    Shape1.Brush.Color := clSilver;
    AtualizaTexto(FormatDateTime('hh:mm:ss', now), cbxLimpar.Checked, True);
    AtualizaTexto('Pingando para: ' + addr, cbxLimpar.Checked, True);
    PingThread := TPingThread.Create(True, edtAddress.Text, port, pkts, delay);
    PingThread.OnPingResult := @ShowPingResult;
    PingThread.Priority := tpNormal;
    PingThread.FreeOnTerminate := True;
    PingThread.OnTerminate := @ThreadFinalizada;
    Pingando := True;
    PingThread.Start;
  end;

begin

  if Pingando then
  begin
    if assigned(PingThread) then
      PingThread.Terminate;
  end
  else
  begin
    startThread;
  end;
end;

procedure TForm1.edtCommandKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    if TraduzComando(edtCommand.Text) then
      edtCommand.Clear;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  //history := TStringArray;
  JSONPropStorage1.JSONFileName := ChangeFileExt(Application.ExeName, '.json');
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  //if Assigned(PingThread) then PingThread.Terminate;
  //PingThread.Terminate;
  //PingThread.Free;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  edtCommand.SetFocus;
end;

procedure TForm1.ShowHelp;
var
  I: integer;
  sInfo, sText: string;
  sChar: char;
begin
  sInfo := 'BEM VINDO'#13;
  sInfo += BR;
  sInfo += 'Inspirado no paping'#13;
  sInfo += BR;
  sInfo += 'Desenvolvido por Arlon'#13;
  sInfo += BR;
  sInfo += 'IDE: Lazarus (https://www.lazarus-ide.org/)'#13;
  sInfo += BR;

  edtResult.Lines.Clear;
  sText := '';
  for I := 1 to 30 do
    sText += ''#13;

  for I := 1 to sInfo.Length - 1 do
  begin
    sText += sInfo[I];
    edtResult.Lines.Text := sText;
    //edtResult.SelStart := edtResult.GetTextLen;
    SendMessage(edtResult.handle, WM_VSCROLL, SB_BOTTOM, 0);
    Application.ProcessMessages;
    sleep(10);
  end;
  edtResult.Lines.Add('');
  edtResult.Lines.Add('');

end;


end.
