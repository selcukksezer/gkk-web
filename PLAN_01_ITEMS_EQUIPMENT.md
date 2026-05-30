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
| Uncommon | `chest_plate_uncommon` | Iron Chestplate | 0 | 1,800 | 3,600 | 0 |
| Rare | `chest_plate_rare` | Steel Cuirass | 0 | 3,500 | 6,400 | 0 |
| Epic | `chest_plate_epic` | Mithril Carapace | 0 | 6,000 | 10,400 | 0 |
| Legendary | `chest_plate_legendary` | Obsidian Armor | 0 | 10,000 | 16,000 | 0 |
| Mythic | `chest_plate_mythic` | Aether Bulwark | 0 | 17,000 | 28,000 | 0 |

#### Tip B: Chainmail (Zincir Zırh)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `chest_chain_common` | Trainee Hauberk | 0 | 600 | 1,800 | 0 |
| Uncommon | `chest_chain_uncommon` | Scaled Chainmail | 0 | 1,500 | 4,000 | 0 |
| Rare | `chest_chain_rare` | Veteran Mail | 0 | 3,000 | 7,200 | 0 |
| Epic | `chest_chain_epic` | Vanguard Chain | 0 | 5,200 | 11,700 | 0 |
| Legendary | `chest_chain_legendary` | Wyrm Flight Mail | 0 | 8,800 | 18,000 | 0 |
| Mythic | `chest_chain_mythic` | Phantom Hauberk | 0 | 14,800 | 31,500 | 0 |

#### Tip C: Leather (Deri Zırh)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `chest_leather_common` | Scout Tunic | 0 | 500 | 1,400 | 200 |
| Uncommon | `chest_leather_uncommon` | Tracker Vest | 0 | 1,200 | 3,200 | 500 |
| Rare | `chest_leather_rare` | Hunter Garb | 0 | 2,500 | 5,800 | 1,000 |
| Epic | `chest_leather_epic` | Ranger Brigandine | 0 | 4,400 | 9,400 | 1,800 |
| Legendary | `chest_leather_legendary` | Pathfinder Jacket | 0 | 7,500 | 14,500 | 3,000 |
| Mythic | `chest_leather_mythic` | Apex Tunic | 0 | 12,500 | 25,000 | 5,000 |

#### Tip D: Robe (Cüppe)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `chest_robe_common` | Cotton Mantle | 0 | 300 | 2,000 | 100 |
| Uncommon | `chest_robe_uncommon` | Linen Robe | 0 | 1,000 | 4,500 | 300 |
| Rare | `chest_robe_rare` | Crimson Cassock | 0 | 2,200 | 8,000 | 700 |
| Epic | `chest_robe_epic` | Arcane Drapery | 0 | 4,000 | 13,000 | 1,200 |
| Legendary | `chest_robe_legendary` | Rune Thread Robe | 0 | 7,000 | 20,000 | 2,000 |
| Mythic | `chest_robe_mythic` | Eternity Gown | 0 | 11,000 | 35,000 | 3,500 |

---

### 3.3 HEAD (Kafalık) — Slot: `head`

#### Tip A: Helm (Miğfer)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_helm_common` | Bronze Cap | 400 | 500 | 500 | 100 |
| Uncommon | `head_helm_uncommon` | Iron Helm | 900 | 1,000 | 1,200 | 200 |
| Rare | `head_helm_rare` | Steel Bascinet | 1,700 | 2,000 | 2,200 | 400 |
| Epic | `head_helm_epic` | Mithril Casque | 3,000 | 3,500 | 3,600 | 700 |
| Legendary | `head_helm_legendary` | Obsidian Visor | 5,200 | 5,800 | 5,600 | 1,200 |
| Mythic | `head_helm_mythic` | Aether Greathelm | 8,800 | 9,500 | 9,500 | 2,000 |

