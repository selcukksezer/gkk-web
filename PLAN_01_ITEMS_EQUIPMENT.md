# PLAN 01 — Item & Ekipman Sistemi

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-04  
> **Bağımlılıklar:** Tesis sistemi (kaynak üretimi), Crafting sistemi (üretim), Enhancement sistemi (+0/+10)

---

## 1. Genel Bakış

Oyunda **8 ekipman slotu** × **4 alt tip** × **6 nadirlik seviyesi** = **192 benzersiz ekipman** bulunacak.
Her ekipmanın Latince/İngilizce benzersiz ismi, farklı stat dağılımı ve nadirliğe göre artan güç seviyesi olacak.

### 1.1 Ekipman Slotları

| Slot Key | Türkçe | İngilizce | Birincil Stat | İkincil Stat |
|----------|--------|-----------|---------------|--------------|
| `weapon` | Silah | Weapon | Attack | Power |
| `chest` | Zırh | Chest Armor | Defense | HP |
| `head` | Kafalık | Headgear | Attack + Defense | — |
| `legs` | Ayaklık | Legwear | Defense | HP |
| `boots` | Bot | Boots | Agility/Luck | Defense |
| `gloves` | Eldiven | Gloves | Attack | Luck |
| `ring` | Yüzük | Ring | Dengeli (küçük) | Luck |
| `necklace` | Kolye | Necklace | HP | Luck |

### 1.2 Nadirlik Seviyeleri (Rarity)

| Rarity | Türkçe | Renk Kodu | Güç Çarpanı | Gerekli Seviye (min) |
|--------|--------|-----------|-------------|---------------------|
| `common` | Sıradan | `#B0B0B0` | ×1.0 | 1 |
| `uncommon` | Yaygın Olmayan | `#33CC33` | ×1.8 | 5 |
| `rare` | Nadir | `#4D80FF` | ×3.2 | 15 |
| `epic` | Destansı | `#9933CC` | ×5.5 | 25 |
| `legendary` | Efsanevi | `#FF8000` | ×9.0 | 40 |
| `mythic` | Mitik | `#FF3333` | ×15.0 | 55 |

---

## 2. Stat Formülleri

### 2.1 Baz Stat Tablosu (Nadirliğe Göre)

Her slot için baz statlar aşağıdaki aralıklarda olacak:

| Rarity | Attack | Defense | HP | Luck |
|--------|--------|---------|-----|------|
| Common | 500–1,000 | 300–800 | 1,000–2,000 | 100–200 |
| Uncommon | 1,200–2,000 | 1,000–1,800 | 2,500–4,500 | 300–500 |
| Rare | 2,500–4,000 | 2,200–3,500 | 5,000–8,000 | 600–1,000 |
| Epic | 4,500–7,000 | 4,000–6,000 | 8,500–13,000 | 1,200–1,800 |
| Legendary | 8,000–12,000 | 7,000–10,000 | 14,000–20,000 | 2,000–3,000 |
| Mythic | 13,000–20,000 | 11,000–17,000 | 22,000–35,000 | 3,500–5,000 |

### 2.2 Slot Stat Dağılımı Ağırlıkları

Her slot, baz statları farklı ağırlıklarla kullanır:

```
Weapon:   attack × 1.0,  defense × 0.0,  hp × 0.0,  luck × 0.2
Chest:    attack × 0.0,  defense × 1.0,  hp × 0.8,  luck × 0.0
Head:     attack × 0.5,  defense × 0.5,  hp × 0.3,  luck × 0.1
Legs:     attack × 0.0,  defense × 0.8,  hp × 0.6,  luck × 0.1
Boots:    attack × 0.0,  defense × 0.3,  hp × 0.2,  luck × 1.0
Gloves:   attack × 0.7,  defense × 0.1,  hp × 0.0,  luck × 0.5
Ring:     attack × 0.3,  defense × 0.3,  hp × 0.3,  luck × 0.8
Necklace: attack × 0.1,  defense × 0.2,  hp × 1.0,  luck × 0.6
```

### 2.3 Alt Tip Farklılıkları

Her slottaki 4 alt tip, hafif stat varyasyonları sağlar:

- **Tip A (Tank/Heavy):** Defense +15%, Attack -10%
- **Tip B (Balanced):** Tüm statlar baz değer
- **Tip C (Agile/Light):** Luck +20%, Defense -15%
- **Tip D (Magic/Arcane):** HP +10%, Attack +5%, Defense -10%

### 2.4 Enhancement Bonus Formülü

```
final_stat = base_stat × (1 + enhancement_level × 0.15)
```

+10 ekipman, baz statın **2.5× katı** güce sahip olur.

### 2.5 Toplam Güç Hesaplaması (Total Power)

