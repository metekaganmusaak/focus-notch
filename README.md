<div align="center">

<img src="macos/FocusNotch/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256@1x.png" width="128" alt="Focus Notch simgesi">

# Focus Notch

**Çentikte yaşayan, sevimli bir odak dostuyla birlikte çalışan Pomodoro zamanlayıcısı.**

macOS'ta MacBook çentiğinin etrafına, Windows'ta görev çubuğunun içine yerleşir.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows)
![23 dil](https://img.shields.io/badge/diller-23-ff735c)

<img src="docs/images/macos-expanded.png" width="720" alt="macOS'ta açık çentik paneli: pet, sayaç, kontroller ve konu çipleri">

</div>

## İçindekiler

- [Özellikler](#özellikler)
- [Ekran görüntüleri](#ekran-görüntüleri)
- [Odak dostları](#odak-dostları)
- [İndirme ve kurulum](#i̇ndirme-ve-kurulum)
- [Kullanım](#kullanım)
- [macOS ve Windows farkları](#macos-ve-windows-farkları)
- [Geliştirme](#geliştirme)

## Özellikler

- **Çentikte zamanlayıcı:** Oturum sürerken çentiğin bir yanında pet, öbür yanında geri sayım görünür. Fareyle üzerine gelince panel açılır.
- **Pomodoro döngüsü:** Odak, kısa mola ve uzun mola süreleri ile uzun molanın kaç oturumda bir geleceği ayarlanabilir. Molalar ve odak oturumları istersen kendiliğinden başlar.
- **Zamanında haber:** Mola başlarken, mola biterken ve bir sonraki odak oturumundan **5 dakika önce** (süre ayarlanabilir) çentikte bir uyarı açılır, Focus Notch'a özel bir melodi çalar ve sistem bildirimi gelir.
- **Kontroller:** Başlat, duraklat, atla, sıfırla ve oturumu özetle kapatan **Bitir**.
- **Odak dostu:** 12 tatlı ve 6 piksel pet. Her biri odakta laptopta çalışır, molada uyur, oturum bitince zıplar. Bazılarına tıklayınca ses çıkarırlar. Kendi GIF'ini de ekleyebilirsin.
- **Konular ve istatistik:** Çalıştığın konuyu (Matematik, Kodlama…) seç; odak süren o konuya yazılsın. Bugün, bu hafta ve tüm zamanlar için konu bazında grafik.
- **Temalar:** Mercan, Okyanus, Orman, Lavanta, Gün Batımı ve Mono.
- **23 dil:** Türkçe, İngilizce, Çince (Basitleştirilmiş ve Geleneksel), Hintçe, İspanyolca, Fransızca, Arapça, Bengalce, Portekizce, Rusça, Urduca, Endonezce, Almanca, Japonca, Korece, Vietnamca, İtalyanca, Farsça, Lehçe, Ukraynaca, Tayca ve Felemenkçe.

## Ekran görüntüleri

### macOS: MacBook çentiğinde

| Oturum sürerken | Mola uyarısı |
| :---: | :---: |
| <img src="docs/images/macos-compact.png" width="380" alt="Çentiğin iki yanında pet ve sayaç"> | <img src="docs/images/macos-alert.png" width="380" alt="Mola zamanı uyarısı"> |

### Windows: görev çubuğunda

| Oturum sürerken | Fareyle üzerine gelince |
| :---: | :---: |
| <img src="docs/images/windows-taskbar-compact.png" width="380" alt="Görev çubuğunda küçük çentik"> | <img src="docs/images/windows-taskbar-expanded.png" width="380" alt="Görev çubuğundan yukarı açılan panel"> |

### Ayarlar

| Zamanlayıcı | Odak dostu |
| :---: | :---: |
| <img src="docs/images/settings-timer.png" width="380" alt="Süre kaydırıcıları"> | <img src="docs/images/settings-pets.png" width="380" alt="Pet seçimi"> |
| **İstatistikler** | **Genel** |
| <img src="docs/images/settings-statistics.png" width="380" alt="Konu bazında istatistik"> | <img src="docs/images/settings-general.png" width="380" alt="Dil, çentik konumu ve tema"> |

## Odak dostları

Pet'ler her zamanlayıcı durumuna göre farklı animasyon oynatır:

| Boşta | Odakta | Molada | Kutlamada |
| :---: | :---: | :---: | :---: |
| <img src="macos/FocusNotch/Resources/Pets/cute_cat_idle.gif" width="96" alt="Kedi boşta"> | <img src="macos/FocusNotch/Resources/Pets/cute_cat_focus.gif" width="96" alt="Kedi laptopta çalışıyor"> | <img src="macos/FocusNotch/Resources/Pets/cute_cat_rest.gif" width="96" alt="Kedi uyuyor"> | <img src="macos/FocusNotch/Resources/Pets/cute_cat_celebrate.gif" width="96" alt="Kedi zıplıyor"> |

**Tatlı stil**: Codex ile çizildi, 12 hayvan.

<p>
<img src="macos/FocusNotch/Resources/Pets/cute_cat_idle.gif" width="64" alt="Kedi" title="Kedi">
<img src="macos/FocusNotch/Resources/Pets/cute_dog_idle.gif" width="64" alt="Köpek" title="Köpek">
<img src="macos/FocusNotch/Resources/Pets/cute_bunny_idle.gif" width="64" alt="Tavşan" title="Tavşan">
<img src="macos/FocusNotch/Resources/Pets/cute_fox_idle.gif" width="64" alt="Tilki" title="Tilki">
<img src="macos/FocusNotch/Resources/Pets/cute_panda_idle.gif" width="64" alt="Panda" title="Panda">
<img src="macos/FocusNotch/Resources/Pets/cute_frog_idle.gif" width="64" alt="Kurbağa" title="Kurbağa">
<img src="macos/FocusNotch/Resources/Pets/cute_hamster_idle.gif" width="64" alt="Hamster" title="Hamster">
<img src="macos/FocusNotch/Resources/Pets/cute_penguin_idle.gif" width="64" alt="Penguen" title="Penguen">
<img src="macos/FocusNotch/Resources/Pets/cute_owl_idle.gif" width="64" alt="Baykuş" title="Baykuş">
<img src="macos/FocusNotch/Resources/Pets/cute_koala_idle.gif" width="64" alt="Koala" title="Koala">
<img src="macos/FocusNotch/Resources/Pets/cute_duck_idle.gif" width="64" alt="Ördek" title="Ördek">
<img src="macos/FocusNotch/Resources/Pets/cute_hedgehog_idle.gif" width="64" alt="Kirpi" title="Kirpi">
</p>

**Piksel stil**: retro piksel art, 6 hayvan.

<p>
<img src="macos/FocusNotch/Resources/Pets/cat_idle.gif" width="64" style="image-rendering: pixelated" alt="Piksel kedi">
<img src="macos/FocusNotch/Resources/Pets/dog_idle.gif" width="64" style="image-rendering: pixelated" alt="Piksel köpek">
<img src="macos/FocusNotch/Resources/Pets/bunny_idle.gif" width="64" style="image-rendering: pixelated" alt="Piksel tavşan">
<img src="macos/FocusNotch/Resources/Pets/fox_idle.gif" width="64" style="image-rendering: pixelated" alt="Piksel tilki">
<img src="macos/FocusNotch/Resources/Pets/panda_idle.gif" width="64" style="image-rendering: pixelated" alt="Piksel panda">
<img src="macos/FocusNotch/Resources/Pets/frog_idle.gif" width="64" style="image-rendering: pixelated" alt="Piksel kurbağa">
</p>

Kedi, köpek, kurbağa, ördek, baykuş ve hamstera tıklayınca ses çıkarırlar.

## İndirme ve kurulum

Hazır dosyalar [**Releases**](https://github.com/metekaganmusaak/focus-notch/releases/latest) sayfasında.

### macOS

1. Releases sayfasından **FocusNotch-macOS.zip** dosyasını indir ve aç.
2. Çıkan **FocusNotch.app** dosyasını **Uygulamalar** klasörüne sürükle.
3. Uygulama Apple tarafından onaylanmış (notarize) bir geliştirici hesabıyla imzalanmadığı için ilk açılışta macOS onu engeller. Açmak için:
   - Uygulamayı bir kez açmayı dene, sonra **Sistem Ayarları → Gizlilik ve Güvenlik** bölümünde en altta çıkan **Yine de Aç** düğmesine bas.
   - Ya da Terminal'de şunu çalıştır:

     ```sh
     xattr -dr com.apple.quarantine /Applications/FocusNotch.app
     ```

4. Bildirim izni istendiğinde **İzin Ver** de.

Gereksinim: macOS 14 Sonoma veya üstü. Çentikli MacBook'larda en iyi görünür; çentiksiz ekranlarda menü çubuğunun ortasında çalışır.

### Windows

Releases sayfasında iki dosya var:

| Dosya | Ne zaman |
| --- | --- |
| **Focus Notch Setup 1.0.0.exe** | Kalıcı kullanım. Tek tıkla kurulur, Başlat menüsüne eklenir. |
| **Focus Notch 1.0.0.exe** | Kurulum yapmadan denemek için taşınabilir sürüm. |

1. Dosyayı indirip çift tıkla.
2. Uygulama imzalı olmadığı için SmartScreen "Windows bilgisayarınızı korudu" diyebilir: **Ek bilgi → Yine de çalıştır**.
3. Çentik görev çubuğunda belirir. Uygulamanın simgesi sağ alttaki bildirim alanındadır; görünmüyorsa **^** okuna bak.

Gereksinim: 64-bit Windows 10 veya 11.

## Kullanım

1. **Başlat:** Fareyle çentiğin üzerine gel; panel açılır. Ortadaki büyük ▶ düğmesine bas. Menü çubuğu (macOS) ya da bildirim alanı (Windows) simgesinden de başlatabilirsin.
2. **Konu seç (isteğe bağlı):** Panelin konu satırındaki çiplerden birine tıkla ya da **+** ile yeni konu yaz. Bu oturumdaki odak süren o konuya yazılır. Seçili konuya tekrar tıklarsan seçim kalkar.
3. **Çalış:** Panel kapanınca çentiğin bir yanında pet laptopunda çalışır, öbür yanında sayaç akar.
4. **Mola:** Süre dolunca çentikte "Mola zamanı!" uyarısı açılır ve melodi çalar. Molada pet uyur. Sonraki oturumdan 5 dakika önce bir hatırlatma daha gelir.
5. **Kontroller:**
   - ⏸ duraklatır, ▶ devam ettirir.
   - ⏭ sonraki faza atlar.
   - ↺ süreyi baştan alır.
   - **Bitir** oturumu kapatıp toplam odak süreni ve tamamlanan oturum sayısını gösterir.
6. **Pet'i sev:** Paneldeki pet'e tıklarsan sevinir; bazıları ses çıkarır.
7. **Ayarlar:** Paneldeki ⚙ düğmesinden ya da simge menüsünden açılır.
   - **Zamanlayıcı:** Süreler ve otomatik başlatma.
   - **Odak Dostu:** Pet, stil, pet sesleri ve kendi GIF'ini ekleme (sürükle-bırak).
   - **İstatistikler:** Konu bazında süreler ve konu yönetimi.
   - **Bildirimler:** Bildirim, ses ve hatırlatma süresi.
   - **Genel:** Dil, girişte başlatma ve tema. Windows'ta çentik konumu da buradan değişir.

## macOS ve Windows farkları

| | macOS | Windows |
| --- | --- | --- |
| **Nerede durur** | MacBook çentiğinin etrafında; çentiksiz ekranda menü çubuğunun ortasında | Görev çubuğunun içinde (sanal çentik) |
| **Açılma yönü** | Aşağı doğru | Yukarı doğru (görev çubuğu üstteyse aşağı) |
| **Konum** | Sabit, çentiğin yeri | Ayarlar → Genel → Çentik konumu (Sol / Orta / Sağ ve kaydırıcı) ya da açık paneli sürükleyerek |
| **Varsayılan konum** | Ortada | Windows 11'de simgeler ortadaysa solda, aksi halde ortada |
| **Kontrol simgesi** | Menü çubuğunda (gizlenebilir) | Bildirim alanında (tray) |
| **Dil değiştirme** | Uygulama yeniden başlatılır | Anında uygulanır |
| **Teknoloji** | SwiftUI + AppKit (yerel uygulama) | Electron |
| **Boyut** | ~10 MB | ~115 MB |
| **Gereksinim** | macOS 14 veya üstü | 64-bit Windows 10 veya 11 |

Geri kalan her şey ortaktır: zamanlayıcı mantığı, uyarı ve hatırlatmalar, pet'ler ve sesleri, konular, istatistikler, temalar ve 23 dil. Windows sürümü pet'leri, sesleri ve çevirileri doğrudan macOS projesinden alır.

## Geliştirme

```
focus-notch/
├── macos/     SwiftUI + AppKit uygulaması ve PetForge (pet, ikon ve ses üretici)
├── windows/   Electron uygulaması
└── docs/      README görselleri
```

- **macOS:** `macos/FocusNotch.xcodeproj` dosyasını Xcode 16 veya üstüyle açıp ⌘R. Ayrıntılar: [macos/README.md](macos/README.md)
- **Windows:** `cd windows && npm install && npm start`. Kurulum dosyası için `npm run dist`. Ayrıntılar: [windows/README.md](windows/README.md)
- **Kod yapısı ve kurallar:** [CLAUDE.md](CLAUDE.md)
- **Görsel ve ses kaynakları ile lisansları:** [ASSETS.md](ASSETS.md)