#### Tip B: Hood (Kapüşon)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_hood_common` | Ragged Hood | 300 | 400 | 600 | 200 |
| Uncommon | `head_hood_uncommon` | Nomad Cowl | 700 | 800 | 1,400 | 500 |
| Rare | `head_hood_rare` | Shadow Mask | 1,400 | 1,600 | 2,600 | 1,000 |
| Epic | `head_hood_epic` | Assassin Veil | 2,500 | 2,800 | 4,200 | 1,800 |
| Legendary | `head_hood_legendary` | Nightcaster Hood | 4,200 | 4,800 | 6,500 | 3,000 |
| Mythic | `head_hood_mythic` | Void Cowl | 7,000 | 8,000 | 10,800 | 5,000 |

#### Tip C: Crown (Taç)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_crown_common` | Worn Tiara | 500 | 300 | 400 | 100 |
| Uncommon | `head_crown_uncommon` | Silver Coronet | 1,000 | 800 | 1,000 | 300 |
| Rare | `head_crown_rare` | Golden Crown | 2,000 | 1,600 | 1,800 | 600 |
| Epic | `head_crown_epic` | Ruby Diadem | 3,500 | 2,800 | 3,000 | 1,000 |
| Legendary | `head_crown_legendary` | Emerald Crest | 6,000 | 4,800 | 4,800 | 1,700 |
| Mythic | `head_crown_mythic` | Diamond Tiara | 10,000 | 8,000 | 8,000 | 2,800 |

#### Tip D: Circlet (Taçlık)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `head_circlet_common` | Novice Ribbon | 300 | 300 | 700 | 200 |
| Uncommon | `head_circlet_uncommon` | Adept Band | 700 | 700 | 1,600 | 400 |
| Rare | `head_circlet_rare` | Mystic Circlet | 1,400 | 1,400 | 2,900 | 800 |
| Epic | `head_circlet_epic` | Sage Halo | 2,400 | 2,400 | 4,800 | 1,400 |
| Legendary | `head_circlet_legendary` | Oracle Wreath | 4,200 | 4,200 | 7,500 | 2,300 |
| Mythic | `head_circlet_mythic` | Luminescent Circlet | 7,000 | 7,000 | 12,500 | 3,800 |

---

### 3.4 LEGS (Ayaklık) — Slot: `legs`

#### Tip A: Greaves (Dizlik)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_greaves_common` | Bronze Greaves | 0 | 700 | 1,200 | 100 |
| Uncommon | `legs_greaves_uncommon` | Iron Chausses | 0 | 1,500 | 2,700 | 200 |
| Rare | `legs_greaves_rare` | Steel Legguards | 0 | 2,800 | 4,800 | 400 |
| Epic | `legs_greaves_epic` | Mithril Kneeguards | 0 | 4,800 | 7,800 | 700 |
| Legendary | `legs_greaves_legendary` | Obsidian Plates | 0 | 8,000 | 12,000 | 1,200 |
| Mythic | `legs_greaves_mythic` | Aether Greaves | 0 | 13,600 | 21,000 | 2,000 |

#### Tip B: Leggings (Pantolon)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_leggings_common` | Padded Pants | 0 | 500 | 1,400 | 100 |
| Uncommon | `legs_leggings_uncommon` | Leather Leggings | 0 | 1,200 | 3,200 | 300 |
| Rare | `legs_leggings_rare` | Reinforced Slacks | 0 | 2,400 | 5,600 | 600 |
| Epic | `legs_leggings_epic` | Marauder Breeches | 0 | 4,200 | 9,100 | 1,000 |
| Legendary | `legs_leggings_legendary` | Apex Trousers | 0 | 7,000 | 14,000 | 1,700 |
| Mythic | `legs_leggings_mythic` | Phantom Leggings | 0 | 11,800 | 24,500 | 2,800 |

