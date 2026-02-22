<# ============================================================
   FANFARE  --  Victory sound on task completion
   ============================================================
   Part of The Armory (github.com/VontaJamal/armory)
   
   Usage:
     fanfare                    # Default victory chime
     fanfare --sound path.wav   # Custom sound file
     fanfare --bell             # Terminal bell only (SSH-friendly)
     fanfare --beep             # System beep (no sound card needed)
     fanfare --melody victory   # Built-in melody (victory|alert|error|levelup)
     fanfare --message "Done!"  # Show toast notification too
     fanfare --pipe             # Pipe mode: reads stdin, plays on EOF
   
   Examples:
     long-running-task; fanfare
     long-running-task; fanfare --melody levelup --message "Build complete!"
     cat log.txt | fanfare --pipe --bell
     codex "fix the tests"; fanfare --melody victory
   ============================================================ #>

param(
    [string]$sound,
    [switch]$bell,
    [switch]$beep,
    [string]$melody = "",
    [string]$message = "",
    [switch]$pipe,
    [switch]$silent,
    [switch]$help,
    [switch]$civ
)

$ErrorActionPreference = "Stop"

# --- Help ---
if ($help) {
    Write-Host ""
    Write-Host "  FANFARE - Victory sound on task completion" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor White
    Write-Host "    fanfare                      Default victory chime"
    Write-Host "    fanfare --sound file.wav      Custom .wav file"
    Write-Host "    fanfare --bell               Terminal bell (SSH-friendly)"
    Write-Host "    fanfare --beep               System beep (no sound card needed)"
    Write-Host "    fanfare --melody <name>      Built-in melody: victory, alert, error, levelup"
    Write-Host "    fanfare --message 'Done!'    Also show a Windows toast notification"
    Write-Host "    fanfare --pipe               Pipe mode: pass stdin through, play on EOF"
    Write-Host ""
    Write-Host "  Chain it:" -ForegroundColor Yellow
    Write-Host "    long-task; fanfare"
    Write-Host "    long-task; fanfare --melody levelup --message 'Build done!'"
    Write-Host ""
    exit 0
}

# --- Pipe mode: consume stdin then play ---
if ($pipe) {
    $input | ForEach-Object { Write-Output $_ }
}

# --- Melodies (frequency, duration pairs) ---
$melodies = @{
    victory = @(
        @(523, 120), @(659, 120), @(784, 120), @(1047, 300)  # C-E-G-C (up octave)
    )
    alert = @(
        @(880, 200), @(0, 100), @(880, 200)  # A beep-beep
    )
    error = @(
        @(440, 300), @(330, 300), @(220, 500)  # Descending A-E-A
    )
    levelup = @(
        @(523, 100), @(587, 100), @(659, 100), @(784, 100),
        @(880, 100), @(1047, 100), @(1175, 100), @(1319, 300)  # C scale run up
    )
}

function Play-Melody($name) {
    $seq = $melodies[$name]
    if (-not $seq) {
        Write-Host "Unknown melody: $name. Options: victory, alert, error, levelup" -ForegroundColor Red
        exit 1
    }
    foreach ($note in $seq) {
        if ($note[0] -eq 0) {
            Start-Sleep -Milliseconds $note[1]
        } else {
            [console]::beep($note[0], $note[1])
        }
    }
}

function Show-Toast($text) {
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
            [Windows.UI.Notifications.ToastTemplateType]::ToastText01
        )
        $template.GetElementsByTagName("text")[0].AppendChild($template.CreateTextNode($text)) | Out-Null
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Fanfare")
        $notifier.Show([Windows.UI.Notifications.ToastNotification]::new($template))
    } catch {
        # Toast not available (older Windows, SSH session, etc.) -- fail silently
    }
}

# --- Main logic ---
if ($silent) {
    # Silent mode - just the toast if requested
} elseif ($bell) {
    [System.Console]::Write([char]7)
} elseif ($beep) {
    [console]::beep(800, 300)
} elseif ($sound) {
    if (-not (Test-Path $sound)) {
        Write-Host "Sound file not found: $sound" -ForegroundColor Red
        exit 1
    }
    $player = New-Object System.Media.SoundPlayer $sound
    $player.PlaySync()
    $player.Dispose()
} elseif ($melody) {
    Play-Melody $melody
} else {
    # Default: victory melody
    Play-Melody "victory"
}

# --- Optional toast notification ---
if ($message) {
    Show-Toast $message
}

if (-not $silent -and -not $bell -and -not $beep -and -not $sound -and -not $melody) {
    # Already played default above
}
