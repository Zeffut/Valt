# Valt

**Gestionnaire de presse-papier pour macOS — rapide, intelligent, discret.**

![macOS](https://img.shields.io/badge/macOS-15%2B-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-orange?style=flat-square&logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Release](https://img.shields.io/github/v/release/Zeffut/Valt?style=flat-square)

---

<!-- Ajoute ici un GIF ou screenshot de l'app -->
<!-- ![Valt demo](docs/assets/demo.gif) -->

## Pourquoi Valt ?

Valt s'ouvre en **une combinaison de touches**, te montre ton historique de copies sous forme de grandes cartes visuelles, et recolle dans l'app que tu utilisais — sans jamais perturber ton flux de travail.

- Pas d'icône dans le Dock
- Pas de fenêtre intrusive
- Zéro friction

## Fonctionnalités

- **⌘⇧V** pour ouvrir l'historique depuis n'importe où
- **Aperçus riches** : couleurs hex rendues, JSON formaté, images, aperçus de liens avec titre et miniature (YouTube, Vimeo, sites web)
- **Navigation clavier** : ← → pour parcourir, Entrée pour coller, Échap pour fermer
- **Recherche instantanée** dans tout l'historique
- **Historique configurable** : nombre d'éléments (50 à 2 000) et durée de rétention (indéfinie à 1 an)
- **Miniatures persistantes** : les aperçus d'URL sont mis en cache sur disque — instantanés au redémarrage
- **Démarrage automatique** à la connexion

## Installation

### Téléchargement direct

1. Télécharger `Valt.dmg` depuis la [dernière release](https://github.com/Zeffut/Valt/releases/latest)
2. Glisser `Valt.app` dans `/Applications`
3. Lancer Valt — accorder la permission **Accessibilité** à la première ouverture
4. Utiliser **⌘⇧V** depuis n'importe quelle app

### Compilation depuis les sources

**Prérequis :** Xcode 16+, macOS 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
git clone https://github.com/Zeffut/Valt.git
cd Valt
xcodegen generate
open Valt.xcodeproj
```

Ou pour builder et installer directement :

```bash
./deploy.sh
```

## Raccourcis

| Touche | Action |
|--------|--------|
| `⌘⇧V` | Ouvrir / fermer Valt |
| `←` `→` | Naviguer dans l'historique |
| `Entrée` | Coller l'élément sélectionné |
| `Échap` | Fermer |
| Double-clic | Copier sans coller |

## Configuration

Cliquer sur l'icône ⚙️ dans le panel ou passer par l'icône dans la barre de menu → Préférences.

- **Nombre d'éléments** : 50 / 100 / 200 / 500 / 1 000 / 2 000
- **Durée de conservation** : indéfinie / 7j / 14j / 30j / 90j / 1 an

## Prérequis

- macOS 15 Sequoia ou supérieur
- Permission **Accessibilité** (pour capturer le raccourci global ⌘⇧V)

## Licence

MIT — voir [LICENSE](LICENSE)
