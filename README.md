# SnapPaste

macOS menü çubuğu uygulaması:

| Kısayol | Ne yapar |
|---|---|
| **⇧⌥S** (Shift + Option + S) | Ekran görüntüsü alır ve **panoya kopyalar** |
| **⌘V** | Son ekran görüntüsünü yapıştırır (Slack, WhatsApp, Mail, Notes, Word, Figma, tarayıcı… her yerde) |

Çekim sırasında: **fareyle sürükle** → alan seç · **Space** → pencere seçimine geç · **Esc** → iptal.

Menü çubuğundaki vizör simgesinden şunları ayarlayabilirsiniz:

- **Çekim Modu:** Alan Seç (varsayılan), Pencere, Tam Ekran (farenin bulunduğu ekran)
- **Son Görüntüyü Tekrar Kopyala:** Arada başka bir şey kopyaladıysanız
- **Deklanşör Sesi:** Açık veya kapalı
- **Oturum Açılışında Başlat:** İlk kurulumda otomatik olarak açılır

Başarılı çekimde simge kısa süreliğine ✓ olur.

Gereksinimler: **macOS 13 Ventura veya üzeri**, Apple Silicon ya da Intel (universal).

---

## Kurulum

### Bu Mac'e veya başka bir Mac'e (hazır paketle)

`dist/` klasöründe iki paket var; ikisi de aynı uygulamayı içerir:

**A) DMG ile:** `SnapPaste-1.0.0.dmg`

1. DMG'yi açın.
2. `SnapPaste.app`'i `Applications` klasörüne sürükleyin.
3. Uygulamayı açın. Uyarı çıkarsa aşağıdaki kutuya bakın. Aynı adımlar DMG içindeki **AÇILMAZSA BENİ OKU.txt** dosyasında da var.

**B) ZIP ile:** `SnapPaste-1.0.0.zip`. Açın ve klasörün içinde şunu çalıştırın:

```bash
bash install.sh
```

`install.sh` şunları yapar:

1. Çalışan eski sürümü kapatır.
2. Uygulamayı `/Applications` klasörüne kopyalar.
3. İndirme karantinasını kaldırır.
4. Uygulamayı başlatır.

> **"Apple, SnapPaste'in kötü amaçlı yazılım içermediğini doğrulayamadı" uyarısı:** Uygulama ücretli bir Apple Developer ID ile noterize edilmediği için macOS; AirDrop, mesaj, e-posta veya indirme ile aktarılan kopyayı ilk açılışta engeller. Bu uyarı bir hata değildir ve tek seferlik onay yeterlidir. İki yol var:
>
> **1. Terminal ile:** Aşağıdaki komutu çalıştırın. Komut yalnızca bu uygulamanın karantina etiketini kaldırır, genel güvenlik ayarlarını değiştirmez.
> ```bash
> xattr -dr com.apple.quarantine /Applications/SnapPaste.app && open /Applications/SnapPaste.app
> ```
>
> **2. Terminal kullanmadan:**
> 1. SnapPaste'i bir kez açmayı deneyin ve uyarıda "Bitti"ye basın.
> 2. Sistem Ayarları › Gizlilik ve Güvenlik bölümünü açın.
> 3. Sayfanın altında "SnapPaste engellendi" satırının yanındaki **"Yine de Aç"** düğmesine basın.
> 4. Parolanızı girin ve çıkan pencerede tekrar **"Yine de Aç"** deyin.
>
> USB bellek veya harici diskle Finder üzerinden kopyalanan uygulamalarda bu uyarı genelde çıkmaz. Uyarının hiç çıkmaması için uygulamanın Apple Developer Program üyeliğiyle (yıllık 99 $) Developer ID imzası alıp noterize edilmesi gerekir.

### Kaynak koddan derleyerek

Yalnızca Xcode veya Command Line Tools gerekir (`xcode-select --install`):

```bash
./scripts/build.sh
./scripts/install.sh
```

### İlk çalıştırmada: Ekran Kaydı izni (tek seferlik)

macOS, ekran görüntüsü alan her uygulamadan izin ister:

1. İlk açılışta çıkan pencerede **Sistem Ayarlarını Aç**'a tıklayın.
2. **Gizlilik ve Güvenlik › Ekran ve Sistem Sesi Kaydı** bölümünde **SnapPaste**'i açın.
3. macOS isterse **Çık ve Yeniden Aç** deyin.

İzin verilmemişse menüde "⚠️ Ekran Kaydı İzni Ver…" satırı görünür. Klavye kısayolu için ayrıca **Erişilebilirlik izni gerekmez.**

> Uygulamayı **kaynaktan yeniden derleyip** kurarsanız imza değiştiği için macOS eski izni tanımayabilir. Bu durumda listede SnapPaste'i kapatıp yeniden açın. Aynı paketi tekrar kurmak izni bozmaz.

## Kaldırma

```bash
bash dist/uninstall.sh
```

Bu betik uygulamayı, önbelleği ve ayarları siler. İsterseniz sadece `/Applications/SnapPaste.app`'i çöpe de atabilirsiniz.

