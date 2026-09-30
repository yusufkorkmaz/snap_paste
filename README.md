# SnapPaste

**SnapPaste**, macOS'te ekran görüntüsü alma → panoya kopyalama → yapıştırma akışını tek kısayola indiren hafif bir menü çubuğu uygulamasıdır.

**⇧⌥S** ile ekran görüntüsünü alırsınız. Görüntü doğrudan sistem panosuna yazılır; ardından Slack, WhatsApp, Mail, Notes, Word, Figma veya tarayıcıda normal **⌘V** ile yapıştırabilirsiniz.

> Yerel Swift uygulaması · Electron yok · Harici bağımlılık yok · Apple Silicon + Intel · macOS 13+

---

## Hızlı kurulum

SnapPaste şu anda kaynak koddan tek akışla kurulabilir.

### 1. Command Line Tools'u yükleyin

```bash
xcode-select --install
```

### 2. Projeyi klonlayın

```bash
git clone https://github.com/yusufkorkmaz/snap_paste.git
cd snap_paste
```

### 3. Derleyin ve kurun

```bash
./scripts/build.sh
./scripts/install.sh
```

Kurulum tamamlandığında SnapPaste otomatik olarak açılır ve menü çubuğunda çalışmaya başlar.

> `dist/` klasörü build sırasında oluşturulur ve binary dosyalar repoda tutulmaz. `build.sh`, universal `.app`, DMG ve ZIP paketlerini yerel olarak üretir.

---

## Kullanım

| Kısayol / işlem | Ne yapar |
|---|---|
| **⇧⌥S** | Ekran görüntüsü alır ve panoya kopyalar |
| **⌘V** | Panodaki son ekran görüntüsünü aktif uygulamaya yapıştırır |
| **Fareyle sürükle** | Yakalanacak alanı seçer |
| **Space** | Pencere seçimine geçer |
| **Esc** | Çekimi iptal eder |

Menü çubuğundaki SnapPaste simgesinden:

- **Alan Seç**, **Pencere** veya **Tam Ekran** çekim modunu seçebilirsiniz.
- **Son Görüntüyü Tekrar Kopyala** ile son ekran görüntüsünü yeniden panoya alabilirsiniz.
- **Deklanşör Sesi**ni açıp kapatabilirsiniz.
- **Oturum Açılışında Başlat** seçeneğini yönetebilirsiniz.

Başarılı çekimden sonra menü çubuğu simgesi kısa süreliğine **✓** durumuna geçer.

---

## İlk çalıştırmada gerekli izin

macOS, ekran içeriğine erişen uygulamalardan bir kez izin ister.

1. SnapPaste'i açın.
2. İlk çekimde çıkan pencereden **Sistem Ayarlarını Aç** seçeneğine basın.
3. **Gizlilik ve Güvenlik → Ekran ve Sistem Sesi Kaydı** bölümüne gidin.
4. **SnapPaste** için izni açın.
5. macOS isterse uygulamayı kapatıp yeniden açın.

Global klavye kısayolu için ayrıca **Erişilebilirlik** veya **Girdi İzleme** izni gerekmez.

---

## Neden SnapPaste?

macOS ekran görüntüsü almak konusunda güçlüdür; ancak ekran görüntüsünü aldıktan sonra dosyayı bulmak, sürüklemek veya başka bir uygulamaya aktarmak çoğu zaman gereksiz adımlar oluşturur.

SnapPaste bu akışı:

```text
⇧⌥S → alanı seç → ⌘V
```

şeklinde tutar.

Uygulamanın amacı ekran görüntülerini yönetmek değil, **ekran görüntüsünü mümkün olan en kısa yoldan başka bir uygulamaya taşımaktır**.

---

## Teknik yaklaşım

### Global kısayol

Carbon `RegisterEventHotKey` kullanılır.

Bu nedenle:

- uygulama boşta beklerken sürekli klavye dinlemez,
- Erişilebilirlik izni gerekmez,
- boşta yaklaşık **%0 CPU** kullanır,
- aktif klavye düzeni değiştiğinde kısayol yeniden eşlenebilir.

Kısayol fiziksel tuş koduna körlemesine bağlanmaz; aktif klavye düzenindeki **S** harfi çözülür. Türkçe-Q, Türkçe-F, Dvorak ve AZERTY gibi düzenler desteklenir.

### Ekran yakalama

macOS'in yerel `screencapture` aracı kullanılır.

Böylece:

- macOS'in kendi alan/pencere seçim deneyimi korunur,
- Retina çözünürlüğü doğal olarak desteklenir,
- çoklu ekran desteği ekstra ekran yakalama framework'ü gerektirmez.

### Pano

PNG baytları mümkün olduğunca yeniden encode edilmeden sistem panosuna yazılır.

Bazı eski uygulamalar TIFF istediğinde TIFF yalnızca talep edildiği anda üretilir.

### Disk kullanımı

Yalnızca son ekran görüntüsü cache'te tutulur:

