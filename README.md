# Windows Yetki Yukseltme Aracı

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?style=flat-square&logo=powershell)](https://docs.microsoft.com/powershell/)
[![Windows](https://img.shields.io/badge/Windows-7+-brightgreen?style=flat-square&logo=windows)](https://www.microsoft.com/windows/)
[![License](https://img.shields.io/badge/License-MIT-orange?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/Version-11.8-red?style=flat-square)]()
[![Author](https://img.shields.io/badge/Author-Vedat%20Tascier-purple?style=flat-square)](https://github.com/vedattascier)
[![GitHub](https://img.shields.io/badge/GitHub-vedattascier-blue?style=flat-square&logo=github)](https://github.com/vedattascier)

> Windows işletim sistemleri icin kapsamlı yetki yukseltme tespit ve güvenlik denetim araci. WinPEAS benzeri özelliklerle sistem güvenlik açıklarını tespit eder.

## Özellikler

### Yetki Yükseltme Tespiti
- Yazılabilir servisler ve executable'lar
- Tırnaksız (unquoted) service path'ler
- Autorun registry anahtarları
- Token yetkileri (SeImpersonatePrivilege, SeDebugPrivilege, vb.)
- AlwaysInstallElevated kontrolü
- PATH hijacking tespiti
- DLL hijacking analizi

### Kimlik Bilgisi Tespiti
- Registry saklı şifreleri
- SAM veritabanı analizi
- Önbelleklenmiş giriş bilgileri
- WDigest durumu
- LSA sırları
- Tarayici şifreleri (Chrome, Edge, Firefox)

### Ağ Güvenliği
- SMBv1 kontrolü (EternalBlue riski)
- LLMNR durumu
- SMB imzalama
- RDP NLA kontrolü
- WinRM güvenlik ayarları

### Sistem Güvenliği
- Windows Defender durumu
- BitLocker şifreleme
- UAC yapılandırması
- LSA koruması (PPL)
- Credential Guard
- Secure Boot durumu
- Firewall profilleri

### Raporlama
- **HTML** - Modern, interaktif rapor
- **JSON** - Programatik erişim
- **CIS Benchmark** uyumluluk kontrolü
- Detaylı risk analizi ve çözüm önerileri

## Kurulum

```powershell
# PowerShell script çalıştırma yetkisi
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Kullanım

```powershell
# Temel kullanım
.\windows-yetki-yukseltme.ps1

# Detaylı tarama
.\windows-yetki-yukseltme.ps1 -Detaylı

# HTML rapor oluştur
.\windows-yetki-yukseltme.ps1 -HTML

# JSON çıktı
.\windows-yetki-yukseltme.ps1 -JSON

# CIS Benchmark kontrolü
.\windows-yetki-yukseltme.ps1 -CIS

# Birlikte kullanım
.\windows-yetki-yukseltme.ps1 -Detaylı -HTML -CIS
.\windows-yetki-yukseltme.ps1 -JSON -CiktiDosya "rapor.json"
```

## Parametreler

| Parametre | Açıklama |
|-----------|----------|
| `-Detayli` | Detaylı tarama modu (70+ kontrol) |
| `-JSON` | JSON formatında çıktı |
| `-HTML` | Modern HTML rapor oluştur |
| `-Tam` | Tam sistem taraması |
| `-Hizli` | Hızlı tarama (temel kontroller) |
| `-CIS` | CIS Benchmark uyumluluk kontrolü |
| `-NoColor` | Renksiz çıktı |
| `-CiktiDosya` | Sonucu dosyaya kaydet |

## Sistem Gereksinimleri

- **İşletim Sistemi**: Windows 7 / Windows Server 2008 veya üstü
- **PowerShell**: 3.0 veya üstü
- **Yetki**: Yönetici (tüm kontroller için)

## Yasal Sorumluluk

> **ÖNEMLİ**: Bu araç yalnızca yetkili güvenlik testleri ve sistem envanteri için kullanılmalıdır.

❌ **Yasaklar:**
- İzinsiz sistemlere giriş
- Başkalarının sisteminde yetki yükseltme
- Veri hırsızlığı veya tahribat
- Kişisel veri toplaması

✅ **Sorumluluk:**
Kullanıcı bu aracın kullanımından tamamen sorumludur. Yazar sistem hasarlarından veya yasal sorunlardan mesul tutulamaz.

## Yazar

**Vedat Taşçıer** 

- 🌐 Web: [www.vedattascier.com](https://www.vedattascier.com)
- 💻 GitHub: [github.com/vedattascier](https://github.com/vedattascier)
- 📧 İletişim: vedattascier@gmail.com

## Lisans

**MIT License** - Tamamen Açık Kaynak

Bu proje açık kaynaklıdır ve topluluk tarafından geliştirilmek üzere paylaşılmıştır. Herkes bu projeyi kullanabilir, değiştirebilir ve geliştirebilir.

---

<div align="center">

**Güvenlik her zaman öncelik olmalıdır!**

</div>

Bu proje acik kaynaklidir ve topluluk tarafindan gelistirilmek uzere paylasilmistir. Herkes bu projeyi kullanabilir, degistirebilir ve gelistirebilir.
