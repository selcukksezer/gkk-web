# Midjourney Item Prompt Paketi

Bu klasor, oyundaki itemler icin kategori bazli ve iteme ozel Midjourney promptlari icerir.

## Dosyalar

- 00_STYLE_GUIDE.md: Tum itemler icin ortak cizim dili ve teknik kapanis
- 01_weapons.md: 24 silah
- 02_chest.md: 24 gogus zirhi
- 03_head.md: 24 kafalik
- 04_legs.md: 24 bacak zirhi
- 05_boots.md: 24 bot
- 06_gloves.md: 24 eldiven
- 07_rings.md: 24 yuzuk
- 08_necklaces.md: 24 kolye
- 09_resources.md: 90 kaynak item
- 10_special_items.md: 37 ozel item (potion, scroll, rune, catalyst, han, detox, monument)

## Toplam

- Ekipman: 192
- Kaynak: 90
- Ozel item: 37
- Genel toplam: 319 prompt

Tum promptlar arkaplansiz, tek obje ikon ve ayni sanat dili hedefiyle yazilmistir.

## Kayit Kurali

Her item satirinin hemen altina su bilgiler eklendi:
- Kayit: PNG'nin repo icindeki tam hedef yolu
- PNG: Cozunurluk ve format standardi

Klasor esleme kurali:
- wpn_: /assets/icons/weapons/
- chest_, head_, legs_, boots_, gloves_: /assets/icons/armor/
- ring_, neck_: /assets/icons/accessories/
- potion_, detox_: /assets/icons/potions/
- rune_: /assets/icons/runes/
- digerleri (res_, scroll_, catalyst_, han_item_, resource_): /assets/icons/materials/

## PNG Teknik Standart

- Uretim (master): 1024x1024 px
- Oyun ici kullanim: 512x512 px
- Format: PNG-24, RGBA, transparent background
- Dosya adi: item_id ile birebir ayni olmali