```text
~/Library/Caches/com.yusufkorkmaz.SnapPaste
```

Yeni görüntü geldiğinde eski geçici görüntü temizlenir.

---

## Performans

Ölçülen değerler geliştirme makinesindeki testlerden alınmıştır:

| Ölçüm | Değer |
|---|---:|
| Boşta CPU | **%0** |
| Bellek — boşta / PNG sonrası | **12–15 MB** |
| Bellek — TIFF talep edilirse | **~40 MB** |
| Tam ekran → pano — arm64 | **~120 ms** |
| Tam ekran → pano — Intel/Rosetta | **~170 ms** |
| Universal executable | **~400 KB** |
| DMG | **~420 KB** |

Sonuçlar donanım ve macOS sürümüne göre değişebilir.

---

## Derleme çıktıları

```bash
./scripts/build.sh
```

komutu:

1. Apple Silicon için `arm64` release binary üretir.
2. Intel için `x86_64` release binary üretir.
3. İki binary'yi `lipo` ile universal executable haline getirir.
4. `SnapPaste.app` oluşturur.
5. Hardened Runtime ile ad-hoc imza uygular.
6. DMG ve ZIP dağıtım paketlerini üretir.

Çıktılar:

```text
dist/
├── SnapPaste.app
├── SnapPaste-1.0.0.dmg
├── SnapPaste-1.0.0.zip
├── install.sh
├── uninstall.sh
└── README.md
```

---

## Gatekeeper notu

SnapPaste şu anda Apple Developer ID ile notarize edilmiş bir release dağıtmıyor.

Başka bir Mac'e indirme/AirDrop/e-posta ile taşınan ad-hoc imzalı uygulamada macOS ilk açılışta şu uyarıyı gösterebilir:

> Apple, SnapPaste'in kötü amaçlı yazılım içermediğini doğrulayamadı.

Kaynak koddan kurulumda `scripts/install.sh`, yalnızca SnapPaste uygulamasının quarantine etiketini kaldırır.

Manuel olarak yapmak gerekirse:

```bash
xattr -dr com.apple.quarantine /Applications/SnapPaste.app
open /Applications/SnapPaste.app
```

Bu işlem macOS'in genel güvenlik ayarlarını kapatmaz.

---

## Testler

Tüm test, release build ve paket doğrulamalarını tek komutta çalıştırabilirsiniz:

```bash
./scripts/test.sh
```

Test akışı şunları kapsar:

- global hotkey kaydı ve gerçek Carbon event teslimi,
- US, Türkçe-Q, Türkçe-F ve Dvorak klavye düzenleri,
- alan/pencere/tam ekran `screencapture` parametreleri,
- çoklu ekran seçimi,
- PNG pano round-trip,
- ihtiyaç halinde TIFF üretimi,
- geçersiz dosya senaryoları,
- çekim iptali,
- eşzamanlı çekim engeli,
- cache temizliği,
- ayarların saklanması,
- universal release build,
- arm64 ve x86_64 mimari kontrolleri,
- minimum macOS sürümü,
- code-sign doğrulaması,
- hardened runtime,
- DMG/ZIP bütünlüğü,
- shell script syntax kontrolleri.

Apple Silicon makinede Rosetta mevcutsa test paketi ayrıca **x86_64** altında da çalıştırılır.

---

## Proje yapısı

```text
Sources/
├── SnapPasteCore/
│   ├── HotKey.swift
│   ├── KeyboardLayout.swift
│   ├── CaptureCommand.swift
│   ├── ProcessRunner.swift
│   ├── ImageClipboard.swift
│   ├── ScreenshotService.swift
│   ├── Settings.swift
│   └── ScreenRecordingPermission.swift
└── SnapPaste/
    └── menü çubuğu uygulaması

Tests/
└── SnapPasteCoreTests/

Resources/
├── Info.plist
└── AppIcon.icns

scripts/
├── build.sh
├── install.sh
├── uninstall.sh
├── test.sh
└── verify.sh
```

---

## Geliştirme

Geliştirme için macOS 13+ ve Xcode / Command Line Tools yeterlidir.

```bash
git clone https://github.com/yusufkorkmaz/snap_paste.git
cd snap_paste
swift test
swift run SnapPaste
```

Release paketini doğrulamak için:

```bash
./scripts/test.sh
```

---

## Kaldırma

Repo içinden:

```bash
bash scripts/uninstall.sh
```

veya uygulamayı yalnızca kaldırmak istiyorsanız:

```bash
rm -rf /Applications/SnapPaste.app
```

---

## Gizlilik

SnapPaste ekran görüntülerini harici bir servise yüklemez.

Uygulamanın temel akışı yereldir:

```text
macOS screencapture → yerel geçici dosya → macOS pasteboard
```

Ağ servisi veya kullanıcı hesabı gerektirmez.

---

## Lisans

Henüz ayrı bir lisans dosyası eklenmemiştir. Kaynak kodu kullanmadan veya yeniden dağıtmadan önce proje sahibinden izin alın.
