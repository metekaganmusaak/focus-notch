# Focus Notch — Windows

macOS sürümünün Electron ile yazılmış Windows karşılığı. PC'lerde donanım çentiği olmadığı için sanal çentik **görev çubuğunun içinde** durur ve üzerine gelince yukarı doğru büyür. Özellikler Mac sürümüyle aynıdır: Pomodoro döngüsü, 5 dk hatırlatma, animasyonlu pet'ler ve sesleri, konular ve istatistikler, temalar ve 23 dil.

## Gereksinimler

- Windows 10 veya 11 (geliştirme macOS ve Linux'ta da çalışır)
- Node.js 20 veya üstü

## Çalıştırma

```sh
cd windows
npm install
npm start
```

`npm start` önce `npm run sync` çalıştırır. Bu adım pet GIF'lerini, sesleri ve ikonu `../macos/FocusNotch/Resources` klasöründen kopyalar, `Localizable.xcstrings` dosyasını da `assets/locales/*.json` dosyalarına çevirir. Böylece iki uygulama aynı içerik ve çevirileri paylaşır.

Uygulama görev çubuğunda görünmez. Bildirim alanındaki (tray) simgeye tıklayınca ayarlar açılır, sağ tıklayınca kontrol menüsü gelir.

## Kurulum dosyası

```sh
npm run dist
```

`dist/` klasörüne x64 ve ARM64 için bir NSIS kurulum dosyası (`Focus Notch Setup *.exe`) üretir. Bu komutu Windows'ta çalıştırın.

## Sanal çentik nasıl çalışır

- **Yer:** Windows 11'de simgeler ortadaysa onları kapatmamak için sol tarafta, simgeler soldaysa veya Windows 10'da ortada durur. Paneli açıp alt şeridinden tutarak sağa sola sürükleyebilirsin; konum hatırlanır. Görev çubuğu üstteyse çentik de üstten aşağı doğru açılır.
- **Sabit pencere:** Görev çubuğunun üstünde 760×300 boyutunda, şeffaf ve her zaman üstte duran bir pencere var. Pencere hiç taşınmaz ve boyutu değişmez. Siyah çentik şekli bu pencerenin içinde yay fiziğiyle animasyonlu bir SVG; içerik de aynı yola kırpılır. Bu sayede büyüme ve küçülme sırasında kayma ya da taşma olmaz.
- **Tıklamalar:** Şeffaf alanlara yapılan tıklamalar alttaki pencerelere geçer. Fare çentiğin üzerine gelince panel tıklanabilir hale gelir, uzaklaşınca yeniden geçirgen olur.
- **Görünümler:** Boştayken küçük bir hap gibi durur. Oturum sürerken iki yanında pet ve sayaç görünür. Üzerine gelince tam panel açılır.

## Geliştirme

- `npm run snapshot -- --taskbar`: Görev çubuğu yerleşimini Mac veya Linux'ta da önizler.
- `npm run snapshot`: Tüm görünümleri `snapshots/` klasörüne PNG olarak kaydeder. Geçici bir profil kullanır; dil seçmek için `npm run snapshot -- --lang=tr`.
- VS Code terminalinde Electron düz Node gibi açılıyorsa `ELECTRON_RUN_AS_NODE` değişkenini kaldırın.
- Kod yapısı için depo kökündeki `CLAUDE.md` dosyasına bakın.
