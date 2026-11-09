#define MyAppName "RemoveSensitiveShortcuts"
#define MyAppVersion "1.0"

[Setup]
AppId={{8F66C52D-7795-4AE8-ACB1-4ED84D918EB0}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\RemoveSensitiveShortcuts
PrivilegesRequired=admin
OutputBaseFilename=RemoveSensitiveShortcuts-Setup
UninstallDisplayName={#MyAppName}

[Files]
Source: "Clean-SensitiveRecent.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "InstallTask.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\InstallTask.ps1"""; \
  Flags: waituntilterminated; \
  StatusMsg: "Setting up the scheduled task..."

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Unregister-ScheduledTask -TaskPath '\Custom\' -TaskName 'Clean Sensitive Recent Shortcuts' -Confirm:$false -ErrorAction SilentlyContinue"""; \
  Flags: runhidden waituntilterminated; \
  RunOnceId: "RemoveSensitiveRecentTask"

[UninstallDelete]
Type: files; Name: "{app}\ExcludedPaths.txt"

[Code]
var
  ExcludedPage: TWizardPage;
  ExcludedMemo: TNewMemo;

procedure InitializeWizard;
begin
  ExcludedPage := CreateCustomPage(
    wpSelectDir,
    'Folders to exclude',
    'Enter one full folder path per line.'
  );

  ExcludedMemo := TNewMemo.Create(ExcludedPage);
  ExcludedMemo.Parent := ExcludedPage.Surface;
  ExcludedMemo.Left := 0;
  ExcludedMemo.Top := 0;
  ExcludedMemo.Width := ExcludedPage.SurfaceWidth;
  ExcludedMemo.Height := ScaleY(180);
  ExcludedMemo.ScrollBars := ssVertical;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  I: Integer;
  PathLine: String;
  FoundPath: Boolean;
begin
  Result := True;

  if CurPageID = ExcludedPage.ID then
  begin
    FoundPath := False;

    for I := 0 to ExcludedMemo.Lines.Count - 1 do
    begin
      PathLine := Trim(ExcludedMemo.Lines[I]);

      if PathLine <> '' then
      begin
        FoundPath := True;

        if not DirExists(PathLine) then
        begin
          MsgBox(
            'This folder does not exist:' + #13#10 + PathLine,
            mbError, MB_OK
          );
          Result := False;
          Exit;
        end;
      end;
    end;

    if not FoundPath then
    begin
      MsgBox(
        'Enter at least one folder path, with one path per line.',
        mbError, MB_OK
      );
      Result := False;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  I: Integer;
  Contents: String;
  PathLine: String;
  ExcludedFile: String;
begin
  if CurStep = ssInstall then
  begin
    ExcludedFile := ExpandConstant('{app}\ExcludedPaths.txt');

    if not ForceDirectories(ExtractFileDir(ExcludedFile)) then
      RaiseException('Could not create the application folder.');

    Contents := '';

    for I := 0 to ExcludedMemo.Lines.Count - 1 do
    begin
      PathLine := Trim(ExcludedMemo.Lines[I]);

      if PathLine <> '' then
      begin
        if Contents <> '' then
          Contents := Contents + #13#10;

        Contents := Contents + PathLine;
      end;
    end;

    if not SaveStringToFile(ExcludedFile, Contents + #13#10, False) then
      RaiseException('Could not write ExcludedPaths.txt.');
  end;
end;
