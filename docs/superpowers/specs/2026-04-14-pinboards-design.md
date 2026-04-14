# Pinboards — Design Spec
Date: 2026-04-14

## Vue d'ensemble

Ajouter des pinboards à Valt : des collections permanentes d'items épinglés, accessibles via des onglets en haut du panel.

## UX

### Barre d'onglets
- Remplace la barre supérieure actuelle (recherche + engrenage)
- Onglets : **Historique** (toujours en premier, non supprimable) + un onglet par pinboard + bouton **+**
- La barre de recherche et l'engrenage sont toujours présents, juste sous les onglets
- Clic sur un onglet → affiche le contenu correspondant

### Créer un pinboard
- Clic sur **+** → un champ de texte inline apparaît dans la barre d'onglets
- L'utilisateur tape le nom, appuie sur Entrée pour valider ou Échap pour annuler
- Le nouveau pinboard devient l'onglet actif

### Épingler un item
- Icône 📌 visible au hover sur chaque carte dans l'**Historique**
- Clic → ajoute l'item au pinboard actuellement sélectionné (si aucun pinboard n'existe, un pinboard "Favoris" est créé automatiquement)
- Si on est déjà sur un onglet Historique sans pinboard sélectionné et qu'il y a plusieurs pinboards → popover pour choisir

### Retirer un item d'un pinboard
- Clic droit sur une carte dans un pinboard → "Retirer du pinboard"
- L'item reste dans l'historique normal

### Supprimer un pinboard
- Clic droit sur un onglet de pinboard → "Supprimer ce pinboard"
- Les items du pinboard sont détachés (pinboard = nil) et restent dans l'historique

## Architecture

### Modèles existants (aucun changement)
- `Pinboard` (CoreData) — `name: String`, relation `items: [ClipItem]`
- `ClipItem.pinboard: Pinboard?` — nil = historique, non-nil = épinglé

### Nouveaux composants

**`TabBarView`** — barre d'onglets SwiftUI
- `@FetchRequest` pour charger tous les pinboards
- `@Binding var activeTab: ActiveTab`
- État local `isCreating: Bool` pour afficher le champ de création inline

**`ActiveTab`** (enum)
- `.history`
- `.pinboard(Pinboard)`

**`ShelfView`** — modifications
- Ajoute `@State var activeTab: ActiveTab = .history`
- Passe `activeTab` à `TabBarView` et à `HistoryView`
- `displayedItems` filtre selon `activeTab` :
  - `.history` → prédiscat existant `pinboard == nil`
  - `.pinboard(p)` → prédicat `pinboard == p`

**`ClipCellView`** — modifications
- Nouveau paramètre `onPin: (() -> Void)?` (nil si déjà dans un pinboard)
- Icône 📌 en overlay, visible au hover, appelle `onPin`

### Flux de données
1. `ShelfView` maintient `activeTab`
2. `TabBarView` lit les pinboards via `@FetchRequest` et met à jour `activeTab`
3. `HistoryView` reçoit les items déjà filtrés via `displayedItems`
4. `ClipCellView` reçoit `onPin` → `ShelfView` gère l'association CoreData

## Gestion des erreurs
- Nom de pinboard vide → ignoré (pas de création)
- Nom dupliqué → autorisé (les pinboards sont identifiés par leur UUID)
- Suppression d'un pinboard non vide → les items sont détachés, pas supprimés
