# PLAN 01 — Item & Ekipman Sistemi

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-07 
> **Bağımlılıklar:** Tesis sistemi (kaynak üretimi), Crafting sistemi (üretim), Enhancement sistemi (+0/+10), PLAN_11 (Karakter Sınıfı — luck stat)

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
| Common | `wpn_dagger_common` | Rookie Piercer | 800 | 0 | 0 | 100 |
| Uncommon | `wpn_dagger_uncommon` | Shadow Shiv | 1,600 | 0 | 0 | 400 |
| Rare | `wpn_dagger_rare` | Bone Slicer | 3,300 | 0 | 0 | 800 |
| Epic | `wpn_dagger_epic` | Phantom Edge | 5,800 | 0 | 0 | 1,500 |
| Legendary | `wpn_dagger_legendary` | Obsidian Skewer | 10,000 | 0 | 0 | 2,500 |
| Mythic | `wpn_dagger_mythic` | Twilight Fang | 16,500 | 0 | 0 | 4,200 |

#### Tip B: Sword (Kılıç)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `wpn_sword_common` | Militia Sword | 1,000 | 0 | 0 | 100 |
| Uncommon | `wpn_sword_uncommon` | Mercenary Broadsword | 2,000 | 0 | 0 | 300 |
| Rare | `wpn_sword_rare` | Giant Chopper | 4,000 | 0 | 0 | 600 |
| Epic | `wpn_sword_epic` | War Blade | 7,000 | 0 | 0 | 1,200 |
| Legendary | `wpn_sword_legendary` | Illusion Sabre | 12,000 | 0 | 0 | 2,000 |
| Mythic | `wpn_sword_mythic` | Imperial Halberd | 20,000 | 0 | 0 | 3,500 |

#### Tip C: Axe (Balta)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `wpn_axe_common` | Forester Axe | 900 | 0 | 0 | 200 |
| Uncommon | `wpn_axe_uncommon` | Savage Tomahawk | 1,800 | 0 | 0 | 500 |
| Rare | `wpn_axe_rare` | Battle Bardiche | 3,600 | 0 | 0 | 1,000 |
| Epic | `wpn_axe_epic` | Tribal Maul | 6,300 | 0 | 0 | 1,800 |
| Legendary | `wpn_axe_legendary` | Crimson Scar | 10,800 | 0 | 0 | 3,000 |
| Mythic | `wpn_axe_mythic` | Executioner Axe | 18,000 | 0 | 0 | 5,000 |

#### Tip D: Staff (Asa)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `wpn_staff_common` | Oak Staff | 700 | 0 | 200 | 100 |
| Uncommon | `wpn_staff_uncommon` | Apprentice Branch | 1,400 | 0 | 500 | 300 |
| Rare | `wpn_staff_rare` | Serpent Staff | 2,800 | 0 | 800 | 700 |
| Epic | `wpn_staff_epic` | Ember Wand | 5,000 | 0 | 1,300 | 1,300 |
| Legendary | `wpn_staff_legendary` | Alchemists Rod | 8,500 | 0 | 2,000 | 2,200 |
| Mythic | `wpn_staff_mythic` | Demon Blood | 14,000 | 0 | 3,500 | 3,800 |

---

### 3.2 CHEST ARMOR (Zırhlar) — Slot: `chest`

#### Tip A: Plate (Plaka Zırh)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `chest_plate_common` | Bronze Pauldron | 0 | 800 | 1,600 | 0 |
| Uncommon | `chest_plate_uncommon` | Iron Pauldron | 0 | 1,800 | 3,600 | 0 |
| Rare | `chest_plate_rare` | Heavy Plate Pauldron | 0 | 3,500 | 6,400 | 0 |
| Epic | `chest_plate_epic` | Dragon Scale Pauldron | 0 | 6,000 | 10,400 | 0 |
| Legendary | `chest_plate_legendary` | Titan Guard Pauldron | 0 | 10,000 | 16,000 | 0 |
| Mythic | `chest_plate_mythic` | Celestial Pauldron | 0 | 17,000 | 28,000 | 0 |