#### Tip C: Tassets (Bel Zırhı)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_tassets_common` | Outlaw Skirt | 0 | 600 | 1,000 | 200 |
| Uncommon | `legs_tassets_uncommon` | Mercenary Tassets | 0 | 1,400 | 2,400 | 500 |
| Rare | `legs_tassets_rare` | Warlord Kilt | 0 | 2,600 | 4,200 | 1,000 |
| Epic | `legs_tassets_epic` | Conqueror Tassets | 0 | 4,600 | 6,800 | 1,800 |
| Legendary | `legs_tassets_legendary` | Vanguard Faulds | 0 | 7,600 | 10,500 | 3,000 |
| Mythic | `legs_tassets_mythic` | Sovereign Tassets | 0 | 12,800 | 18,000 | 5,000 |

#### Tip D: Battle Skirt (Savaş Eteği)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `legs_pteruges_common` | Initiate Pteruges | 0 | 400 | 1,600 | 100 |
| Uncommon | `legs_pteruges_uncommon` | Acolyte Bottoms | 0 | 1,000 | 3,600 | 300 |
| Rare | `legs_pteruges_rare` | Disciple Pteruges | 0 | 2,000 | 6,500 | 600 |
| Epic | `legs_pteruges_epic` | Enlightened Wrap | 0 | 3,600 | 10,500 | 1,000 |
| Legendary | `legs_pteruges_legendary` | Archmage Skirt | 0 | 6,000 | 16,500 | 1,700 |
| Mythic | `legs_pteruges_mythic` | Celestial Kilt | 0 | 10,000 | 28,000 | 2,800 |

---

### 3.5 BOOTS (Botlar) — Slot: `boots`

#### Tip A: Sabatons (Çelik Bot)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_sabaton_common` | Bronze Sabatons | 0 | 400 | 300 | 200 |
| Uncommon | `boots_sabaton_uncommon` | Iron Sollerets | 0 | 800 | 700 | 500 |
| Rare | `boots_sabaton_rare` | Steel Stompers | 0 | 1,600 | 1,300 | 1,000 |
| Epic | `boots_sabaton_epic` | Mithril Sabatons | 0 | 2,800 | 2,100 | 1,800 |
| Legendary | `boots_sabaton_legendary` | Obsidian Treads | 0 | 4,600 | 3,300 | 3,000 |
| Mythic | `boots_sabaton_mythic` | Aether Sabatons | 0 | 7,800 | 5,600 | 5,000 |

#### Tip B: Treads (İz Botu)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_treads_common` | Rough Treads | 0 | 300 | 400 | 200 |
| Uncommon | `boots_treads_uncommon` | Spiked Treads | 0 | 600 | 900 | 500 |
| Rare | `boots_treads_rare` | Vanguard Treads | 0 | 1,200 | 1,600 | 1,000 |
| Epic | `boots_treads_epic` | Commando Boots | 0 | 2,200 | 2,600 | 1,800 |
| Legendary | `boots_treads_legendary` | Phantom Treads | 0 | 3,600 | 4,000 | 3,000 |
| Mythic | `boots_treads_mythic` | Shadow Stalkers | 0 | 6,000 | 7,000 | 5,000 |

#### Tip C: Sandals (Sandalet)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_sandals_common` | Wanderer Sandals | 0 | 200 | 400 | 200 |
| Uncommon | `boots_sandals_uncommon` | Pilgrim Sandals | 0 | 400 | 900 | 500 |
| Rare | `boots_sandals_rare` | Mystic Sandals | 0 | 800 | 1,600 | 1,000 |
| Epic | `boots_sandals_epic` | Ascetic Footwear | 0 | 1,400 | 2,600 | 1,800 |
| Legendary | `boots_sandals_legendary` | Prophet Sandals | 0 | 2,400 | 4,000 | 3,000 |
| Mythic | `boots_sandals_mythic` | Aura Sandals | 0 | 4,000 | 7,000 | 5,000 |

