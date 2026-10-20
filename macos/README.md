# Focus Notch — macOS

MacBook çentiğinde (notch) yaşayan bir Pomodoro zamanlayıcısı ve size eşlik eden sevimli bir "odak dostu".

## Özellikler

- **Çentikte zamanlayıcı:** Oturum sürerken çentiğin bir yanında pet, öbür yanında geri sayım görünür. Fareyle çentiğin üzerine gelince panel genişler.
- **Kontroller:** Başlat/Duraklat, Sürdür, Atla, Sıfırla ve oturumu özetle kapatan **Bitir**.
- **Döngü:** Odak, kısa mola ve uzun mola süreleri ile uzun molanın kaç oturumda bir geleceği ayarlanabilir. Molaların ve odak oturumlarının otomatik başlaması da seçilebilir.
- **Haber verme:** Mola başlarken, mola biterken ve bir sonraki odak oturumundan **5 dk önce** (süre ayarlanabilir) çentikte bir uyarı açılır, Focus Notch'a özel bir melodi çalar ve sistem bildirimi gönderilir. Hatırlatma süresinden kısa molalarda bu bilgi mola başlarken verilir.
- **Konular:** Genişleyen panelin altındaki çiplerden çalıştığın konuyu seç ya da "+" ile yenisini yaz. Odak süresi o konuya yazılır; Ayarlar → İstatistikler'de bugün, bu hafta ve tüm zamanlar için konu bazında görünür.
- **Temalar:** Mercan, Okyanus, Orman, Lavanta, Gün Batımı ve Mono.
- **Odak dostu:** Kedi, köpek, tavşan, tilki, panda, kurbağa, hamster, penguen, baykuş, koala, ördek ve kirpi var (son altısı yalnızca Tatlı stilde). Bazılarına tıklayınca ses çıkarıyorlar. Her birinin dört animasyonu bulunur: boşta, odakta (laptopta çalışır), molada (uyur) ve kutlamada (zıplar). İki stil arasında seçim yapabilirsiniz: **Tatlı** (Codex ile çizilmiş illüstrasyonlar, varsayılan) ve **Piksel** (retro piksel art). Ayarlardan kendi GIF'inizi de ekleyebilirsiniz; sürükleyip bırakmak yeterli.
- **İstatistik:** Bugünkü odak süresi ve tamamlanan oturum sayısı.
- **23 dil:** İngilizce, Türkçe, Çince (Basitleştirilmiş/Geleneksel), Hintçe, İspanyolca, Fransızca, Arapça, Bengalce, Portekizce (BR), Rusça, Urduca, Endonezce, Almanca, Japonca, Korece, Vietnamca, İtalyanca, Farsça, Lehçe, Ukraynaca, Tayca ve Felemenkçe. Dil, uygulamanın içinden de değiştirilebilir.
- Çentiksiz ekranlarda menü çubuğunun ortasında sanal bir çentik olarak çalışır. Menü çubuğu simgesi ve "girişte başlat" seçeneği de vardır.

## Gereksinimler

- macOS 14 Sonoma veya üstü
- Xcode 16 veya üstü (Xcode 26 ile derlendi)

## Çalıştırma

1. `FocusNotch.xcodeproj` dosyasını Xcode'da açın.
2. **Run** (⌘R) ile çalıştırın.

Uygulamanın Dock simgesi yoktur. Ayarlara çentikteki dişli düğmesinden, menü çubuğu simgesinden ya da uygulamayı yeniden açarak ulaşabilirsiniz.

Proje "Sign to Run Locally" ile imzalanır. Başka bir Mac'e dağıtmak için **Signing & Capabilities** bölümünden kendi geliştirici ekibinizi seçin.

## Proje yapısı

| Klasör | İçerik |
| --- | --- |
| `FocusNotch/App` | Uygulama girişi, `AppModel` (olayları çentiğe, sese ve bildirime bağlar), menü çubuğu menüsü |
| `FocusNotch/Timer` | `PomodoroEngine` (fazlar, hatırlatmalar, bitirme) ve günlük istatistikler |
| `FocusNotch/Notch` | Çentik paneli, şekli, fareyle üzerine gelme takibi ve SwiftUI görünümleri |
| `FocusNotch/Pets` | Pet deposu (hazır pet'ler ve özel GIF'ler) ile GIF oynatıcı |
| `FocusNotch/Settings` | Ayarlar deposu ve ayarlar penceresi |
| `FocusNotch/Resources` | Pet GIF'leri, uygulama ikonu, `Localizable.xcstrings` |
| `Tools/PetForge` | Pet GIF'lerini, uygulama ikonunu ve bildirim seslerini üreten Swift paketi |
| `Tools/Art` | Codex ile üretilmiş kaynak görseller (pet karakter sayfaları ve ikon) |

## Pet'leri, ikonu ve sesleri yeniden üretmek

Komutları `macos/` klasöründen çalıştırın:

```sh
# Piksel stil: pet'ler koddan çizilir (Tools/PetForge/Sources/petforge/PixelPets.swift)
swift run -c release --package-path Tools/PetForge petforge pixel --preview /tmp/pixel.png

# Tatlı stil: Tools/Art içindeki Codex karakter sayfalarından animasyonlu GIF'ler
swift run -c release --package-path Tools/PetForge petforge cute Tools/Art --preview /tmp/cute.png

# Uygulama ikonu: Codex görselinden
swift run -c release --package-path Tools/PetForge petforge icon Tools/Art/icon.png

# Bildirim melodileri (sentezlenir)
swift run -c release --package-path Tools/PetForge petforge sounds
```

Hayvan sesleri (`Resources/Sounds/pet_*.wav`) CC0 kayıtlardır; kaynakları depo kökündeki `ASSETS.md` dosyasında.

Her karakter sayfası düz macenta (#FF00FF) arka plan üzerinde 2×2 pozdan oluşur. Sol üstte boşta, sağ üstte odakta (laptopta), sol altta uykuda, sağ altta kutlamada. PetForge arka planı şeffaflaştırır ve pozları ayırır. Ardından nefes alma, zıplama, "z" ve parıltı animasyonlarını ekleyip GIF'leri `FocusNotch/Resources/Pets/` klasörüne yazar. Her GIF ImageIO ile geri okunup doğrulanır.

Yeni bir pet eklemek için önce aynı düzende bir karakter sayfası üretin (Codex'e stil referansı olarak `Tools/Art/cat.png` verilebilir). Sonra `CutePets.swift` içindeki `cutePetNames` listesine ve uygulamadaki `PetStore.builtIn` listesine ekleyin.

## Çeviriler

Tüm metinler `FocusNotch/Resources/Localizable.xcstrings` dosyasındadır; Windows sürümü de çevirileri buradan alır (`windows/` içinde `npm run sync`). Her anahtarda çevirmenler için bir açıklama bulunur. Yeni bir metin eklediğinizde Xcode onu derleme sırasında kataloğa ekler; çevirilerini Xcode'un String Catalog düzenleyicisinden girebilirsiniz.