#### Tip B: Chainmail (Zincir Zırh)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `chest_chain_common` | Trainee Mantle | 0 | 600 | 1,800 | 0 |
| Uncommon | `chest_chain_uncommon` | Scaled Leather Mantle | 0 | 1,500 | 4,000 | 0 |
| Rare | `chest_chain_rare` | Carapace Mantle | 0 | 3,000 | 7,200 | 0 |
| Epic | `chest_chain_epic` | Shadow Scale Mantle | 0 | 5,200 | 11,700 | 0 |
| Legendary | `chest_chain_legendary` | Wyrm Flight Mantle | 0 | 8,800 | 18,000 | 0 |
| Mythic | `chest_chain_mythic` | Phantom Mantle | 0 | 14,800 | 31,500 | 0 |

#### Tip C: Leather (Deri Zırh)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `chest_leather_common` | Scout Garb | 0 | 500 | 1,400 | 200 |
| Uncommon | `chest_leather_uncommon` | Tracker Garb | 0 | 1,200 | 3,200 | 500 |
| Rare | `chest_leather_rare` | Hunter Garb | 0 | 2,500 | 5,800 | 1,000 |
| Epic | `chest_leather_epic` | Ranger Garb | 0 | 4,400 | 9,400 | 1,800 |
| Legendary | `chest_leather_legendary` | Pathfinder Garb | 0 | 7,500 | 14,500 | 3,000 |
| Mythic | `chest_leather_mythic` | Apex Garb | 0 | 12,500 | 25,000 | 5,000 |

#### Tip D: Robe (Cüppe)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `chest_robe_common` | Cotton Robe | 0 | 300 | 2,000 | 100 |
| Uncommon | `chest_robe_uncommon` | Linen Robe | 0 | 1,000 | 4,500 | 300 |
| Rare | `chest_robe_rare` | Crimson Robe Robe | 0 | 2,200 | 8,000 | 700 |
| Epic | `chest_robe_epic` | Arcane Weave Robe | 0 | 4,000 | 13,000 | 1,200 |
| Legendary | `chest_robe_legendary` | Rune Thread Robe | 0 | 7,000 | 20,000 | 2,000 |
| Mythic | `chest_robe_mythic` | Eternity Robe | 0 | 11,000 | 35,000 | 3,500 |

---

### 3.3 HEAD (Kafalık) — Slot: `head`

#### Tip A: Helm (Miğfer)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_helm_common` | Copper Cap | 400 | 500 | 500 | 100 |
| Uncommon | `head_helm_uncommon` | Iron Cap | 900 | 1,000 | 1,200 | 200 |
| Rare | `head_helm_rare` | Steel Cap | 1,700 | 2,000 | 2,200 | 400 |
| Epic | `head_helm_epic` | Mithril Cap | 3,000 | 3,500 | 3,600 | 700 |
| Legendary | `head_helm_legendary` | Obsidian Cap | 5,200 | 5,800 | 5,600 | 1,200 |
| Mythic | `head_helm_mythic` | Aether Cap | 8,800 | 9,500 | 9,500 | 2,000 |

#### Tip B: Hood (Kapüşon)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_hood_common` | Copper Cap | 300 | 400 | 600 | 200 |
| Uncommon | `head_hood_uncommon` | Iron Cap | 700 | 800 | 1,400 | 500 |
| Rare | `head_hood_rare` | Steel Cap | 1,400 | 1,600 | 2,600 | 1,000 |
| Epic | `head_hood_epic` | Mithril Cap | 2,500 | 2,800 | 4,200 | 1,800 |
| Legendary | `head_hood_legendary` | Obsidian Cap | 4,200 | 4,800 | 6,500 | 3,000 |
| Mythic | `head_hood_mythic` | Aether Cap | 7,000 | 8,000 | 10,800 | 5,000 |

#### Tip C: Crown (Taç)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_crown_common` | Copper Crown | 500 | 300 | 400 | 100 |
| Uncommon | `head_crown_uncommon` | Iron Crown | 1,000 | 800 | 1,000 | 300 |
| Rare | `head_crown_rare` | Steel Crown | 2,000 | 1,600 | 1,800 | 600 |
| Epic | `head_crown_epic` | Mithril Crown | 3,500 | 2,800 | 3,000 | 1,000 |
| Legendary | `head_crown_legendary` | Obsidian Crown | 6,000 | 4,800 | 4,800 | 1,700 |
| Mythic | `head_crown_mythic` | Aether Crown | 10,000 | 8,000 | 8,000 | 2,800 |

