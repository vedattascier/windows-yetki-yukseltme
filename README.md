# Windows Yetki Yukseltme Araci

Windows isletim sistemleri icin kapsamli yetki yukseltme tespit ve guvenlik denetim araci.

## Ozellikler

- **Sistem Bilgileri**: Isletim sistemi, surum, mimari bilgileri
- **Guvenlik Durumu**: Firewall, antivirus, sifreleme kontrolleri
- **Yetki Yukseltme Tespiti**:
  - Yazilabilir servisler
  - Tirnaksiz service path'ler
  - Autorun anahtarlari
  - Zayif servis izinleri
  - Token yetkileri (SeImpersonatePrivilege, SeDebugPrivilege)
- **Kimlik Bilgisi Tespiti**:
  - Registry sifreleri
  - SAM veritabani
  - Onbelleklenmis giris bilgileri
  - WDigest durumu
- **Ag Guvenligi**:
  - SMBv1 kontrolu
  - LLMNR durumu
  - SMB imzalama
- **Olay Analizi**:
  - Basarisiz giris denemeleri
  - Event log analizi
- **Cozum Onerileri**: Tespit edilen riskler icin detayli onarim adimlari

## Kullanim

### PowerShell Ayarlari

Oncelikle PowerShell'de script calistirma yetkisi verin:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Temel Kullanim

```powershell
# Scripti calistirin
.\windows-yetki-yukseltme.ps1
```

### Detayli Kullanim

```powershell
# Tam tarama ile detayli sonuclar
.\windows-yetki-yukseltme.ps1 -Detayli

# CIS Benchmark uyumluluk kontrolu
.\windows-yetki-yukseltme.ps1 -CIS

# HTML formatinda rapor olustur
.\windows-yetki-yukseltme.ps1 -HTML

# JSON formatinda cikti al
.\windows-yetki-yukseltme.ps1 -JSON

# Hizli tarama (daha az kontrol)
.\windows-yetki-yukseltme.ps1 -Hizli

# Tam sistem taramasi
.\windows-yetki-yukseltme.ps1 -Tam

# Rengi kapat
.\windows-yetki-yukseltme.ps1 -NoColor

# Sonuclari dosyaya kaydet
.\windows-yetki-yukseltme.ps1 -CiktiDosya "rapor.txt"

# Birlikte kullanım örnekleri
.\windows-yetki-yukseltme.ps1 -Detayli -HTML
.\windows-yetki-yukseltme.ps1 -JSON -CiktiDosya "sonuc.json"
.\windows-yetki-yukseltme.ps1 -Tam -CIS
```

### Yonetici Yetkisi

Bazi kontroller icin yonetici yetkisi gereklidir. PowerShell'i "Yonetici olarak calistir" ile baslatin.

## Parametreler

| Parametre | Aciklama |
|-----------|----------|
| `-Detayli` | Detayli tarama modu |
| `-JSON` | JSON formatinda cikti |
| `-HTML` | HTML rapor olustur |
| `-Tam` | Tam sistem taramasi |
| `-Hizli` | Hizli tarama modu |
| `-CiktiDosya` | Cikti dosyasi belirt |
| `-NoColor` | Renkli ciktiyi kapat |
| `-CIS` | CIS benchmark kontrolu |

## Sistem Gereksinimleri

- Windows 7 / Server 2008 veya ustü
- PowerShell 3.0 veya ustü
- Yonetici yetkileri (tüm kontroller icin)

## Yazar

**Vedat Tascier**

- GitHub: https://github.com/vedattascier
- Web: www.vedattascier.com

## Yasal Sorumluluk

Bu arac yalnizca yetkili guvenlik testleri ve sistem envanteri icin kullanilmalidir.

**Yasaklar:**
- Izinsiz sistemlere giris
- Baskasinin sisteminde yetki yukseltme
- Veri hirsizligi veya tahribat
- Kisisel veri toplanmasi

**Sorumluluk:**
Kullanici bu aracin kullanimindan tamamen sorumludur. Yazar sistem hasarlarindan veya yasal sorunlardan mesul tutulamaz.

## GitHub'a Yukleme

### 1. GitHub Repository Olusturma

1. GitHub'da yeni repository olusturun: https://github.com/new
2. Repository adi: `windows-yetki-yukseltme`
3. Acik kaynak olarak secin
4. Repository olusturun

### 2. Yerel Bilgisayardan Yukleme

```bash
# Klasore gidin
cd C:\Users\vedat\CascadeProjects\WindowsAudit-TR

# Git baslat
git init

# Dosyalari ekle
git add .

# Commit yap
git commit -m "Windows Yetki Yukseltme Araci v11.8"

# Main branch olustur
git branch -M main

# Remote ekle
git remote add origin https://github.com/vedattascier/windows-yetki-yukseltme.git

# Yukle
git push -u origin main
```

### 3. Git Kurulumu (Yoksa)

```powershell
# Winget ile
winget install Git.Git

# Veya choco ile
choco install git
```

## Lisans

MIT License - Tamamen Acik Kaynak

Bu proje acik kaynaklidir ve topluluk tarafindan gelistirilmek uzere paylasilmistir. Herkes bu projeyi kullanabilir, degistirebilir ve gelistirebilir.