---

## Tasarım ve optimizasyon

- **⌘V neden ele geçirilmiyor?** Görüntü doğrudan sistem panosuna konur. Böylece ⌘V her uygulamada yerel olarak çalışır ve normal kopyala/yapıştır bozulmaz. Arada metin kopyalarsanız ⌘V o metni yapıştırır. Görüntüyü geri almak için menüden **Son Görüntüyü Tekrar Kopyala**'yı kullanın.
- **Kısayol:** Carbon `RegisterEventHotKey` kullanılır. Erişilebilirlik veya Girdi İzleme izni gerektirmez. Uygulama boştayken **%0 CPU** harcar; sistem uygulamayı yalnızca ⇧⌥S basıldığında uyandırır.
- **Klavye düzenine duyarlı:** Kısayol, üzerinde "S" yazan tuşa bağlanır. Türkçe-F, Türkçe-Q, Dvorak, AZERTY gibi düzenlerde doğru çalışır ve düzen değişince kendini günceller.
- **Çekim:** macOS'in kendi `screencapture` aracı kullanılır. Yerel seçim arayüzü, Retina çözünürlüğü ve çoklu ekran desteği ek kod veya bellek maliyeti olmadan gelir.
- **Pano:** PNG baytları yeniden kodlanmadan panoya verilir (dosya belleğe eşlenir, `mmap`). TIFF formatını yalnızca bazı eski uygulamalar ister; bu yüzden TIFF **sadece bir uygulama talep ederse** üretilir.
- **Disk:** Önbellekte yalnızca son görüntü tutulur (`~/Library/Caches/com.yusufkorkmaz.SnapPaste`), eskiler silinir.
- **Boyut:** Universal ikili dosya yaklaşık 400 KB, DMG yaklaşık 420 KB. Swift çalışma zamanı sistemden gelir ve harici bağımlılık yoktur.
- **Ölçülen değerler** (bu Mac, macOS 26.5):

  | Ölçüm | Değer |
  |---|---|
  | Bellek (boşta / PNG ile yapıştırma sonrası) | 12–15 MB |
  | Bellek (bir uygulama TIFF isterse, pano değişene kadar) | ~40 MB |
  | Boşta CPU | %0 |
  | Tam ekran çekim → pano (arm64) | ~120 ms |
  | Tam ekran çekim → pano (Intel/Rosetta) | ~170 ms |

## Testler

Hepsini tek komutla çalıştırmak için:

```bash
./scripts/test.sh
```

Bu komut sırasıyla şunları yapar:

1. **59 birim ve entegrasyon testi** (yerel mimaride):
   - kısayol kaydı ve gerçek Carbon olay teslimi
   - klavye düzenleri (US, Türkçe-Q, Türkçe-F, Dvorak)
   - `screencapture` argümanları ve çoklu ekran seçimi
   - pano (PNG baytları birebir, talep üzerine TIFF, `NSImage` okunabilirliği, geçersiz dosya)
   - çekim servisi (başarı, iptal, izin hatası, eşzamanlı çekim engeli, eski dosya temizliği, tekrar kopyalama)
   - ayarlar
   - gerçek `screencapture` ile uçtan uca tam ekran çekim
2. Apple Silicon Mac'te aynı 59 testi **Intel (x86_64) için Rosetta altında** tekrar çalıştırır.
3. **Universal release derlemesi** yapar; DMG ve ZIP üretir.
4. **32 paket kontrolü** yapar: mimariler, minimum macOS, imza, hardened runtime, bağımlılıklar, DMG/ZIP bütünlüğü, betik sözdizimi.

Ek olarak kurulu uygulama üzerinde elle şunlar doğrulandı:

- ⇧⌥S → tam ekran ve sürükleyerek alan seçimi → pano → TextEdit'te ⌘V
- Tıklayarak iptal (uyarı çıkmaz, pano korunur)
- İkinci örneğin kendini kapatması
- Oturum açılışı kaydı
- Karantinalı ZIP'ten yeniden kurulum

## Proje yapısı

```
Sources/SnapPasteCore/      Test edilebilir çekirdek
  HotKey.swift                 Global kısayol (Carbon)
  KeyboardLayout.swift         "S" harfinin tuş kodunu aktif düzenden bulma
  CaptureCommand.swift         screencapture argümanları, ekran seçimi
  ProcessRunner.swift          Süreç çalıştırma (çıkış kodu + stderr)
  ImageClipboard.swift         PNG + talep üzerine TIFF pano yazımı
  ScreenshotService.swift      Çekim → pano akışı, iptal/hata ayrımı, dosya temizliği
  Settings.swift               Kullanıcı ayarları
  ScreenRecordingPermission.swift
Sources/SnapPaste/          Menü çubuğu uygulaması (AppDelegate, main)
Tests/SnapPasteCoreTests/   XCTest paketleri
Resources/                  Info.plist, AppIcon.icns
scripts/                    build · install · uninstall · test · verify · make-icon
dist/                       Derlenmiş .app, .dmg, .zip
```