#### Tip D: Circlet (Taçlık)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_circlet_common` | Copper Circlet | 300 | 300 | 700 | 200 |
| Uncommon | `head_circlet_uncommon` | Iron Circlet | 700 | 700 | 1,600 | 400 |
| Rare | `head_circlet_rare` | Steel Circlet | 1,400 | 1,400 | 2,900 | 800 |
| Epic | `head_circlet_epic` | Mithril Circlet | 2,400 | 2,400 | 4,800 | 1,400 |
| Legendary | `head_circlet_legendary` | Obsidian Circlet | 4,200 | 4,200 | 7,500 | 2,300 |
| Mythic | `head_circlet_mythic` | Aether Circlet | 7,000 | 7,000 | 12,500 | 3,800 |

---

### 3.4 LEGS (Ayaklık) — Slot: `legs`

#### Tip A: Greaves (Dizlik)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_greaves_common` | Trainee Greaves | 0 | 700 | 1,200 | 100 |
| Uncommon | `legs_greaves_uncommon` | Soldier Greaves | 0 | 1,500 | 2,700 | 200 |
| Rare | `legs_greaves_rare` | Knight Greaves | 0 | 2,800 | 4,800 | 400 |
| Epic | `legs_greaves_epic` | Commander Greaves | 0 | 4,800 | 7,800 | 700 |
| Legendary | `legs_greaves_legendary` | Lord Greaves | 0 | 8,000 | 12,000 | 1,200 |
| Mythic | `legs_greaves_mythic` | King Greaves | 0 | 13,600 | 21,000 | 2,000 |

#### Tip B: Leggings (Pantolon)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_leggings_common` | Trainee Greaves | 0 | 500 | 1,400 | 100 |
| Uncommon | `legs_leggings_uncommon` | Soldier Greaves | 0 | 1,200 | 3,200 | 300 |
| Rare | `legs_leggings_rare` | Knight Greaves | 0 | 2,400 | 5,600 | 600 |
| Epic | `legs_leggings_epic` | Commander Greaves | 0 | 4,200 | 9,100 | 1,000 |
| Legendary | `legs_leggings_legendary` | Lord Greaves | 0 | 7,000 | 14,000 | 1,700 |
| Mythic | `legs_leggings_mythic` | King Greaves | 0 | 11,800 | 24,500 | 2,800 |

#### Tip C: Tassets (Bel Zırhı)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_tassets_common` | Trainee Greaves | 0 | 600 | 1,000 | 200 |
| Uncommon | `legs_tassets_uncommon` | Soldier Greaves | 0 | 1,400 | 2,400 | 500 |
| Rare | `legs_tassets_rare` | Knight Greaves | 0 | 2,600 | 4,200 | 1,000 |
| Epic | `legs_tassets_epic` | Commander Greaves | 0 | 4,600 | 6,800 | 1,800 |
| Legendary | `legs_tassets_legendary` | Lord Greaves | 0 | 7,600 | 10,500 | 3,000 |
| Mythic | `legs_tassets_mythic` | King Greaves | 0 | 12,800 | 18,000 | 5,000 |

#### Tip D: Battle Skirt (Savaş Eteği)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_pteruges_common` | Trainee Greaves | 0 | 400 | 1,600 | 100 |
| Uncommon | `legs_pteruges_uncommon` | Soldier Greaves | 0 | 1,000 | 3,600 | 300 |
| Rare | `legs_pteruges_rare` | Knight Greaves | 0 | 2,000 | 6,500 | 600 |
| Epic | `legs_pteruges_epic` | Commander Greaves | 0 | 3,600 | 10,500 | 1,000 |
| Legendary | `legs_pteruges_legendary` | Lord Greaves | 0 | 6,000 | 16,500 | 1,700 |
| Mythic | `legs_pteruges_mythic` | King Greaves | 0 | 10,000 | 28,000 | 2,800 |

---

### 3.5 BOOTS (Botlar) — Slot: `boots`

