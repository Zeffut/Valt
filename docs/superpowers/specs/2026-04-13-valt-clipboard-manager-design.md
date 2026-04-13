# Valt — Clipboard Manager macOS (MVP Design)

**Date:** 2026-04-13  
**Status:** Approved  
**Stack:** Swift + SwiftUI/AppKit, Core Data, macOS 15 Sequoia+, distribution directe (hors App Store)

---

## Vue d'ensemble

Valt est un gestionnaire de presse-papier pour macOS qui reproduit fidèlement les fonctionnalités core de l'app Paste. L'app tourne en background (pas d'icône Dock), accessible via un raccourci clavier global (⌘⇧V par défaut) qui fait apparaître un panneau flottant en bas d'écran.

---

## Architecture générale

Approche SwiftUI-first avec AppKit pour le panneau flottant. Quatre couches :

```
┌─────────────────────────────────────────────┐
│  UI Layer (SwiftUI)                         │
│  PastePanel · ShelfView · PinboardView      │
│  ClipCell · SearchBar · PreviewView         │
├─────────────────────────────────────────────┤
│  App Layer (Swift / @Observable)            │
│  ClipboardMonitor · HotkeyManager           │
│  PasteboardService · SearchService          │
├─────────────────────────────────────────────┤
│  Data Layer (Core Data)                     │
│  ClipItem · Pinboard · PersistenceController│
├─────────────────────────────────────────────┤
│  System Layer (AppKit / macOS APIs)         │
│  NSPanel · NSPasteboard · NSEvent (hotkey)  │
│  CGEventTap (coller via simulated keypress) │
└─────────────────────────────────────────────┘
```

---

## Interface utilisateur

Le panneau principal (`PastePanel`) est un `NSPanel` qui apparaît en bas de l'écran sur toute la largeur, avec un fond flouté (vibrancy/dark). Il se ferme avec Échap ou en cliquant en dehors.

**Layout horizontal en deux zones :**

```
┌─────────────────────────────────────────────────────────────────┐
│  [Recherche]                                          [⚙️ Prefs] │
├──────────────────────────────┬──────────────────────────────────┤
│                              │                                  │
│   HISTORIQUE (scroll horiz.) │   PINBOARDS (tabs + scroll)      │
│   ← [img][txt][url][code] →  │   [Pin 1] [Pin 2] [Pin 3] ...   │
│                              │   ← [item][item][item] →        │
│                              │                                  │
└──────────────────────────────┴──────────────────────────────────┘
```

**Cellules (`ClipCellView`) :**
- Thumbnail/preview adapté au type : texte tronqué, aperçu image, favicon pour URL, syntax highlight basique pour code
- Icône de l'app source + timestamp relatif

**Interactions :**
- Clic simple → colle dans l'app précédente + ferme le panneau
- Double-clic → copie sans coller
- Échap → ferme le panneau sans action

**Recherche :** filtre en temps réel sur le contenu textuel, debounce 150ms.

---

## Modèle de données (Core Data)

### Entité `ClipItem`
| Attribut | Type | Description |
|---|---|---|
| `id` | UUID | Identifiant unique |
| `content` | Data | Contenu brut (texte, image, fichier) |
| `type` | String | `"text"`, `"image"`, `"url"`, `"file"` |
| `plainText` | String? | Version texte pour recherche/indexation |
| `sourceApp` | String? | Bundle ID de l'app source |
| `sourceAppName` | String? | Nom lisible de l'app source |
| `createdAt` | Date | Date de capture |
| `pinboard` | Pinboard? | Relation vers un pinboard (optionnel) |

### Entité `Pinboard`
| Attribut | Type | Description |
|---|---|---|
| `id` | UUID | Identifiant unique |
| `name` | String | Nom affiché |
| `position` | Int16 | Ordre d'affichage |
| `items` | [ClipItem] | Relation inverse |

### Règles métier
- Historique limité à **500 items** (FIFO — les plus anciens supprimés en premier)
- Les items dans un pinboard sont **exemptés** de la purge FIFO
- Les doublons consécutifs sont ignorés (même contenu que le dernier clip = pas de nouvelle entrée)

---

## Services système

### `ClipboardMonitor`
- Polling toutes les **0.5 secondes** sur `NSPasteboard.general.changeCount`
- À chaque changement : lit le contenu, détermine le type, crée un `ClipItem` via Core Data
- Types supportés : texte brut, images (PNG/JPEG), URLs, chemins de fichiers

### `HotkeyManager`
- Raccourci global via `CGEventTap` (niveau système, sans sandbox)
- ⌘⇧V par défaut, reconfigurable dans les préférences
- Toggle la visibilité du `PastePanel`

### `PasteboardService`
Séquence au clic sur un item :
1. Écrit le contenu dans `NSPasteboard.general`
2. Ferme le panneau
3. Restaure le focus sur l'app précédemment active (`NSRunningApplication`)
4. Simule ⌘V via `CGEventSource`

### `SearchService`
- `NSFetchRequest` avec prédicat sur `plainText` contenant la query
- Debounce 150ms pour éviter de surcharger Core Data à chaque frappe
- Résultats triés par `createdAt` décroissant

---

## Structure du projet Xcode

```
Valt/
├── App/
│   ├── ValtApp.swift          # @main, NSApplicationDelegate, setup
│   └── AppDelegate.swift      # Status bar item, lifecycle
├── UI/
│   ├── Panel/
│   │   ├── PastePanel.swift   # NSPanel subclass
│   │   └── PanelController.swift
│   ├── Views/
│   │   ├── ShelfView.swift    # Layout principal 2 colonnes
│   │   ├── HistoryView.swift  # Scroll horizontal historique
│   │   ├── PinboardView.swift # Tabs + scroll horizontal
│   │   ├── ClipCellView.swift # Cellule individuelle
│   │   ├── SearchBarView.swift
│   │   └── PreviewView.swift  # Aperçu type-adapté
│   └── Settings/
│       └── SettingsView.swift
├── Services/
│   ├── ClipboardMonitor.swift
│   ├── HotkeyManager.swift
│   ├── PasteboardService.swift
│   └── SearchService.swift
├── Data/
│   ├── PersistenceController.swift
│   ├── ClipItem+CoreData.swift
│   └── Pinboard+CoreData.swift
└── Resources/
    └── Valt.xcdatamodeld
```

---

## Hors scope MVP

- Sync iCloud
- Organisation par app source
- Thèmes / personnalisation visuelle avancée
- Tests unitaires (ajoutés dans une itération suivante)
- Plugins / extensions