```
total_power = Σ(tüm ekipmanlar: attack + defense + hp/10 + luck×2)
             + level × 500
             + reputation × 0.1
```

Örnek: Level 70, full Mythic +10 set, 356K saygınlık → ~450,000 power
Bu değer zindan başarı oranı hesaplamalarında kullanılır.

---

## 3. Tam Ekipman Kataloğu (192 Item)

### 3.1 WEAPONS (Silahlar) — Slot: `weapon`

#### Tip A: Dagger (Hançer)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `wpn_dagger_common` | Pugio Rusticus | 800 | 0 | 0 | 100 |
| Uncommon | `wpn_dagger_uncommon` | Sica Venefica | 1,600 | 0 | 0 | 400 |
| Rare | `wpn_dagger_rare` | Noctis Kris | 3,300 | 0 | 0 | 800 |
| Epic | `wpn_dagger_epic` | Misericordia Sanguinis | 5,800 | 0 | 0 | 1,500 |
| Legendary | `wpn_dagger_legendary` | Umbra Letalis | 10,000 | 0 | 0 | 2,500 |
| Mythic | `wpn_dagger_mythic` | Fatum Aeternum | 16,500 | 0 | 0 | 4,200 |

#### Tip B: Sword (Kılıç)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `wpn_sword_common` | Gladius Ferreus | 1,000 | 0 | 0 | 100 |
| Uncommon | `wpn_sword_uncommon` | Spatha Bellatoris | 2,000 | 0 | 0 | 300 |
| Rare | `wpn_sword_rare` | Falcata Ignis | 4,000 | 0 | 0 | 600 |
| Epic | `wpn_sword_epic` | Claymore Tempestatis | 7,000 | 0 | 0 | 1,200 |
| Legendary | `wpn_sword_legendary` | Caliburnus Rex | 12,000 | 0 | 0 | 2,000 |
| Mythic | `wpn_sword_mythic` | Animus Divinus | 20,000 | 0 | 0 | 3,500 |

#### Tip C: Axe (Balta)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `wpn_axe_common` | Securis Laboris | 900 | 0 | 0 | 200 |
| Uncommon | `wpn_axe_uncommon` | Bipennis Silvana | 1,800 | 0 | 0 | 500 |
| Rare | `wpn_axe_rare` | Francisca Glacialis | 3,600 | 0 | 0 | 1,000 |
| Epic | `wpn_axe_epic` | Labrys Volcania | 6,300 | 0 | 0 | 1,800 |
| Legendary | `wpn_axe_legendary` | Pelekys Titanis | 10,800 | 0 | 0 | 3,000 |
| Mythic | `wpn_axe_mythic` | Securis Ragnarok | 18,000 | 0 | 0 | 5,000 |

#### Tip D: Staff (Asa)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `wpn_staff_common` | Baculum Ligneum | 700 | 0 | 200 | 100 |
| Uncommon | `wpn_staff_uncommon` | Virga Herbalis | 1,400 | 0 | 500 | 300 |
| Rare | `wpn_staff_rare` | Sceptrum Crystallinum | 2,800 | 0 | 800 | 700 |
| Epic | `wpn_staff_epic` | Caduceus Temporis | 5,000 | 0 | 1,300 | 1,300 |
| Legendary | `wpn_staff_legendary` | Thyrsus Arcanus | 8,500 | 0 | 2,000 | 2,200 |
| Mythic | `wpn_staff_mythic` | Nexus Infinitus | 14,000 | 0 | 3,500 | 3,800 |

---

### 3.2 CHEST ARMOR (Zırhlar) — Slot: `chest`

#### Tip A: Plate (Plaka Zırh)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `chest_plate_common` | Lorica Ferrea | 0 | 800 | 1,600 | 0 |
| Uncommon | `chest_plate_uncommon` | Thorax Aeratus | 0 | 1,800 | 3,600 | 0 |
| Rare | `chest_plate_rare` | Lorica Argentea | 0 | 3,500 | 6,400 | 0 |
| Epic | `chest_plate_epic` | Thorax Draconis | 0 | 6,000 | 10,400 | 0 |
| Legendary | `chest_plate_legendary` | Aegis Imperialis | 0 | 10,000 | 16,000 | 0 |
| Mythic | `chest_plate_mythic` | Lorica Caelestis | 0 | 17,000 | 28,000 | 0 |

