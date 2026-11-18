# Robot Arena Tycoon

Roblox tycoon + robot arena oyunu. Kod VS Code'da yazılır, [Rojo](https://rojo.space) ile Studio'ya senkronlanır.

## Durum

- [x] Aşama 0: Rojo proje iskeleti
- [x] Aşama 1: Veri kaydı, fabrika, hurda üretimi, upgrade'ler, HUD
- [x] Aşama 2: Parçalar, kasalar, garaj (kod hazır; 3D modeller şimdilik primitive)
- [x] Aşama 3: Arena, bot rakipler, kupa ve lig, global kupa tablosu
- [x] Aşama 4: Rebirth + token ağacı, Robux mağazası, günlük ödül ve görevler, teklifler
- [ ] Aşama 5: Cila ve lansman

## Kurulum (bir kere)

1. **Roblox Studio**'yu kur ve giriş yap.
2. **VS Code**'u kur.
3. VS Code eklentileri: **Rojo** (evaera.vscode-rojo) ve **Luau Language Server** (JohnnyMorganz.luau-lsp).
4. VS Code'da `Ctrl+Shift+P` → **Rojo: Open menu** → **Install Roblox Studio plugin**.
   - Alternatif: [Rokit](https://github.com/rojo-rbx/rokit) kuruluysa proje klasöründe `rokit install` yaz, `rokit.toml`'daki Rojo sürümü gelir.

## Çalıştırma

1. Bu klasörü VS Code'da aç.
2. `Ctrl+Shift+P` → **Rojo: Open menu** → `default.project.json` → **Start**.
3. Studio'da yeni bir **Baseplate** projesi aç.
4. Studio'da **Plugins** sekmesi → **Rojo** → **Connect**.
5. Kodlar Studio'ya düşer. **Play** (F5) ile test et.

VS Code'da bir dosyayı kaydettiğin an Studio'daki kopyası da güncellenir.

## Studio ayarları

- **Veri kaydı için:** Oyunu bir kere yayınla (File → Publish to Roblox), sonra
  Game Settings → Security → **Enable Studio Access to API Services**'i aç.
  Kapalıysa oyun yine çalışır ama veri sadece bellekte tutulur (çıkınca sıfırlanır), Output'ta uyarı görürsün.
- **Max players:** Game Settings → Places → Max Players = **6** (sunucuda 6 arsa var).

## Proje yapısı

```
src/
├─ server/                → ServerScriptService.Server
│  ├─ Main.server.luau    giriş noktası
│  └─ Services/
│     ├─ DataService      veri yükleme/kaydetme, session lock
│     ├─ TycoonService    arsa, üretim, toplama, upgrade
│     ├─ PartService      envanter, kasa (olasılık + pity), parça takma, birleştirme
│     ├─ ArenaService     kuyruk, eşleştirme, bot, maç simülasyonu, ödül/kupa
│     ├─ ArenaBuilder     arena platformları, arena kapısı, kupa tablosu
│     ├─ LeaderboardService  global kupa sıralaması (OrderedDataStore)
│     ├─ RebirthService   rebirth + token ağacı
│     ├─ MonetizationService  Robux ürünleri (ProcessReceipt) + teklifler
│     ├─ DailyService     günlük giriş serisi, günlük görevler, VIP kasası
│     ├─ Events           servisler arası olaylar (görev ilerlemesi, teklifler)
│     └─ PlotBuilder      arsaları kodla oluşturur
├─ client/                → StarterPlayerScripts.Client
│  ├─ Main.client.luau
│  ├─ HUD                 hurda sayacı + bildirimler
│  ├─ ScrapVisuals        konveyördeki hurda küpleri (sadece görsel)
│  ├─ GarageUI            garaj ekranı (G tuşu)
│  ├─ CrateUI             kasa açılış animasyonu
│  ├─ ArenaController     maç kamerası, yön girişi, yetenek, can barları, sonuç ekranı
│  ├─ SideMenu            sol alttaki menü butonları + ortak panel iskeleti
│  ├─ ShopUI              mağaza + teklif kartı
│  ├─ RebirthUI           rebirth + token ağacı paneli
│  ├─ DailyUI             günlük ödül + görevler
│  └─ UIKit               ortak UI yardımcıları
└─ shared/                → ReplicatedStorage.Shared
   ├─ Config/             Economy, Upgrades, GamePasses, Products, Parts, Rarities, Crates, Arena, Rebirth, Daily
   ├─ Formulas            fiyat, üretim, kapasite hesapları
   ├─ RobotStats          parçalardan Güç/Can/Hasar/Hız hesabı
   ├─ RobotBuilder        parçalardan robot modeli (primitive'lerle)
   ├─ Items               envanter anahtarı "PartId|Rarity"
   ├─ Remotes             RemoteEvent tanımları
   └─ Util                sayı formatlama, tablo yardımcıları
```

## Kendi haritanı yapınca

Arsalar şu an kodla oluşturuluyor. Kendin tasarlamak istersen Workspace'e `Plots` adında bir klasör koy,
içine `Plot1` ... `Plot6` modelleri yap. Her modelde şu isimler olmalı:

| Parça | Ne işe yarar |
| --- | --- |
| `Base` | Zemin (PrimaryPart) |
| `Sign` | İçinde `OwnerGui` BillboardGui → `Label` TextLabel |
| `Collector` | Hurda toplayıcı |
| `Conveyor` | Bant (hurda küpleri bunun üstünden gider) |
| `Box` | `CollectPrompt` ProximityPrompt + `BoxGui` → `Label` |
| `SpawnPoint` | Oyuncunun doğduğu yer |
| `Pads/<UpgradeId>` | Her upgrade için bir ped: `BuyPrompt` + `PadGui` → `Label` |
| `RobotStand` | Robotun sergilendiği kaide (robot bunun üst yüzeyine, aynı yöne bakarak konur) |
| `CrateMachine` | `CratePrompt` ProximityPrompt (+ isteğe bağlı `CrateGui` → `Label`) |

En kolayı: oyunu bir kere çalıştır, Workspace'teki `Plots` klasörünü kopyala, oyunu durdur, yapıştır ve üstünde düzenle.

## Test listesi (Aşama 1)

- [ ] Oyuna girince kendi arsana ışınlanıyor musun, tabelada adın yazıyor mu?
- [ ] Kutudaki sayı her saniye artıyor mu, konveyörde küpler gidiyor mu?
- [ ] `E` ile toplayınca üstteki Hurda sayacı artıyor mu?
- [ ] Ped'den upgrade alınca hız (+x/sn) artıyor mu, fiyat yükseliyor mu?
- [ ] Paran yetmezken alınca kırmızı bildirim geliyor mu?
- [ ] Başkasının arsasındaki ped'e basınca "Bu senin fabrikan değil" diyor mu? (Test → Clients and Servers → 2 oyuncu)
- [ ] Çık, 1-2 dakika bekle, gir: hurda kaldı mı, "sen yokken..." bildirimi geldi mi? (API erişimi açıkken)

## Test listesi (Aşama 2)

Hızlı test için `src/shared/Config/Economy.luau`'da geçici olarak `BaseRate = 500` yap (sonra geri al!).

- [ ] Arsadaki kaidede başlangıç robotu duruyor mu (teneke gövde, testere, tekerlek, plaka), üstünde "Güç: X" yazıyor mu?
- [ ] Mor kasa makinesinde `E` ya da garajdaki butonla kasa açınca animasyon oynuyor, hurda düşüyor mu?
- [ ] Garajda (G) yeni parça görünüyor mu, "Tak" deyince kaidedeki robot değişiyor mu?
- [ ] Eski parça envantere geri dönüyor mu?
- [ ] Aynı parçadan 3 tane olunca "Birleştir" yeşil oluyor ve bir üst nadirlik geliyor mu?
- [ ] Ağır zırh + çekiç takınca Ağırlık kırmızı "AĞIR!" oluyor, hız düşüyor mu?
- [ ] Çıkıp girince envanter ve takılı parçalar kalıyor mu?

## Arena nasıl çalışıyor?

Maçın tamamı sunucuda hesaplanır: konum, dönüş, hasar, savrulma. Robot modelleri `AlignPosition`
ile hesaplanan noktaya çekilir, böylece client'ta akıcı görünür ama kimse hile yapamaz.
Oyuncu sadece yön (WASD / joystick) ve yetenek (F) gönderir. Yön vermezse robot kendi saldırır.

| Silah | Tarz | Yetenek |
| --- | --- | --- |
| Testere | Yakın, sık vuruş | Turbo: 2.5 sn hız ×1.8, hasar ×1.5 |
| Çekiç Kol | Yavaş, büyük savurma | Şok Dalgası: çevreye hasar + büyük savurma |
| Alev Makinesi | Uzak, yakar | Alev Patlaması: 2 sn menzil +4, hasar ×2 |

Ağır robotlar daha az savrulur. Platformdan düşen ya da canı biten kaybeder. 90 saniye dolarsa can yüzdesi yüksek olan kazanır.
Bütün sayılar `src/shared/Config/Arena.luau`'da.

## Test listesi (Aşama 3)

- [ ] Ortadaki kırmızı kapıda `E` → "Rakip aranıyor" çubuğu çıkıyor mu, İptal çalışıyor mu?
- [ ] 10 sn sonra bot maçı başlıyor mu: kamera arenaya geçiyor, 3-2-1-SAVAŞ!
- [ ] Hiçbir şeye basmazsan robotun rakibe gidip saldırıyor mu?
- [ ] WASD ile yönlendirebiliyor musun, bırakınca tekrar otomatik saldırıyor mu?
- [ ] Hasar sayıları ve kıvılcımlar çıkıyor mu, can barları düşüyor mu?
- [ ] F ile yetenek çalışıyor, buton geri sayıyor mu?
- [ ] Çekiçle rakibi platformdan düşürebiliyor musun?
- [ ] Maç sonu ekranı (hurda + kupa) geliyor, 4 sn sonra fabrikana dönüyor musun?
- [ ] Oyuncu listesinde "Kupa" güncelleniyor mu, kapının yanındaki tabloda adın var mı?
- [ ] 2 oyunculu test (Test → Clients and Servers → 2): ikisi de kapıya girince birbirleriyle eşleşiyor mu?
- [ ] **His testi:** Robotlar çok mu hızlı/yavaş, maçlar çok mu kısa/uzun? `Arena.luau`'daki sayılarla oyna.

## Robux ürünlerini bağlama (Aşama 4)

Oyun yayınlanmış olmalı. [Creator Hub](https://create.roblox.com/dashboard/creations) → oyunun → **Monetization**:

1. **Passes** → 5 pass oluştur, fiyat ver, "Item for sale" aç. ID'leri `src/shared/Config/GamePasses.luau`'ya yaz:
   `DoubleScrap`, `AutoCollect`, `ExtraGarage`, `LuckyCrate`, `VIP`.
2. **Developer Products** → 5 ürün oluştur. ID'leri `src/shared/Config/Products.luau`'da `Id = 0` yerlerine yaz:
   `SmallScrap`, `BigScrap`, `MegaCrate`, `Boost`, `Repair`.
3. Önerilen fiyatlar `Products.luau`'da (`Price`) ve GDD'de. Mağaza gerçek fiyatı Roblox'tan çeker.

ID'si 0 olan ürün mağazada "Yakında" görünür, teklif olarak hiç çıkmaz; yani ID girmeden de oyun sorunsuz çalışır.
Studio'da satın alma test modunda gerçek Robux harcanmaz.

**Satın alma güvenliği:** Her ürün sunucuda `ProcessReceipt` ile verilir, aynı satın alma iki kez verilmez,
ürün verildikten sonra veri hemen kaydedilir. Tamir Kiti maç dışında alınırsa karşılığında hurda verilir.

## Test listesi (Aşama 4)

- [ ] Sol altta 4 buton var mı: Garaj, Mağaza, Rebirth, Günlük? Biri açılınca diğeri kapanıyor mu?
- [ ] **Günlük:** İlk girişte butonda kırmızı nokta, 1. gün ödülü alınıyor mu? Görevler ilerliyor mu (kutudan topla, upgrade al, kasa aç)?
- [ ] **Rebirth:** `Economy.BaseRate = 5000` ile hızlıca 100K'ya çık. İlk basışta "Emin misin?", ikinci basışta fabrika sıfırlanıyor, üretim çarpanı artıyor, 1 token geliyor mu?
- [ ] Token ağacından bir şey al: Dev Kutu kapasiteyi artırıyor mu?
- [ ] Parçalar ve robot rebirth sonrası duruyor mu?
- [ ] **Mağaza:** ID girmeden "Yakında" yazıyor mu? ID girince fiyat geliyor, Studio test satın alması ürünü veriyor mu?
- [ ] 3x Boost alınca üstte geri sayım çıkıyor, üretim 3 katına çıkıyor, bitince normale dönüyor mu?
- [ ] Ekstra Garaj pass'i ile garajda "Garaj 1 ⇄ 2" butonu çıkıyor, ikinci robota geçiyor mu?
- [ ] Teklif kartı: kutu dolunca / maç kaybedince sağ üstte çıkıyor mu (3 dakikada en fazla 1)?