#### Tip A: Sabatons (Çelik Bot)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_sabaton_common` | Trainee Boots | 0 | 400 | 300 | 200 |
| Uncommon | `boots_sabaton_uncommon` | Soldier Boots | 0 | 800 | 700 | 500 |
| Rare | `boots_sabaton_rare` | Knight Boots | 0 | 1,600 | 1,300 | 1,000 |
| Epic | `boots_sabaton_epic` | Commander Boots | 0 | 2,800 | 2,100 | 1,800 |
| Legendary | `boots_sabaton_legendary` | Lord Boots | 0 | 4,600 | 3,300 | 3,000 |
| Mythic | `boots_sabaton_mythic` | King Boots | 0 | 7,800 | 5,600 | 5,000 |

#### Tip B: Treads (İz Botu)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_treads_common` | Trainee Boots | 0 | 300 | 400 | 200 |
| Uncommon | `boots_treads_uncommon` | Soldier Boots | 0 | 600 | 900 | 500 |
| Rare | `boots_treads_rare` | Knight Boots | 0 | 1,200 | 1,600 | 1,000 |
| Epic | `boots_treads_epic` | Commander Boots | 0 | 2,200 | 2,600 | 1,800 |
| Legendary | `boots_treads_legendary` | Lord Boots | 0 | 3,600 | 4,000 | 3,000 |
| Mythic | `boots_treads_mythic` | King Boots | 0 | 6,000 | 7,000 | 5,000 |

#### Tip C: Sandals (Sandalet)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_sandals_common` | Trainee Boots | 0 | 200 | 400 | 200 |
| Uncommon | `boots_sandals_uncommon` | Soldier Boots | 0 | 400 | 900 | 500 |
| Rare | `boots_sandals_rare` | Knight Boots | 0 | 800 | 1,600 | 1,000 |
| Epic | `boots_sandals_epic` | Commander Boots | 0 | 1,400 | 2,600 | 1,800 |
| Legendary | `boots_sandals_legendary` | Lord Boots | 0 | 2,400 | 4,000 | 3,000 |
| Mythic | `boots_sandals_mythic` | King Boots | 0 | 4,000 | 7,000 | 5,000 |

#### Tip D: Moccasins (Mokasen)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_moccasins_common` | Trainee Boots | 0 | 200 | 200 | 200 |
| Uncommon | `boots_moccasins_uncommon` | Soldier Boots | 0 | 500 | 600 | 500 |
| Rare | `boots_moccasins_rare` | Knight Boots | 0 | 1,000 | 1,000 | 1,000 |
| Epic | `boots_moccasins_epic` | Commander Boots | 0 | 1,800 | 1,600 | 1,800 |
| Legendary | `boots_moccasins_legendary` | Lord Boots | 0 | 3,000 | 2,600 | 3,000 |
| Mythic | `boots_moccasins_mythic` | King Boots | 0 | 5,000 | 4,400 | 5,000 |

---

### 3.6 GLOVES (Eldivenler) — Slot: `gloves`

#### Tip A: Gauntlets (Yumruk Zırhı)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_gauntlet_common` | Trainee Gauntlets | 600 | 100 | 0 | 200 |
| Uncommon | `gloves_gauntlet_uncommon` | Soldier Gauntlets | 1,300 | 200 | 0 | 400 |
| Rare | `gloves_gauntlet_rare` | Knight Gauntlets | 2,500 | 400 | 0 | 800 |
| Epic | `gloves_gauntlet_epic` | Commander Gauntlets | 4,400 | 700 | 0 | 1,400 |
| Legendary | `gloves_gauntlet_legendary` | Lord Gauntlets | 7,500 | 1,200 | 0 | 2,300 |
| Mythic | `gloves_gauntlet_mythic` | King Gauntlets | 12,600 | 2,000 | 0 | 3,800 |

#### Tip B: Bracers (Kolluk)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_bracers_common` | Trainee Gauntlets | 500 | 100 | 0 | 200 |
| Uncommon | `gloves_bracers_uncommon` | Soldier Gauntlets | 1,100 | 200 | 0 | 500 |
| Rare | `gloves_bracers_rare` | Knight Gauntlets | 2,100 | 400 | 0 | 1,000 |
| Epic | `gloves_bracers_epic` | Commander Gauntlets | 3,700 | 700 | 0 | 1,800 |
| Legendary | `gloves_bracers_legendary` | Lord Gauntlets | 6,300 | 1,200 | 0 | 3,000 |
| Mythic | `gloves_bracers_mythic` | King Gauntlets | 10,500 | 2,000 | 0 | 5,000 |