#### Tip B: Chainmail (Zincir Zırh)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `chest_chain_common` | Hamata Simplex | 0 | 600 | 1,800 | 0 |
| Uncommon | `chest_chain_uncommon` | Hamata Fortis | 0 | 1,500 | 4,000 | 0 |
| Rare | `chest_chain_rare` | Hamata Lunaris | 0 | 3,000 | 7,200 | 0 |
| Epic | `chest_chain_epic` | Hamata Tempestatis | 0 | 5,200 | 11,700 | 0 |
| Legendary | `chest_chain_legendary` | Hamata Invicta | 0 | 8,800 | 18,000 | 0 |
| Mythic | `chest_chain_mythic` | Hamata Aeterna | 0 | 14,800 | 31,500 | 0 |

#### Tip C: Leather (Deri Zırh)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `chest_leather_common` | Corium Rusticum | 0 | 500 | 1,400 | 200 |
| Uncommon | `chest_leather_uncommon` | Corium Silvaticum | 0 | 1,200 | 3,200 | 500 |
| Rare | `chest_leather_rare` | Corium Umbrae | 0 | 2,500 | 5,800 | 1,000 |
| Epic | `chest_leather_epic` | Corium Draconis | 0 | 4,400 | 9,400 | 1,800 |
| Legendary | `chest_leather_legendary` | Corium Phoenicis | 0 | 7,500 | 14,500 | 3,000 |
| Mythic | `chest_leather_mythic` | Corium Primordiale | 0 | 12,500 | 25,000 | 5,000 |

#### Tip D: Robe (Cüppe)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `chest_robe_common` | Tunica Texta | 0 | 300 | 2,000 | 100 |
| Uncommon | `chest_robe_uncommon` | Stola Mystica | 0 | 1,000 | 4,500 | 300 |
| Rare | `chest_robe_rare` | Palla Arcana | 0 | 2,200 | 8,000 | 700 |
| Epic | `chest_robe_epic` | Toga Elementalis | 0 | 4,000 | 13,000 | 1,200 |
| Legendary | `chest_robe_legendary` | Vestis Astralis | 0 | 7,000 | 20,000 | 2,000 |
| Mythic | `chest_robe_mythic` | Amictus Divinus | 0 | 11,000 | 35,000 | 3,500 |

---

### 3.3 HEAD (Kafalık) — Slot: `head`

#### Tip A: Helm (Miğfer)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_helm_common` | Galea Ferrea | 400 | 500 | 500 | 100 |
| Uncommon | `head_helm_uncommon` | Galea Aerata | 900 | 1,000 | 1,200 | 200 |
| Rare | `head_helm_rare` | Galea Argentea | 1,700 | 2,000 | 2,200 | 400 |
| Epic | `head_helm_epic` | Galea Draconis | 3,000 | 3,500 | 3,600 | 700 |
| Legendary | `head_helm_legendary` | Galea Imperialis | 5,200 | 5,800 | 5,600 | 1,200 |
| Mythic | `head_helm_mythic` | Galea Caelestis | 8,800 | 9,500 | 9,500 | 2,000 |

#### Tip B: Hood (Kapüşon)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_hood_common` | Cucullus Simplex | 300 | 400 | 600 | 200 |
| Uncommon | `head_hood_uncommon` | Cucullus Silvanus | 700 | 800 | 1,400 | 500 |
| Rare | `head_hood_rare` | Cucullus Umbrae | 1,400 | 1,600 | 2,600 | 1,000 |
| Epic | `head_hood_epic` | Cucullus Noctis | 2,500 | 2,800 | 4,200 | 1,800 |
| Legendary | `head_hood_legendary` | Cucullus Phantasma | 4,200 | 4,800 | 6,500 | 3,000 |
| Mythic | `head_hood_mythic` | Cucullus Abyssi | 7,000 | 8,000 | 10,800 | 5,000 |

#### Tip C: Crown (Taç)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_crown_common` | Corona Cuprea | 500 | 300 | 400 | 100 |
| Uncommon | `head_crown_uncommon` | Corona Argentea | 1,000 | 800 | 1,000 | 300 |
| Rare | `head_crown_rare` | Corona Aurea | 2,000 | 1,600 | 1,800 | 600 |
| Epic | `head_crown_epic` | Corona Tempestatis | 3,500 | 2,800 | 3,000 | 1,000 |
| Legendary | `head_crown_legendary` | Corona Regalis | 6,000 | 4,800 | 4,800 | 1,700 |
| Mythic | `head_crown_mythic` | Corona Omnipotentis | 10,000 | 8,000 | 8,000 | 2,800 |

#### Tip D: Circlet (Taçlık)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_circlet_common` | Circulus Simplex | 300 | 300 | 700 | 200 |
| Uncommon | `head_circlet_uncommon` | Circulus Lunaris | 700 | 700 | 1,600 | 400 |
| Rare | `head_circlet_rare` | Circulus Stellaris | 1,400 | 1,400 | 2,900 | 800 |
| Epic | `head_circlet_epic` | Circulus Elementalis | 2,400 | 2,400 | 4,800 | 1,400 |
| Legendary | `head_circlet_legendary` | Circulus Aeternus | 4,200 | 4,200 | 7,500 | 2,300 |
| Mythic | `head_circlet_mythic` | Circulus Infinitus | 7,000 | 7,000 | 12,500 | 3,800 |

