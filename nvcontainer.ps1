# Wymagane zestawy .NET do tworzenia interfejsu graficznego
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Konfiguracja ---
$serviceName = "NvContainerLocalSystem" # Nazwa usługi NVIDIA do zarządzania
$defaultLanguage = 'en' # Domyślny język interfejsu

# --- Tłumaczenia Interfejsu ---
# Słownik przechowujący teksty interfejsu w różnych językach
$uiStrings = @{
    en = @{
        WindowTitle           = "NVIDIA Service Manager"
        StatusLabelPrefix     = "Service status:"
        StatusRunning         = "Running"
        StatusStopped         = "Stopped"
        StatusNotFound        = "Service not found"
        ButtonStart           = "Enable"
        ButtonStop            = "Disable"
        ButtonExit            = "Exit"
        TabService            = "Service"
        TabOptions            = "Options"
        LabelLanguage         = "Language:"
        AdminWarning          = "Warning: Application not running as administrator! Service control disabled." # Nowy tekst
    }
    pl = @{
        WindowTitle           = "Menedżer Usług NVIDIA"
        StatusLabelPrefix     = "Stan usługi:"
        StatusRunning         = "Włączona"
        StatusStopped         = "Wyłączona"
        StatusNotFound        = "Nie znaleziono usługi"
        ButtonStart           = "Włącz"
        ButtonStop            = "Wyłącz"
        ButtonExit            = "Wyjdź"
        TabService            = "Usługa"
        TabOptions            = "Opcje"
        LabelLanguage         = "Język:"
        AdminWarning          = "Uwaga: Program nie został uruchomiony jako administrator! Kontrola usługi wyłączona." # Nowy tekst
    }
    ru = @{
        WindowTitle           = "Диспетчер служб NVIDIA"
        StatusLabelPrefix     = "Статус службы:"
        StatusRunning         = "Включена"
        StatusStopped         = "Отключена"
        StatusNotFound        = "Служба не найдена"
        ButtonStart           = "Включить"
        ButtonStop            = "Отключить"
        ButtonExit            = "Выход"
        TabService            = "Служба"
        TabOptions            = "Настройки"
        LabelLanguage         = "Язык:"
        AdminWarning          = "Внимание: Программа не запущена от имени администратора! Управление службой отключено." # Nowy tekst
    }
    de = @{
        WindowTitle           = "NVIDIA Dienstmanager"
        StatusLabelPrefix     = "Dienststatus:"
        StatusRunning         = "Läuft"
        StatusStopped         = "Gestoppt"
        StatusNotFound        = "Dienst nicht gefunden"
        ButtonStart           = "Aktivieren"
        ButtonStop            = "Deaktivieren"
        ButtonExit            = "Beenden"
        TabService            = "Dienst"
        TabOptions            = "Optionen"
        LabelLanguage         = "Sprache:"
        AdminWarning          = "Warnung: Programm nicht als Administrator ausgeführt! Dienststeuerung deaktiviert." # Nowy tekst
    }
    zh = @{
        WindowTitle           = "NVIDIA 服务管理器"
        StatusLabelPrefix     = "服务状态:"
        StatusRunning         = "运行中"
        StatusStopped         = "已停止"
        StatusNotFound        = "未找到服务"
        ButtonStart           = "启用"
        ButtonStop            = "禁用"
        ButtonExit            = "退出"
        TabService            = "服务"
        TabOptions            = "选项"
        LabelLanguage         = "语言:"
        AdminWarning          = "警告：应用程序未以管理员身份运行！服务控制已禁用。" # Nowy tekst
    }
}
$currentLanguage = $defaultLanguage # Ustawienie bieżącego języka

# Mapa kodów języków na ich pełne nazwy (do wyświetlania w ComboBox)
$languageMap = @{
    en = 'English'
    pl = 'Polski'
    ru = 'Русский'
    de = 'Deutsch'
    zh = '中文'
}

# --- Sprawdzenie Uprawnień Administratora ---
function Test-IsAdmin {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        Write-Error "Błąd podczas sprawdzania uprawnień administratora: $_"
        return $false # Zakładamy brak uprawnień w razie błędu
    }
}
$isAdmin = Test-IsAdmin # Zapisz wynik sprawdzenia do zmiennej

# --- Funkcje Pomocnicze ---

# Tworzy prostą bitmapę danego koloru
function New-ColorBitmap {
    param(
        [System.Drawing.Color]$Color,
        [int]$Width = 16,
        [int]$Height = 16
    )
    $bmp = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.Clear($Color)
    $graphics.Dispose()
    return $bmp
}

# Globalne zmienne dla obrazków statusu
$imgStatusRunning = New-ColorBitmap -Color Green
$imgStatusStopped = New-ColorBitmap -Color Red
$imgStatusUnknown = New-ColorBitmap -Color Gray # Dodano szary dla stanu "nie znaleziono"