#### Tip C: Wraps (Sargı)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_wraps_common` | Trainee Gauntlets | 400 | 100 | 0 | 200 |
| Uncommon | `gloves_wraps_uncommon` | Soldier Gauntlets | 900 | 200 | 0 | 500 |
| Rare | `gloves_wraps_rare` | Knight Gauntlets | 1,800 | 400 | 0 | 1,000 |
| Epic | `gloves_wraps_epic` | Commander Gauntlets | 3,200 | 600 | 0 | 1,800 |
| Legendary | `gloves_wraps_legendary` | Lord Gauntlets | 5,400 | 1,000 | 0 | 3,000 |
| Mythic | `gloves_wraps_mythic` | King Gauntlets | 9,000 | 1,700 | 0 | 5,000 |

#### Tip D: Mitts (Parmaklık)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_mitts_common` | Trainee Gauntlets | 500 | 100 | 0 | 200 |
| Uncommon | `gloves_mitts_uncommon` | Soldier Gauntlets | 1,000 | 200 | 0 | 500 |
| Rare | `gloves_mitts_rare` | Knight Gauntlets | 2,000 | 400 | 0 | 1,000 |
| Epic | `gloves_mitts_epic` | Commander Gauntlets | 3,500 | 600 | 0 | 1,800 |
| Legendary | `gloves_mitts_legendary` | Lord Gauntlets | 6,000 | 1,000 | 0 | 3,000 |
| Mythic | `gloves_mitts_mythic` | King Gauntlets | 10,000 | 1,700 | 0 | 5,000 |

---

### 3.7 RING (Yüzükler) — Slot: `ring`

#### Tip A: Signet (Mühür Yüzüğü)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `ring_signet_common` | Copper Signet | 200 | 200 | 400 | 200 |
| Uncommon | `ring_signet_uncommon` | Silver Signet | 500 | 500 | 1,000 | 400 |
| Rare | `ring_signet_rare` | Gold Signet | 1,000 | 1,000 | 1,800 | 800 |
| Epic | `ring_signet_epic` | Ruby Signet | 1,800 | 1,800 | 3,000 | 1,400 |
| Legendary | `ring_signet_legendary` | Emerald Signet | 3,000 | 3,000 | 4,600 | 2,400 |
| Mythic | `ring_signet_mythic` | Diamond Signet | 5,000 | 5,000 | 8,000 | 4,000 |

#### Tip B: Band (Bant)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `ring_band_common` | Copper Band | 200 | 300 | 500 | 100 |
| Uncommon | `ring_band_uncommon` | Silver Band | 400 | 600 | 1,200 | 300 |
| Rare | `ring_band_rare` | Gold Band | 800 | 1,200 | 2,200 | 600 |
| Epic | `ring_band_epic` | Ruby Band | 1,400 | 2,200 | 3,600 | 1,000 |
| Legendary | `ring_band_legendary` | Emerald Band | 2,400 | 3,600 | 5,500 | 1,700 |
| Mythic | `ring_band_mythic` | Diamond Band | 4,000 | 6,000 | 9,500 | 2,800 |

#### Tip C: Loop (Halka)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `ring_loop_common` | Copper Loop | 100 | 100 | 300 | 200 |
| Uncommon | `ring_loop_uncommon` | Silver Loop | 300 | 300 | 800 | 500 |
| Rare | `ring_loop_rare` | Gold Loop | 600 | 600 | 1,400 | 1,000 |
| Epic | `ring_loop_epic` | Ruby Loop | 1,000 | 1,000 | 2,400 | 1,800 |
| Legendary | `ring_loop_legendary` | Emerald Loop | 1,800 | 1,800 | 3,700 | 3,000 |
| Mythic | `ring_loop_mythic` | Diamond Loop | 3,000 | 3,000 | 6,300 | 5,000 |

#### Tip D: Seal (Damga)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `ring_seal_common` | Copper Seal | 300 | 100 | 300 | 200 |
| Uncommon | `ring_seal_uncommon` | Silver Seal | 600 | 300 | 800 | 400 |
| Rare | `ring_seal_rare` | Gold Seal | 1,200 | 600 | 1,400 | 800 |
| Epic | `ring_seal_epic` | Ruby Seal | 2,200 | 1,000 | 2,400 | 1,400 |
| Legendary | `ring_seal_legendary` | Emerald Seal | 3,600 | 1,800 | 3,700 | 2,400 |
| Mythic | `ring_seal_mythic` | Diamond Seal | 6,000 | 3,000 | 6,300 | 4,000 |