---

### 3.4 LEGS (Ayaklık) — Slot: `legs`

#### Tip A: Greaves (Dizlik)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_greaves_common` | Ocreae Ferreae | 0 | 700 | 1,200 | 100 |
| Uncommon | `legs_greaves_uncommon` | Ocreae Aeratae | 0 | 1,500 | 2,700 | 200 |
| Rare | `legs_greaves_rare` | Ocreae Argenteae | 0 | 2,800 | 4,800 | 400 |
| Epic | `legs_greaves_epic` | Ocreae Draconis | 0 | 4,800 | 7,800 | 700 |
| Legendary | `legs_greaves_legendary` | Ocreae Imperiales | 0 | 8,000 | 12,000 | 1,200 |
| Mythic | `legs_greaves_mythic` | Ocreae Caelestes | 0 | 13,600 | 21,000 | 2,000 |

#### Tip B: Leggings (Pantolon)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_leggings_common` | Bracae Rusticae | 0 | 500 | 1,400 | 100 |
| Uncommon | `legs_leggings_uncommon` | Bracae Silvaticae | 0 | 1,200 | 3,200 | 300 |
| Rare | `legs_leggings_rare` | Bracae Umbrae | 0 | 2,400 | 5,600 | 600 |
| Epic | `legs_leggings_epic` | Bracae Tempestatis | 0 | 4,200 | 9,100 | 1,000 |
| Legendary | `legs_leggings_legendary` | Bracae Invictae | 0 | 7,000 | 14,000 | 1,700 |
| Mythic | `legs_leggings_mythic` | Bracae Primordiales | 0 | 11,800 | 24,500 | 2,800 |

#### Tip C: Tassets (Bel Zırhı)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_tassets_common` | Cingulum Ferreum | 0 | 600 | 1,000 | 200 |
| Uncommon | `legs_tassets_uncommon` | Cingulum Fortis | 0 | 1,400 | 2,400 | 500 |
| Rare | `legs_tassets_rare` | Cingulum Lunare | 0 | 2,600 | 4,200 | 1,000 |
| Epic | `legs_tassets_epic` | Cingulum Volcanum | 0 | 4,600 | 6,800 | 1,800 |
| Legendary | `legs_tassets_legendary` | Cingulum Titanis | 0 | 7,600 | 10,500 | 3,000 |
| Mythic | `legs_tassets_mythic` | Cingulum Aeternum | 0 | 12,800 | 18,000 | 5,000 |

#### Tip D: Battle Skirt (Savaş Eteği)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_pteruges_common` | Pteruges Simplex | 0 | 400 | 1,600 | 100 |
| Uncommon | `legs_pteruges_uncommon` | Pteruges Militaris | 0 | 1,000 | 3,600 | 300 |
| Rare | `legs_pteruges_rare` | Pteruges Arcana | 0 | 2,000 | 6,500 | 600 |
| Epic | `legs_pteruges_epic` | Pteruges Noctis | 0 | 3,600 | 10,500 | 1,000 |
| Legendary | `legs_pteruges_legendary` | Pteruges Heroica | 0 | 6,000 | 16,500 | 1,700 |
| Mythic | `legs_pteruges_mythic` | Pteruges Divina | 0 | 10,000 | 28,000 | 2,800 |

---

### 3.5 BOOTS (Botlar) — Slot: `boots`

#### Tip A: Sabatons (Çelik Bot)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_sabaton_common` | Caligae Ferreae | 0 | 400 | 300 | 200 |
| Uncommon | `boots_sabaton_uncommon` | Caligae Aeratae | 0 | 800 | 700 | 500 |
| Rare | `boots_sabaton_rare` | Caligae Argenteae | 0 | 1,600 | 1,300 | 1,000 |
| Epic | `boots_sabaton_epic` | Caligae Draconis | 0 | 2,800 | 2,100 | 1,800 |
| Legendary | `boots_sabaton_legendary` | Caligae Imperiales | 0 | 4,600 | 3,300 | 3,000 |
| Mythic | `boots_sabaton_mythic` | Caligae Caelestes | 0 | 7,800 | 5,600 | 5,000 |