# Pobiera aktualny status usługi (zwraca obiekt)
function Get-ServiceStatusObject {
    if (-not $isAdmin) {
        # Jeśli nie jest adminem, nie próbuj nawet sprawdzać usługi
        return @{ Name = "Unknown"; Text = $uiStrings[$currentLanguage].StatusNotFound }
    }
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        if ($service.Status -eq "Running") {
            return @{ Name = "Running"; Text = $uiStrings[$currentLanguage].StatusRunning }
        } else {
            return @{ Name = "Stopped"; Text = $uiStrings[$currentLanguage].StatusStopped }
        }
    } catch {
        return @{ Name = "NotFound"; Text = $uiStrings[$currentLanguage].StatusNotFound }
    }
}

# Aktualizuje etykietę statusu usługi i obrazek
function Update-StatusControls {
    $statusInfo = Get-ServiceStatusObject
    $labelStatus.Text = "$($uiStrings[$currentLanguage].StatusLabelPrefix) $($statusInfo.Text)"

    # Ustaw odpowiedni obrazek w PictureBox
    switch ($statusInfo.Name) {
        "Running"  { $pictureBoxStatus.Image = $imgStatusRunning }
        "Stopped"  { $pictureBoxStatus.Image = $imgStatusStopped }
        default    { $pictureBoxStatus.Image = $imgStatusUnknown } # Dla NotFound i Unknown
    }
}

# Uruchamia usługę i ustawia jej tryb startu na automatyczny (tylko dla admina)
function Start-ServiceAction {
    if (-not $isAdmin) { return } # Nie rób nic, jeśli nie admin
    try {
        sc.exe config $serviceName start= auto | Out-Null
        Start-Service -Name $serviceName -ErrorAction Stop
        Update-StatusControls
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Nie udało się uruchomić usługi '$serviceName'.`nBłąd: $($_.Exception.Message)", "Błąd", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Update-StatusControls
    }
}

# Zatrzymuje usługę i ustawia jej tryb startu na wyłączony (tylko dla admina)
function Stop-ServiceAction {
    if (-not $isAdmin) { return } # Nie rób nic, jeśli nie admin
    try {
        sc.exe config $serviceName start= disabled | Out-Null
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
        Update-StatusControls
    } catch {
        if ($_.Exception.Message -notlike "*service is not running*") {
             [System.Windows.Forms.MessageBox]::Show("Nie udało się zatrzymać usługi '$serviceName'.`nBłąd: $($_.Exception.Message)", "Błąd", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        Update-StatusControls
    }
}

# Aktualizuje teksty wszystkich kontrolek interfejsu na podstawie wybranego języka
function Update-UIText {
    param(
        [string]$langCode # Kod języka (np. 'en', 'pl')
    )
    $global:currentLanguage = $langCode # Użycie $global: jest ważne
    $form.Text = $uiStrings[$langCode].WindowTitle
    Update-StatusControls # Aktualizacja etykiety statusu i obrazka
    $buttonStart.Text = $uiStrings[$langCode].ButtonStart
    $buttonStop.Text = $uiStrings[$langCode].ButtonStop
    $buttonExit.Text = $uiStrings[$langCode].ButtonExit
    $tabPageService.Text = $uiStrings[$langCode].TabService
    $tabPageOptions.Text = $uiStrings[$langCode].TabOptions
    $labelLanguage.Text = $uiStrings[$langCode].LabelLanguage
    # Aktualizacja tekstu ostrzeżenia o braku uprawnień admina
    $labelAdminWarning.Text = $uiStrings[$langCode].AdminWarning
}

# --- Tworzenie Głównego Okna (Formularza) ---
$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(340, 280) # Zwiększony rozmiar dla ostrzeżenia
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false

# --- Etykieta Ostrzeżenia o Braku Uprawnień Admina ---
$labelAdminWarning = New-Object System.Windows.Forms.Label
$labelAdminWarning.Location = New-Object System.Drawing.Point(10, 10)
$labelAdminWarning.Size = New-Object System.Drawing.Size(305, 20) # Szeroka etykieta na górze
$labelAdminWarning.ForeColor = [System.Drawing.Color]::Red
$labelAdminWarning.TextAlign = 'MiddleCenter'
$labelAdminWarning.Visible = (-not $isAdmin) # Widoczna tylko jeśli nie jest adminem
$form.Controls.Add($labelAdminWarning)

# --- Tworzenie Kontrolki Zakładek (TabControl) ---
$tabControl = New-Object System.Windows.Forms.TabControl
# Przesunięcie w dół, jeśli ostrzeżenie jest widoczne
$tabControlY = if ($isAdmin) { 10 } else { 35 }
$tabControl.Location = New-Object System.Drawing.Point(10, $tabControlY)
$tabControl.Size = New-Object System.Drawing.Size(305, 165) # Dopasowanie rozmiaru
$form.Controls.Add($tabControl)