---

### 3.8 NECKLACE (Kolyeler) — Slot: `necklace`

#### Tip A: Pendant (Kolye Ucu)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_pendant_common` | Copper Pendant | 100 | 200 | 1,800 | 100 |
| Uncommon | `neck_pendant_uncommon` | Silver Pendant | 200 | 400 | 4,000 | 300 |
| Rare | `neck_pendant_rare` | Gold Pendant | 400 | 800 | 7,200 | 600 |
| Epic | `neck_pendant_epic` | Sapphire Pendant | 700 | 1,400 | 11,700 | 1,000 |
| Legendary | `neck_pendant_legendary` | Opal Pendant | 1,200 | 2,400 | 18,000 | 1,700 |
| Mythic | `neck_pendant_mythic` | Abyssal Pendant | 2,000 | 4,000 | 31,500 | 2,800 |

#### Tip B: Amulet (Muska)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_amulet_common` | Copper Amulet | 100 | 100 | 1,600 | 200 |
| Uncommon | `neck_amulet_uncommon` | Silver Amulet | 200 | 300 | 3,600 | 400 |
| Rare | `neck_amulet_rare` | Gold Amulet | 400 | 600 | 6,500 | 800 |
| Epic | `neck_amulet_epic` | Sapphire Amulet | 700 | 1,000 | 10,500 | 1,400 |
| Legendary | `neck_amulet_legendary` | Opal Amulet | 1,200 | 1,800 | 16,200 | 2,300 |
| Mythic | `neck_amulet_mythic` | Abyssal Amulet | 2,000 | 3,000 | 28,000 | 3,800 |

#### Tip C: Choker (Gerdanlık)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_choker_common` | Copper Choker | 100 | 200 | 1,400 | 200 |
| Uncommon | `neck_choker_uncommon` | Silver Choker | 200 | 400 | 3,200 | 500 |
| Rare | `neck_choker_rare` | Gold Choker | 400 | 800 | 5,800 | 1,000 |
| Epic | `neck_choker_epic` | Sapphire Choker | 700 | 1,400 | 9,400 | 1,800 |
| Legendary | `neck_choker_legendary` | Opal Choker | 1,200 | 2,400 | 14,500 | 3,000 |
| Mythic | `neck_choker_mythic` | Abyssal Choker | 2,000 | 4,000 | 25,000 | 5,000 |

#### Tip D: Talisman (Tılsım)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_talisman_common` | Copper Talisman | 100 | 100 | 2,000 | 100 |
| Uncommon | `neck_talisman_uncommon` | Silver Talisman | 200 | 300 | 4,500 | 300 |
| Rare | `neck_talisman_rare` | Gold Talisman | 400 | 600 | 8,000 | 600 |
| Epic | `neck_talisman_epic` | Sapphire Talisman | 700 | 1,000 | 13,000 | 1,000 |
| Legendary | `neck_talisman_legendary` | Opal Talisman | 1,200 | 1,800 | 20,000 | 1,700 |
| Mythic | `neck_talisman_mythic` | Abyssal Talisman | 2,000 | 3,000 | 35,000 | 2,800 |

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
  is_han_only BOOLEAN DEFAULT false,          -- Han/Mekan-only item mi? (PLAN_07)
  is_market_tradeable BOOLEAN DEFAULT true,   -- Market'te trade edilebilir mi?
  is_direct_tradeable BOOLEAN DEFAULT true,   -- Direkt oyuncuya trade edilebilir mi?
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

*Bu belge `PLAN_02_FACILITIES_RESOURCES.md`, `PLAN_03_CRAFTING_SYSTEM.md`, `PLAN_04_DUNGEON_SYSTEM.md`, `PLAN_07_MEKAN_SYSTEM.md` (Han-only itemlar için `is_han_only` alanı) ve `PLAN_11_CHARACTER_CLASS_SYSTEM.md` (luck stat, karakter sınıfı bağlamı) ile birlikte kullanılmalıdır.*