#### Tip B: Treads (İz Botu)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_treads_common` | Solea Rustica | 0 | 300 | 400 | 200 |
| Uncommon | `boots_treads_uncommon` | Solea Silvatica | 0 | 600 | 900 | 500 |
| Rare | `boots_treads_rare` | Solea Umbrae | 0 | 1,200 | 1,600 | 1,000 |
| Epic | `boots_treads_epic` | Solea Tempestatis | 0 | 2,200 | 2,600 | 1,800 |
| Legendary | `boots_treads_legendary` | Solea Velocis | 0 | 3,600 | 4,000 | 3,000 |
| Mythic | `boots_treads_mythic` | Solea Infinita | 0 | 6,000 | 7,000 | 5,000 |

#### Tip C: Sandals (Sandalet)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_sandals_common` | Sandalia Texta | 0 | 200 | 400 | 200 |
| Uncommon | `boots_sandals_uncommon` | Sandalia Mystica | 0 | 400 | 900 | 500 |
| Rare | `boots_sandals_rare` | Sandalia Lunaris | 0 | 800 | 1,600 | 1,000 |
| Epic | `boots_sandals_epic` | Sandalia Elementalis | 0 | 1,400 | 2,600 | 1,800 |
| Legendary | `boots_sandals_legendary` | Sandalia Astralis | 0 | 2,400 | 4,000 | 3,000 |
| Mythic | `boots_sandals_mythic` | Sandalia Divina | 0 | 4,000 | 7,000 | 5,000 |

#### Tip D: Moccasins (Mokasen)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_moccasins_common` | Pero Simplex | 0 | 200 | 200 | 200 |
| Uncommon | `boots_moccasins_uncommon` | Pero Silvanus | 0 | 500 | 600 | 500 |
| Rare | `boots_moccasins_rare` | Pero Noctis | 0 | 1,000 | 1,000 | 1,000 |
| Epic | `boots_moccasins_epic` | Pero Venatoris | 0 | 1,800 | 1,600 | 1,800 |
| Legendary | `boots_moccasins_legendary` | Pero Phantasma | 0 | 3,000 | 2,600 | 3,000 |
| Mythic | `boots_moccasins_mythic` | Pero Abyssi | 0 | 5,000 | 4,400 | 5,000 |

---

### 3.6 GLOVES (Eldivenler) — Slot: `gloves`

#### Tip A: Gauntlets (Yumruk Zırhı)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_gauntlet_common` | Manicae Ferreae | 600 | 100 | 0 | 200 |
| Uncommon | `gloves_gauntlet_uncommon` | Manicae Aeratae | 1,300 | 200 | 0 | 400 |
| Rare | `gloves_gauntlet_rare` | Manicae Argenteae | 2,500 | 400 | 0 | 800 |
| Epic | `gloves_gauntlet_epic` | Manicae Draconis | 4,400 | 700 | 0 | 1,400 |
| Legendary | `gloves_gauntlet_legendary` | Manicae Imperiales | 7,500 | 1,200 | 0 | 2,300 |
| Mythic | `gloves_gauntlet_mythic` | Manicae Caelestes | 12,600 | 2,000 | 0 | 3,800 |

#### Tip B: Bracers (Kolluk)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_bracers_common` | Armillae Rusticae | 500 | 100 | 0 | 200 |
| Uncommon | `gloves_bracers_uncommon` | Armillae Fortis | 1,100 | 200 | 0 | 500 |
| Rare | `gloves_bracers_rare` | Armillae Lunaris | 2,100 | 400 | 0 | 1,000 |
| Epic | `gloves_bracers_epic` | Armillae Tempestatis | 3,700 | 700 | 0 | 1,800 |
| Legendary | `gloves_bracers_legendary` | Armillae Invictae | 6,300 | 1,200 | 0 | 3,000 |
| Mythic | `gloves_bracers_mythic` | Armillae Primordiales | 10,500 | 2,000 | 0 | 5,000 |

#### Tip C: Wraps (Sargı)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_wraps_common` | Fascia Texta | 400 | 100 | 0 | 200 |
| Uncommon | `gloves_wraps_uncommon` | Fascia Herbalis | 900 | 200 | 0 | 500 |
| Rare | `gloves_wraps_rare` | Fascia Arcana | 1,800 | 400 | 0 | 1,000 |
| Epic | `gloves_wraps_epic` | Fascia Elementalis | 3,200 | 600 | 0 | 1,800 |
| Legendary | `gloves_wraps_legendary` | Fascia Astralis | 5,400 | 1,000 | 0 | 3,000 |
| Mythic | `gloves_wraps_mythic` | Fascia Aeterna | 9,000 | 1,700 | 0 | 5,000 |

