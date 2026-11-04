# Menu COTW

Menu tout-en-un pour **theHunter: Call of the Wild** sous **Windows**, en **mode solo**.

## Télécharger

**[⬇ Télécharger Menu COTW (zip)](https://github.com/Momolscode/menu-cotw/releases/latest/download/MenuCOTW.zip)**

1. Décompresse le zip où tu veux (par exemple sur le Bureau).
2. Double-clique sur **`Lancer-Menu-COTW.bat`**.
   Si Windows affiche « Windows a protégé votre ordinateur », clique sur *Informations complémentaires* puis *Exécuter quand même*.
3. Dans le menu, clique sur **« Installer / mettre à jour les deux outils »** (environ 440 Mo à télécharger la première fois).

## Ce que fait le menu

Le menu installe et lance deux outils libres de la communauté (licence MIT), téléchargés depuis leurs dépôts officiels, et regroupe tout en français :

| Bouton | Ce qu'il permet |
| --- | --- |
| Diamants, Great Ones, pelages rares, sexe (APC) | Transformer des animaux existants d'une réserve |
| Population : nombre par espèce et par réserve | Choisir combien d'animaux de chaque espèce le jeu génère |
| Régénérer les populations | Faire recréer les populations (après un mod de population) ; le jeu replace lui-même les animaux dans leurs zones de vie |
| Sens, agressivité, diamants et pelages plus fréquents | Régler le comportement et la rareté des animaux |
| Munitions, armes, chargeurs, lunettes | Munitions, dégâts, recul, taille des chargeurs, zoom |
| Boutique, argent, équipement de départ | Prix de la boutique, gains d'argent, équipement au départ |
| Compétences, endurance, vitesse, sac | Avantages du joueur |
| Activer les mods | Copie les options de lancement Steam à coller dans *Propriétés > Options de lancement* |
| Copier / restaurer mes sauvegardes | Une copie complète est aussi faite automatiquement avant chaque opération risquée |

Toutes les réserves et tous les DLC **que tu possèdes** sont pris en charge. Le menu ne débloque aucun DLC.

## Activer les mods dans le jeu

Les mods du Mod Builder sont écrits dans le dossier `dropzone` du jeu. Pour que le jeu les lise :

1. Clique sur **« Activer les mods : copier les options de lancement »**.
2. Dans Steam : clic droit sur *theHunter: Call of the Wild* > *Propriétés* > *Général* > *Options de lancement*, puis **Ctrl+V**.

Options utilisées : `--vfs-fs dropzone --vfs-archive archives_win64 --vfs-archive patch_win64 --vfs-archive dlc_win64 --vfs-fs .`

Pour revenir au jeu d'origine : vide ces options de lancement (ou le dossier `dropzone`).

## Limites

- **Mode solo uniquement.** N'utilise pas ces modifications en multijoueur.
- Une espèce ne peut apparaître que sur les réserves où le jeu lui a prévu des zones de vie : faire apparaître une espèce sur une carte qui ne la prévoit pas n'est pas fiable (animaux mal placés ou plantage).
- Après une mise à jour du jeu, attends la mise à jour des deux outils (bouton « Installer / mettre à jour »).
- Certains antivirus signalent à tort les exécutables construits avec PyInstaller (cas connu des deux outils).
- Ferme le jeu avant de modifier ou de restaurer les sauvegardes.

## Où sont les fichiers

- Outils et copies de sauvegardes : `%LOCALAPPDATA%\MenuCOTW`
- Sauvegardes du jeu (Steam) : `Documents\Avalanche Studios\COTW\Saves\<identifiant>`

## Crédits

- [Animal Population Changer - Revived](https://github.com/RyMaxim/apc) — Ryan Maxim, d'après cpypasta (MIT)
- [Mod Builder - Revived](https://github.com/RyMaxim/cotw-mod-builder) — Ryan Maxim, d'après cpypasta (MIT)
- [DECA](https://github.com/kk49/deca) — Krzysztof Kamieniecki (MIT)

Ces outils ne sont pas redistribués ici : le menu les télécharge depuis leurs pages de versions officielles.
theHunter: Call of the Wild est une marque d'Expansive Worlds / Avalanche Studios Group. Ce projet n'est pas affilié à l'éditeur.