# --- Zakładka 1: Zarządzanie Usługą ---
$tabPageService = New-Object System.Windows.Forms.TabPage
$tabControl.Controls.Add($tabPageService)

# PictureBox dla statusu
$pictureBoxStatus = New-Object System.Windows.Forms.PictureBox
$pictureBoxStatus.Location = New-Object System.Drawing.Point(20, 27)
$pictureBoxStatus.Size = New-Object System.Drawing.Size(16, 16)
$tabPageService.Controls.Add($pictureBoxStatus)

# Etykieta statusu
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Location = New-Object System.Drawing.Point(45, 20) # Przesunięta w prawo
$labelStatus.Size = New-Object System.Drawing.Size(240, 30)
$labelStatus.TextAlign = 'MiddleLeft'
$tabPageService.Controls.Add($labelStatus)

# Przycisk Włącz
$buttonStart = New-Object System.Windows.Forms.Button
$buttonStart.Location = New-Object System.Drawing.Point(60, 70) # Dostosowanie położenia
$buttonStart.Size = New-Object System.Drawing.Size(80, 30)
$buttonStart.Add_Click({ Start-ServiceAction })
$buttonStart.Enabled = $isAdmin # Wyłączony, jeśli nie admin
$tabPageService.Controls.Add($buttonStart)

# Przycisk Wyłącz
$buttonStop = New-Object System.Windows.Forms.Button
$buttonStop.Location = New-Object System.Drawing.Point(150, 70) # Dostosowanie położenia
$buttonStop.Size = New-Object System.Drawing.Size(80, 30)
$buttonStop.Add_Click({ Stop-ServiceAction })
$buttonStop.Enabled = $isAdmin # Wyłączony, jeśli nie admin
$tabPageService.Controls.Add($buttonStop)

# --- Zakładka 2: Opcje ---
$tabPageOptions = New-Object System.Windows.Forms.TabPage
$tabControl.Controls.Add($tabPageOptions)

# Etykieta "Język"
$labelLanguage = New-Object System.Windows.Forms.Label
$labelLanguage.Location = New-Object System.Drawing.Point(20, 30)
$labelLanguage.Size = New-Object System.Drawing.Size(80, 25)
$labelLanguage.TextAlign = 'MiddleRight'
$tabPageOptions.Controls.Add($labelLanguage)

# Lista rozwijana (ComboBox) do wyboru języka
$comboBoxLanguage = New-Object System.Windows.Forms.ComboBox
$comboBoxLanguage.Location = New-Object System.Drawing.Point(110, 30)
$comboBoxLanguage.Size = New-Object System.Drawing.Size(170, 25) # Dopasowanie szerokości
$comboBoxLanguage.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

# Dodanie języków do ComboBox
$languageMap.Keys | ForEach-Object {
    [void]$comboBoxLanguage.Items.Add($languageMap[$_])
}
$comboBoxLanguage.SelectedItem = $languageMap[$defaultLanguage]

# Akcja wykonywana po zmianie wybranego języka
$comboBoxLanguage.Add_SelectedIndexChanged({
    $selectedLangName = $comboBoxLanguage.SelectedItem
    $selectedLangCode = $languageMap.Keys | Where-Object { $languageMap[$_] -eq $selectedLangName }
    if ($selectedLangCode) {
        Update-UIText -langCode $selectedLangCode
    }
})
$tabPageOptions.Controls.Add($comboBoxLanguage)

# --- Przycisk Wyjdź (poza zakładkami) ---
$buttonExit = New-Object System.Windows.Forms.Button
$buttonExitY = $tabControl.Location.Y + $tabControl.Height + 10 # Położenie pod zakładkami
$buttonExit.Location = New-Object System.Drawing.Point(125, $buttonExitY)
$buttonExit.Size = New-Object System.Drawing.Size(80, 30)
$buttonExit.Add_Click({ $form.Close() })
$form.Controls.Add($buttonExit)

# --- Obsługa zamknięcia formularza ---
$form.Add_FormClosing({
    # Zwolnij zasoby GDI (obrazki)
    if ($imgStatusRunning) { $imgStatusRunning.Dispose() }
    if ($imgStatusStopped) { $imgStatusStopped.Dispose() }
    if ($imgStatusUnknown) { $imgStatusUnknown.Dispose() }
})

# --- Inicjalizacja i Wyświetlenie Okna ---

# Ustawienie początkowych tekstów interfejsu w domyślnym języku
Update-UIText -langCode $defaultLanguage

# Ustawienie okna jako zawsze na wierzchu
$form.Topmost = $true
# Aktywacja okna po jego pokazaniu
$form.Add_Shown({$form.Activate()})
# Wyświetlenie okna
[void]$form.ShowDialog()