#### Tip D: Mitts (Parmaklık)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_mitts_common` | Digitale Simplex | 500 | 100 | 0 | 200 |
| Uncommon | `gloves_mitts_uncommon` | Digitale Silvanum | 1,000 | 200 | 0 | 500 |
| Rare | `gloves_mitts_rare` | Digitale Umbrae | 2,000 | 400 | 0 | 1,000 |
| Epic | `gloves_mitts_epic` | Digitale Noctis | 3,500 | 600 | 0 | 1,800 |
| Legendary | `gloves_mitts_legendary` | Digitale Phantasma | 6,000 | 1,000 | 0 | 3,000 |
| Mythic | `gloves_mitts_mythic` | Digitale Abyssi | 10,000 | 1,700 | 0 | 5,000 |

---

### 3.7 RING (Yüzükler) — Slot: `ring`

#### Tip A: Signet (Mühür Yüzüğü)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `ring_signet_common` | Sigillum Cupreum | 200 | 200 | 400 | 200 |
| Uncommon | `ring_signet_uncommon` | Sigillum Argenteum | 500 | 500 | 1,000 | 400 |
| Rare | `ring_signet_rare` | Sigillum Aureum | 1,000 | 1,000 | 1,800 | 800 |
| Epic | `ring_signet_epic` | Sigillum Draconis | 1,800 | 1,800 | 3,000 | 1,400 |
| Legendary | `ring_signet_legendary` | Sigillum Regale | 3,000 | 3,000 | 4,600 | 2,400 |
| Mythic | `ring_signet_mythic` | Sigillum Omnipotentis | 5,000 | 5,000 | 8,000 | 4,000 |

#### Tip B: Band (Bant)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `ring_band_common` | Anulus Simplex | 200 | 300 | 500 | 100 |
| Uncommon | `ring_band_uncommon` | Anulus Fortis | 400 | 600 | 1,200 | 300 |
| Rare | `ring_band_rare` | Anulus Lunaris | 800 | 1,200 | 2,200 | 600 |
| Epic | `ring_band_epic` | Anulus Tempestatis | 1,400 | 2,200 | 3,600 | 1,000 |
| Legendary | `ring_band_legendary` | Anulus Aeternus | 2,400 | 3,600 | 5,500 | 1,700 |
| Mythic | `ring_band_mythic` | Anulus Infinitus | 4,000 | 6,000 | 9,500 | 2,800 |

#### Tip C: Loop (Halka)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `ring_loop_common` | Circulus Minor | 100 | 100 | 300 | 200 |
| Uncommon | `ring_loop_uncommon` | Circulus Herbalis | 300 | 300 | 800 | 500 |
| Rare | `ring_loop_rare` | Circulus Arcanus | 600 | 600 | 1,400 | 1,000 |
| Epic | `ring_loop_epic` | Circulus Elementalis | 1,000 | 1,000 | 2,400 | 1,800 |
| Legendary | `ring_loop_legendary` | Circulus Stellaris | 1,800 | 1,800 | 3,700 | 3,000 |
| Mythic | `ring_loop_mythic` | Circulus Cosmicus | 3,000 | 3,000 | 6,300 | 5,000 |

#### Tip D: Seal (Damga)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `ring_seal_common` | Obsignatum Ferreum | 300 | 100 | 300 | 200 |
| Uncommon | `ring_seal_uncommon` | Obsignatum Silvanum | 600 | 300 | 800 | 400 |
| Rare | `ring_seal_rare` | Obsignatum Umbrae | 1,200 | 600 | 1,400 | 800 |
| Epic | `ring_seal_epic` | Obsignatum Noctis | 2,200 | 1,000 | 2,400 | 1,400 |
| Legendary | `ring_seal_legendary` | Obsignatum Heroicum | 3,600 | 1,800 | 3,700 | 2,400 |
| Mythic | `ring_seal_mythic` | Obsignatum Divinum | 6,000 | 3,000 | 6,300 | 4,000 |

---

### 3.8 NECKLACE (Kolyeler) — Slot: `necklace`

#### Tip A: Pendant (Kolye Ucu)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_pendant_common` | Pendulus Cupreus | 100 | 200 | 1,800 | 100 |
| Uncommon | `neck_pendant_uncommon` | Pendulus Argenteus | 200 | 400 | 4,000 | 300 |
| Rare | `neck_pendant_rare` | Pendulus Aureus | 400 | 800 | 7,200 | 600 |
| Epic | `neck_pendant_epic` | Pendulus Draconis | 700 | 1,400 | 11,700 | 1,000 |
| Legendary | `neck_pendant_legendary` | Pendulus Imperialis | 1,200 | 2,400 | 18,000 | 1,700 |
| Mythic | `neck_pendant_mythic` | Pendulus Caelestis | 2,000 | 4,000 | 31,500 | 2,800 |