#### Tip D: Moccasins (Mokasen)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `boots_moccasins_common` | Fur Moccasins | 0 | 200 | 200 | 200 |
| Uncommon | `boots_moccasins_uncommon` | Scout Moccasins | 0 | 500 | 600 | 500 |
| Rare | `boots_moccasins_rare` | Stalker Shoes | 0 | 1,000 | 1,000 | 1,000 |
| Epic | `boots_moccasins_epic` | Ranger Moccasins | 0 | 1,800 | 1,600 | 1,800 |
| Legendary | `boots_moccasins_legendary` | Apex Paws | 0 | 3,000 | 2,600 | 3,000 |
| Mythic | `boots_moccasins_mythic` | Silent Steppers | 0 | 5,000 | 4,400 | 5,000 |

---

### 3.6 GLOVES (Eldivenler) — Slot: `gloves`

#### Tip A: Gauntlets (Yumruk Zırhı)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_gauntlet_common` | Bronze Gauntlets | 600 | 100 | 0 | 200 |
| Uncommon | `gloves_gauntlet_uncommon` | Iron Handguards | 1,300 | 200 | 0 | 400 |
| Rare | `gloves_gauntlet_rare` | Steel Fists | 2,500 | 400 | 0 | 800 |
| Epic | `gloves_gauntlet_epic` | Mithril Crushers | 4,400 | 700 | 0 | 1,400 |
| Legendary | `gloves_gauntlet_legendary` | Obsidian Gauntlets | 7,500 | 1,200 | 0 | 2,300 |
| Mythic | `gloves_gauntlet_mythic` | Aether Grips | 12,600 | 2,000 | 0 | 3,800 |

#### Tip B: Bracers (Kolluk)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_bracers_common` | Leather Bracers | 500 | 100 | 0 | 200 |
| Uncommon | `gloves_bracers_uncommon` | Studded Bracers | 1,100 | 200 | 0 | 500 |
| Rare | `gloves_bracers_rare` | Combat Bracers | 2,100 | 400 | 0 | 1,000 |
| Epic | `gloves_bracers_epic` | Vanguard Bracers | 3,700 | 700 | 0 | 1,800 |
| Legendary | `gloves_bracers_legendary` | Dragonscale Bracers | 6,300 | 1,200 | 0 | 3,000 |
| Mythic | `gloves_bracers_mythic` | Phantom Bracers | 10,500 | 2,000 | 0 | 5,000 |

#### Tip C: Wraps (Sargı)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_wraps_common` | Cloth Wraps | 400 | 100 | 0 | 200 |
| Uncommon | `gloves_wraps_uncommon` | Brawler Wraps | 900 | 200 | 0 | 500 |
| Rare | `gloves_wraps_rare` | Shadow Wraps | 1,800 | 400 | 0 | 1,000 |
| Epic | `gloves_wraps_epic` | Assassin Bands | 3,200 | 600 | 0 | 1,800 |
| Legendary | `gloves_wraps_legendary` | Nightfall Wraps | 5,400 | 1,000 | 0 | 3,000 |
| Mythic | `gloves_wraps_mythic` | Void Wraps | 9,000 | 1,700 | 0 | 5,000 |

