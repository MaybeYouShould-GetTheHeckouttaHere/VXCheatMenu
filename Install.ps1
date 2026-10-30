param([string]$GameDirectory = $PSScriptRoot, [switch]$Uninstall)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $GameDirectory).Path
$ini = Join-Path $root 'Game.ini'
$backup = Join-Path $root 'Game.ini.vxcheat-backup'
$cheatDirectory = Join-Path $root 'cheat'
$archive = Join-Path $root 'Game.rgss3a'
$archiveJournal = Join-Path $cheatDirectory 'archive-backup.bin'
function Load-ArchiveHelper {
    if (-not ('VXCheatArchive' -as [type])) {
        Add-Type -Path (Join-Path $cheatDirectory 'ArchivePatch.cs')
    }
}
if ($Uninstall) {
    if (!(Test-Path -LiteralPath $backup)) { throw 'No VXCheat backup found.' }
    if (Test-Path -LiteralPath $archiveJournal) {
        Load-ArchiveHelper
        [VXCheatArchive]::Restore($archive, $cheatDirectory)
    }
    Copy-Item -LiteralPath $backup -Destination $ini -Force
    Write-Host 'Original Game.ini restored. Cheat files can now be removed.'
    exit
}
$iniEncoding = [Text.Encoding]::GetEncoding(28591)
$originalBytes = [IO.File]::ReadAllBytes($ini)
$text = $iniEncoding.GetString($originalBytes)
# Migrate the earlier loose-bootstrap installation using its original INI.
if ($text -match '(?im)^Scripts\s*=\s*cheat[\\/]bootstrap\.rvdata2\s*$' -and (Test-Path -LiteralPath $backup)) {
    $originalBytes = [IO.File]::ReadAllBytes($backup)
    $text = $iniEncoding.GetString($originalBytes)
}
if ($text -notmatch '(?im)^Library\s*=.*RGSS30\d\.dll\s*$') {
    throw 'This package supports VX Ace / RGSS3 only.'
}
$match = [regex]::Match($text, '(?im)^Scripts\s*=\s*([^\r\n]+)')
if (!$match.Success) { throw 'Game.ini has no Scripts entry.' }
$original = $match.Groups[1].Value.Trim()
$required = @('bootstrap.rvdata2','ArchivePatch.cs','core.rb','ui.rb','input.rb','display.rb','input.dll','storage.rb','translate.rb',
              'panels/actors.rb','panels/general.rb','panels/inventory.rb','panels/world.rb')
foreach ($file in $required) {
    if (!(Test-Path -LiteralPath (Join-Path $root ('cheat/' + $file)))) {
        throw "Missing cheat/$file. Copy the complete cheat folder into the game root before installing."
    }
}
if ($original.Replace('\','/') -eq 'cheat/bootstrap.rvdata2') {
    Write-Host 'Already installed. Ruby modules can be replaced to update.'
    exit
}
if (Test-Path -LiteralPath $backup) {
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($backup)) -ne [Convert]::ToBase64String($originalBytes)) {
        throw 'An existing backup needs review before installing again.'
    }
}
if (!(Test-Path -LiteralPath (Join-Path $root 'cheat/bootstrap.rvdata2'))) {
    throw 'Copy the cheat folder into the game root before installing.'
}
if (!(Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $ini -Destination $backup }
$rubyPath = $original.Replace('\','/').Replace("'", "\'")
$config = "VXCHEAT_ORIGINAL_SCRIPTS = '" + $rubyPath + "'`n"
$updated = [regex]::Replace($text, '(?im)^Scripts\s*=\s*[^\r\n]+', 'Scripts=cheat\bootstrap.rvdata2')
try {
    if (Test-Path -LiteralPath $archive) {
        Load-ArchiveHelper
        [VXCheatArchive]::Install($archive, $original, (Join-Path $cheatDirectory 'bootstrap.rvdata2'), $cheatDirectory)
        $config += "VXCHEAT_ORIGINAL_BYTES_FILE = './cheat/original_scripts.rvdata2'`n"
        $updated = $text
    }
    [IO.File]::WriteAllText((Join-Path $root 'cheat/original_path.rb'), $config, (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllBytes($ini, $iniEncoding.GetBytes($updated))
} catch {
    if (Test-Path -LiteralPath $archiveJournal) {
        Load-ArchiveHelper
        [VXCheatArchive]::Restore($archive, $cheatDirectory)
    }
    Copy-Item -LiteralPath $backup -Destination $ini -Force
    throw
}
Write-Host 'Installed. Launch Game.exe and press Ctrl+C on a map or in battle.'