#### Tip B: Amulet (Muska)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_amulet_common` | Amuletum Simplex | 100 | 100 | 1,600 | 200 |
| Uncommon | `neck_amulet_uncommon` | Amuletum Silvanum | 200 | 300 | 3,600 | 400 |
| Rare | `neck_amulet_rare` | Amuletum Lunare | 400 | 600 | 6,500 | 800 |
| Epic | `neck_amulet_epic` | Amuletum Elementale | 700 | 1,000 | 10,500 | 1,400 |
| Legendary | `neck_amulet_legendary` | Amuletum Aeternum | 1,200 | 1,800 | 16,200 | 2,300 |
| Mythic | `neck_amulet_mythic` | Amuletum Primordiale | 2,000 | 3,000 | 28,000 | 3,800 |

#### Tip C: Choker (Gerdanlık)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_choker_common` | Torques Simplex | 100 | 200 | 1,400 | 200 |
| Uncommon | `neck_choker_uncommon` | Torques Fortis | 200 | 400 | 3,200 | 500 |
| Rare | `neck_choker_rare` | Torques Arcanus | 400 | 800 | 5,800 | 1,000 |
| Epic | `neck_choker_epic` | Torques Tempestatis | 700 | 1,400 | 9,400 | 1,800 |
| Legendary | `neck_choker_legendary` | Torques Invictus | 1,200 | 2,400 | 14,500 | 3,000 |
| Mythic | `neck_choker_mythic` | Torques Omnipotens | 2,000 | 4,000 | 25,000 | 5,000 |

#### Tip D: Talisman (Tılsım)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_talisman_common` | Talisman Rusticum | 100 | 100 | 2,000 | 100 |
| Uncommon | `neck_talisman_uncommon` | Talisman Herbale | 200 | 300 | 4,500 | 300 |
| Rare | `neck_talisman_rare` | Talisman Noctis | 400 | 600 | 8,000 | 600 |
| Epic | `neck_talisman_epic` | Talisman Volcanum | 700 | 1,000 | 13,000 | 1,000 |
| Legendary | `neck_talisman_legendary` | Talisman Phoenicis | 1,200 | 1,800 | 20,000 | 1,700 |
| Mythic | `neck_talisman_mythic` | Talisman Cosmicum | 2,000 | 3,000 | 35,000 | 2,800 |

---

## 4. Ek Item Kategorileri (Ekipman Dışı)

### 4.1 İksirler (Potions)

| Item ID | İsim | Tip | Etki |
|---------|------|-----|------|
| `potion_health_minor` | Elixir Vitae Minor | health | +5,000 HP |
| `potion_health_major` | Elixir Vitae Major | health | +20,000 HP |
| `potion_health_supreme` | Elixir Vitae Suprema | health | +50,000 HP |
| `potion_energy_minor` | Essentia Vigoris Minor | energy | +10 energia |
| `potion_energy_major` | Essentia Vigoris Major | energy | +25 energia |
| `potion_energy_supreme` | Essentia Vigoris Suprema | energy | +50 energia |
| `potion_attack_buff` | Furor Bellicum | buff | +20% attack 30 dk |
| `potion_defense_buff` | Scutum Magicum | buff | +20% defense 30 dk |
| `potion_luck_buff` | Fortuna Aurea | buff | +30% luck 30 dk |
| `potion_xp_buff` | Sapientia Accelerata | buff | +50% XP 60 dk |

### 4.2 Scroll'lar (Enhancement için)

| Item ID | İsim | Kullanım |
|---------|------|----------|
| `scroll_upgrade_low` | Liber Ascensionis Minor | Common/Uncommon enhancement |
| `scroll_upgrade_middle` | Liber Ascensionis Medius | Rare/Epic enhancement |
| `scroll_upgrade_high` | Liber Ascensionis Major | Legendary/Mythic enhancement |

### 4.3 Özel Katalizörler (Crafting için)

| Item ID | İsim | Kullanım | Nereden Düşer |
|---------|------|----------|---------------|
| `catalyst_common` | Petra Catalytica | Common crafting | Zone 1 zindan |
| `catalyst_uncommon` | Elementum Activum | Uncommon crafting | Zone 2 zindan |
| `catalyst_rare` | Nucleus Alchemicus | Rare crafting | Zone 3 zindan |
| `catalyst_epic` | Cor Transmutationis | Epic crafting | Zone 4 zindan |
| `catalyst_legendary` | Essentia Creationis | Legendary crafting | Zone 5-6 zindan |
| `catalyst_mythic` | Primordium Absolutum | Mythic crafting | Zone 7 (Mitik) zindan |

---

## 5. Veritabanı Şeması

### 5.1 `items` Tablosu (Catalog)