#### Tip D: Mitts (Parmaklık)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `gloves_mitts_common` | Wool Mitts | 500 | 100 | 0 | 200 |
| Uncommon | `gloves_mitts_uncommon` | Padded Mitts | 1,000 | 200 | 0 | 500 |
| Rare | `gloves_mitts_rare` | Arcane Mitts | 2,000 | 400 | 0 | 1,000 |
| Epic | `gloves_mitts_epic` | Spellcaster Gloves | 3,500 | 600 | 0 | 1,800 |
| Legendary | `gloves_mitts_legendary` | Rune Mitts | 6,000 | 1,000 | 0 | 3,000 |
| Mythic | `gloves_mitts_mythic` | Celestial Gloves | 10,000 | 1,700 | 0 | 5,000 |

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
| Common | `ring_band_common` | Iron Band | 200 | 300 | 500 | 100 |
| Uncommon | `ring_band_uncommon` | Steel Band | 400 | 600 | 1,200 | 300 |
| Rare | `ring_band_rare` | Cobalt Band | 800 | 1,200 | 2,200 | 600 |
| Epic | `ring_band_epic` | Onyx Band | 1,400 | 2,200 | 3,600 | 1,000 |
| Legendary | `ring_band_legendary` | Sapphire Band | 2,400 | 3,600 | 5,500 | 1,700 |
| Mythic | `ring_band_mythic` | Prismatic Band | 4,000 | 6,000 | 9,500 | 2,800 |

#### Tip C: Loop (Halka)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `ring_loop_common` | Tin Loop | 100 | 100 | 300 | 200 |
| Uncommon | `ring_loop_uncommon` | Brass Loop | 300 | 300 | 800 | 500 |
| Rare | `ring_loop_rare` | Bronze Loop | 600 | 600 | 1,400 | 1,000 |
| Epic | `ring_loop_epic` | Jade Loop | 1,000 | 1,000 | 2,400 | 1,800 |
| Legendary | `ring_loop_legendary` | Topaz Loop | 1,800 | 1,800 | 3,700 | 3,000 |
| Mythic | `ring_loop_mythic` | Aether Loop | 3,000 | 3,000 | 6,300 | 5,000 |

#### Tip D: Seal (Damga)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `ring_seal_common` | Clay Seal | 300 | 100 | 300 | 200 |
| Uncommon | `ring_seal_uncommon` | Quartz Seal | 600 | 300 | 800 | 400 |
| Rare | `ring_seal_rare` | Amethyst Seal | 1,200 | 600 | 1,400 | 800 |
| Epic | `ring_seal_epic` | Garnet Seal | 2,200 | 1,000 | 2,400 | 1,400 |
| Legendary | `ring_seal_legendary` | Pearl Seal | 3,600 | 1,800 | 3,700 | 2,400 |
| Mythic | `ring_seal_mythic` | Void Seal | 6,000 | 3,000 | 6,300 | 4,000 |

---

### 3.8 NECKLACE (Kolyeler) — Slot: `necklace`

#### Tip A: Pendant (Kolye Ucu)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_pendant_common` | Copper Pendant | 100 | 200 | 1,800 | 100 |
| Uncommon | `neck_pendant_uncommon` | Silver Pendant | 200 | 400 | 4,000 | 300 |
| Rare | `neck_pendant_rare` | Gold Pendant | 400 | 800 | 7,200 | 600 |
| Epic | `neck_pendant_epic` | Ruby Pendant | 700 | 1,400 | 11,700 | 1,000 |
| Legendary | `neck_pendant_legendary` | Emerald Pendant | 1,200 | 2,400 | 18,000 | 1,700 |
| Mythic | `neck_pendant_mythic` | Diamond Pendant | 2,000 | 4,000 | 31,500 | 2,800 |

#### Tip B: Amulet (Muska)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_amulet_common` | Bone Amulet | 100 | 100 | 1,600 | 200 |
| Uncommon | `neck_amulet_uncommon` | Ivory Amulet | 200 | 300 | 3,600 | 400 |
| Rare | `neck_amulet_rare` | Coral Amulet | 400 | 600 | 6,500 | 800 |
| Epic | `neck_amulet_epic` | Obsidian Amulet | 700 | 1,000 | 10,500 | 1,400 |
| Legendary | `neck_amulet_legendary` | Sapphire Amulet | 1,200 | 1,800 | 16,200 | 2,300 |
| Mythic | `neck_amulet_mythic` | Prismatic Amulet | 2,000 | 3,000 | 28,000 | 3,800 |

