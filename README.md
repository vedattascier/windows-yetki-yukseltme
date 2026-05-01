# 🛡️ Windows Yetki Yukseltme Araci

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+--blue?style=flat-square&logo=powershell)](https://docs.microsoft.com/powershell/)
[![Windows](https://img.shields.io/badge/Windows-7+-brightgreen?style=flat-square&logo=windows)](https://www.microsoft.com/windows/)
[![License](https://img.shields.io/badge/License-MIT-orange?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/Version-11.8-red?style=flat-square)]()
[![Author](https://img.shields.io/badge/Author-Vedat%20Ta%C5%9F%C3%A7%C4%B1er-purple?style=flat-square)](https://github.com/vedattascier)

> Windows isletim sistemleri icin kapsamli yetki yukseltme tespit ve guvenlik denetim araci. WinPEAS benzeri ozelliklerle sistem guvenlik açiklarini tespit eder.

## 🚀 Ozellikler

### 🔍 Yetki Yukseltme Tespiti
- Yazilabilir servisler ve executable'lar
- Tirnaksiz (unquoted) service path'ler
- Autorun registry anahtarlari
- Token yetkileri (SeImpersonatePrivilege, SeDebugPrivilege, vb.)
- AlwaysInstallElevated kontrolu
- PATH hijacking tespiti
- DLL hijacking analizi

### 🔐 Kimlik Bilgisi Tespiti
- Registry sakli sifreleri
- SAM veritabani analizi
- Onbelleklenmis giris bilgileri
- WDigest durumu
- LSA sirlari
- Tarayici sifreleri (Chrome, Edge, Firefox)

### 🌐 Ag Guvenligi
- SMBv1 kontrolu (EternalBlue riski)
- LLMNR durumu
- SMB imzalama
- RDP NLA kontrolu
- WinRM guvenlik ayarlari

### 🖥️ Sistem Guvenligi
- Windows Defender durumu
- BitLocker sifreleme
- UAC yapilandirmasi
- LSA korumasi (PPL)
- Credential Guard
- Secure Boot durumu
- Firewall profilleri

### 📊 Raporlama
- **HTML** - Modern, interaktif rapor
- **JSON** - Programatik erisim
- **CIS Benchmark** uyumluluk kontrolu
- Detayli risk analizi ve cozum onerileri

## 📦 Kurulum

```powershell
# PowerShell script calistirma yetkisi
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## ▶️ Kullanim

```powershell
# Temel kullanim
.\windows-yetki-yukseltme.ps1

# Detayli tarama
.\windows-yetki-yukseltme.ps1 -Detayli

# HTML rapor olustur
.\windows-yetki-yukseltme.ps1 -HTML

# JSON cikti
.\windows-yetki-yukseltme.ps1 -JSON

# CIS Benchmark kontrolu
.\windows-yetki-yukseltme.ps1 -CIS

# Birlikte kullanim
.\windows-yetki-yukseltme.ps1 -Detayli -HTML -CIS
.\windows-yetki-yukseltme.ps1 -JSON -CiktiDosya "rapor.json"
```

## 📋 Parametreler

| Parametre | Aciklama |
|-----------|----------|
| `-Detayli` | Detayli tarama modu (70+ kontrol) |
| `-JSON` | JSON formatinda cikti |
| `-HTML` | Modern HTML rapor olustur |
| `-Tam` | Tam sistem taramasi |
| `-Hizli` | Hizli tarama (temel kontroller) |
| `-CIS` | CIS Benchmark uyumluluk |
| `-NoColor` | Renksiz cikti |
| `-CiktiDosya` | Sonucu dosyaya kaydet |

## 🖥️ Sistem Gereksinimleri

- **Isletim Sistemi**: Windows 7 / Server 2008 veya ustü
- **PowerShell**: 3.0 veya ustü
- **Yetki**: Yonetici (tüm kontroller icin)

## ⚠️ Yasal Sorumluluk

> **ONEMLI**: Bu arac yalnizca yetkili guvenlik testleri ve sistem envanteri icin kullanilmalidir.

❌ **Yasaklar:**
- Izinsiz sistemlere giris
- Baskasinin sisteminde yetki yukseltme
- Veri hirsizligi veya tahribat
- Kisisel veri toplanmasi

✅ **Sorumluluk:**
Kullanici bu aracin kullanimindan tamamen sorumludur. Yazar sistem hasarlarindan veya yasal sorunlardan mesul tutulamaz.

## 👨‍💻 Yazar

**Vedat Tascier**

- 🌐 Web: [www.vedattascier.com](https://www.vedattascier.com)
- 💻 GitHub: [github.com/vedattascier](https://github.com/vedattascier)

## 📄 Lisans

**MIT License** - Tamamen Acik Kaynak

Bu proje acik kaynaklidir ve topluluk tarafindan gelistirilmek uzere paylasilmistir. Herkes bu projeyi kullanabilir, degistirebilir ve gelistirebilir.

---

<div align="center">

**Guvenlik her zaman oncelik olmalidir!**

</div>

Bu proje acik kaynaklidir ve topluluk tarafindan gelistirilmek uzere paylasilmistir. Herkes bu projeyi kullanabilir, degistirebilir ve gelistirebilir.