```sql
CREATE TABLE IF NOT EXISTS public.items (
  id TEXT PRIMARY KEY,                    -- wpn_sword_common
  name TEXT NOT NULL,                     -- Gladius Ferreus
  description TEXT DEFAULT '',
  icon TEXT DEFAULT 'default_item',
  item_type TEXT NOT NULL,                -- weapon, armor, potion, material, scroll, catalyst
  rarity TEXT NOT NULL DEFAULT 'common',  -- common..mythic
  equip_slot TEXT DEFAULT 'none',         -- weapon, chest, head, legs, boots, gloves, ring, necklace, none
  weapon_type TEXT DEFAULT 'none',        -- sword, dagger, axe, staff, none
  armor_type TEXT DEFAULT 'none',         -- plate, chain, leather, robe, none
  sub_type TEXT DEFAULT '',               -- signet, band, loop, seal, pendant, amulet, choker, talisman
  
  -- Combat Stats
  attack INTEGER DEFAULT 0,
  defense INTEGER DEFAULT 0,
  health INTEGER DEFAULT 0,
  power INTEGER DEFAULT 0,
  luck INTEGER DEFAULT 0,
  
  -- Requirements
  required_level INTEGER DEFAULT 1,
  
  -- Enhancement
  can_enhance BOOLEAN DEFAULT false,
  max_enhancement INTEGER DEFAULT 10,
  
  -- Economy
  base_price INTEGER DEFAULT 0,
  vendor_sell_price INTEGER DEFAULT 0,
  
  -- Stacking
  is_stackable BOOLEAN DEFAULT false,
  max_stack INTEGER DEFAULT 1,
  
  -- Trade
  is_tradeable BOOLEAN DEFAULT true,
  
  -- Potion fields
  potion_type TEXT DEFAULT 'none',
  energy_restore INTEGER DEFAULT 0,
  health_restore INTEGER DEFAULT 0,
  buff_type TEXT DEFAULT '',
  buff_value NUMERIC DEFAULT 0,
  buff_duration INTEGER DEFAULT 0,
  
  -- Material fields  
  material_type TEXT DEFAULT '',
  facility_source TEXT DEFAULT '',
  
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### 5.2 TypeScript Interface Güncellemesi

Mevcut `src/types/item.ts` üzerine eklenecek:

```typescript
export type SubType =
  // Weapon subtypes
  | "dagger" | "sword" | "axe" | "staff"
  // Chest subtypes
  | "plate" | "chain" | "leather" | "robe"
  // Head subtypes
  | "helm" | "hood" | "crown" | "circlet"
  // Legs subtypes
  | "greaves" | "leggings" | "tassets" | "pteruges"
  // Boots subtypes
  | "sabaton" | "treads" | "sandals" | "moccasins"
  // Gloves subtypes
  | "gauntlet" | "bracers" | "wraps" | "mitts"
  // Ring subtypes
  | "signet" | "band" | "loop" | "seal"
  // Necklace subtypes
  | "pendant" | "amulet" | "choker" | "talisman"
  | "none";
```

---

## 6. Güç Referans Tablosu (Tam Set Toplam Power)

Bir oyuncunun tam set giydiğinde (8 parça, +0, aynı nadirlik) yaklaşık toplam power'ı:

| Rarity | Tam Set Power (approx) | Zindan Erişimi |
|--------|----------------------|----------------|
| Common | 8,000–12,000 | Zone 1 (1-10) rahat |
| Uncommon | 20,000–32,000 | Zone 2 (11-20) rahat |
| Rare | 45,000–68,000 | Zone 3 (21-30) rahat |
| Epic | 80,000–120,000 | Zone 4 (31-40) rahat |
| Legendary | 140,000–200,000 | Zone 5 (41-50) rahat |
| Mythic | 240,000–350,000 | Zone 6-7 (51-65) rahat |

> **Örnek End-Game Karakter (Level 70):**
> Full Mythic +10 Set Power: ~380,000 (ekipman) + 35,000 (level) + 35,600 (saygınlık) ≈ **~450,000**

Enhancement ile (tam +10): Power × 2.5

---

## 7. Uygulama Öncelikleri

1. **Faz 1:** Veritabanında `items` catalog'unu oluştur (192 ekipman + iksir + scroll + catalyst)
2. **Faz 2:** `ItemData` TypeScript interface güncellemelerini yap
3. **Faz 3:** Seed script ile tüm 192 ekipmanı DB'ye ekle
4. **Faz 4:** Envanter UI'ını yeni item'larla test et
5. **Faz 5:** Crafting/Enhancement entegrasyonları

---

*Bu belge `PLAN_02_FACILITIES_RESOURCES.md`, `PLAN_03_CRAFTING_SYSTEM.md` ve `PLAN_04_DUNGEON_SYSTEM.md` ile birlikte kullanılmalıdır.*