#### Tip C: Choker (Gerdanlık)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_choker_common` | Leather Choker | 100 | 200 | 1,400 | 200 |
| Uncommon | `neck_choker_uncommon` | Velvet Choker | 200 | 400 | 3,200 | 500 |
| Rare | `neck_choker_rare` | Silk Choker | 400 | 800 | 5,800 | 1,000 |
| Epic | `neck_choker_epic` | Spiked Choker | 700 | 1,400 | 9,400 | 1,800 |
| Legendary | `neck_choker_legendary` | Jeweled Choker | 1,200 | 2,400 | 14,500 | 3,000 |
| Mythic | `neck_choker_mythic` | Aether Choker | 2,000 | 4,000 | 25,000 | 5,000 |

#### Tip D: Talisman (Tılsım)

| Rarity | Item ID | İsim | Attack | Defense | HP | Luck |
|--------|---------|------|--------|---------|-----|------|
| Common | `neck_talisman_common` | Wood Talisman | 100 | 100 | 2,000 | 100 |
| Uncommon | `neck_talisman_uncommon` | Stone Talisman | 200 | 300 | 4,500 | 300 |
| Rare | `neck_talisman_rare` | Iron Talisman | 400 | 600 | 8,000 | 600 |
| Epic | `neck_talisman_epic` | Jade Talisman | 700 | 1,000 | 13,000 | 1,000 |
| Legendary | `neck_talisman_legendary` | Dragon Talisman | 1,200 | 1,800 | 20,000 | 1,700 |
| Mythic | `neck_talisman_mythic` | Void Talisman | 2,000 | 3,000 | 35,000 | 2,800 |

---

## 4. Ek Item Kategorileri (Ekipman Dışı)

### 4.1 İksirler (Potions)

| Item ID | İsim | Tip | Etki |
|---------|------|-----|------|
| `potion_health_minor` | Minor Healing Draught | health | +5,000 HP |
| `potion_health_major` | Major Healing Potion | health | +20,000 HP |
| `potion_health_supreme` | Supreme Health Flask | health | +50,000 HP |
| `potion_energy_minor` | Minor Energy Vial | energy | +10 energia |
| `potion_energy_major` | Major Energy Potion | energy | +25 energia |
| `potion_energy_supreme` | Supreme Energy Flask | energy | +50 energia |
| `potion_attack_buff` | Vial of Warlust | buff | +20% attack 30 dk |
| `potion_defense_buff` | Flask of Iron Skin | buff | +20% defense 30 dk |
| `potion_luck_buff` | Draught of Golden Fortune | buff | +30% luck 30 dk |
| `potion_xp_buff` | Elixir of Rapid Wisdom | buff | +50% XP 60 dk |

### 4.2 Scroll'lar (Enhancement için)

| Item ID | İsim | Kullanım |
|---------|------|----------|
| `scroll_upgrade_low` | Lesser Upgrade Scroll | Common/Uncommon enhancement |
| `scroll_upgrade_middle` | Standard Upgrade Scroll | Rare/Epic enhancement |
| `scroll_upgrade_high` | Greater Upgrade Scroll | Legendary/Mythic enhancement |

### 4.3 Özel Katalizörler (Crafting için)

| Item ID | İsim | Kullanım | Nereden Düşer |
|---------|------|----------|---------------|
| `catalyst_common` | Common Catalyst Crystal | Common crafting | Zone 1 zindan |
| `catalyst_uncommon` | Uncommon Reactant | Uncommon crafting | Zone 2 zindan |
| `catalyst_rare` | Rare Alchemical Core | Rare crafting | Zone 3 zindan |
| `catalyst_epic` | Epic Transmutation Heart | Epic crafting | Zone 4 zindan |
| `catalyst_legendary` | Legendary Creation Essence | Legendary crafting | Zone 5-6 zindan |
| `catalyst_mythic` | Mythic Primordial Spark | Mythic crafting | Zone 7 (Mitik) zindan |

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
