# Menu COTW : menu tout-en-un pour theHunter: Call of the Wild (Windows, mode solo).
# Installe et lance les deux outils libres de la communauté (licence MIT), téléchargés depuis leurs dépôts officiels :
#   - Animal Population Changer - Revived (RyMaxim/apc) : diamants, Great Ones, pelages rares, sexe des animaux ;
#   - Mod Builder - Revived (RyMaxim/cotw-mod-builder) : munitions, armes, chargeurs, boutique, argent,
#     compétences, population des réserves, sens des animaux, météo, etc.
# Le menu ajoute : détection du jeu et des sauvegardes, sauvegarde/restauration, régénération des populations,
# options de lancement des mods copiées dans le presse-papiers.
# Aucun DLC n'est débloqué : les outils agissent sur le contenu déjà possédé.

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
# Sans cela, Windows PowerShell 5.1 télécharge très lentement les grosses archives (barre de progression).
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$script:Journal = $null
$script:Fenetre = $null
$script:Reglages = $null

$Version = '1.0.0'
$IdJeuSteam = '518790'
$ExeJeu = 'theHunterCotW_F.exe'
$OptionsLancement = '--vfs-fs dropzone --vfs-archive archives_win64 --vfs-archive patch_win64 --vfs-archive dlc_win64 --vfs-fs .'
$Base = Join-Path $env:LOCALAPPDATA 'MenuCOTW'
$DossierOutils = Join-Path $Base 'outils'
$DossierCopies = Join-Path $Base 'copies-de-sauvegardes'
$FichierReglages = Join-Path $Base 'reglages.json'

$Outils = @{
  apc = @{ Nom = 'Animaux (APC)'; Depot = 'RyMaxim/apc'; Archive = '^apcgui_[0-9.]+\.7z$'; Exe = 'apcgui.exe' }
  modbuilder = @{ Nom = 'Mod Builder'; Depot = 'RyMaxim/cotw-mod-builder'; Archive = '^modbuilder_[0-9.]+\.7z$'; Exe = 'modbuilder.exe' }
}

function Initialiser-Dossiers {
  foreach ($d in @($Base, $DossierOutils, $DossierCopies)) {
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
  }
}

function Lire-Reglages {
  if (Test-Path -LiteralPath $FichierReglages) {
    try { return Get-Content -LiteralPath $FichierReglages -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
  }
  return [pscustomobject]@{ jeu = ''; sauvegardes = '' }
}

function Ecrire-Reglages($r) {
  Initialiser-Dossiers
  $r | ConvertTo-Json | Set-Content -LiteralPath $FichierReglages -Encoding UTF8
}

# --- Détection du jeu ---------------------------------------------------------------------------------------------

function Lire-BibliothequesSteam([string]$SteamPath) {
  $chemins = New-Object System.Collections.Generic.List[string]
  if ($SteamPath) { $chemins.Add($SteamPath) }
  $vdf = Join-Path $SteamPath 'steamapps\libraryfolders.vdf'
  if ($SteamPath -and (Test-Path -LiteralPath $vdf)) {
    foreach ($ligne in Get-Content -LiteralPath $vdf -Encoding UTF8) {
      if ($ligne -match '^\s*"path"\s+"(.+)"\s*$') { $chemins.Add(($Matches[1] -replace '\\\\', '\')) }
    }
  }
  return $chemins | Select-Object -Unique
}

function Trouver-Jeu {
  $candidats = New-Object System.Collections.Generic.List[string]
  try {
    $steam = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath -replace '/', '\'
    foreach ($lib in Lire-BibliothequesSteam $steam) { $candidats.Add((Join-Path $lib 'steamapps\common\theHunterCotW')) }
  } catch { }
  foreach ($racine in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, 'C:\Games', 'D:\Games', 'D:\SteamLibrary\steamapps\common', 'E:\SteamLibrary\steamapps\common')) {
    if ($racine) {
      $candidats.Add((Join-Path $racine 'Epic Games\theHunterCotW'))
      $candidats.Add((Join-Path $racine 'theHunterCotW'))
    }
  }
  foreach ($c in $candidats) { if (Test-Path -LiteralPath (Join-Path $c $ExeJeu)) { return $c } }
  return ''
}

function Trouver-Sauvegardes {
  $docs = [Environment]::GetFolderPath('MyDocuments')
  foreach ($c in @((Join-Path $docs 'Avalanche Studios\COTW\Saves'), (Join-Path $docs 'Avalanche Studios\Epic Games Store\COTW\Saves'))) {
    if (Test-Path -LiteralPath $c) {
      # Un sous-dossier par compte (identifiant numérique) : on prend celui qui contient des fichiers de population.
      $compte = Get-ChildItem -LiteralPath $c -Directory -ErrorAction SilentlyContinue |
        Where-Object { Get-ChildItem -LiteralPath $_.FullName -Filter 'animal_population_*' -File -ErrorAction SilentlyContinue } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($compte) { return $compte.FullName }
      return $c
    }
  }
  return ''
}

function Jeu-EnCours { return [bool](Get-Process -Name 'theHunterCotW_F' -ErrorAction SilentlyContinue) }

# --- Outils de la communauté ---------------------------------------------------------------------------------------

function Obtenir-7z {
  foreach ($p in @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe", (Join-Path $DossierOutils '7zr.exe'))) {
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }
  }
  $dest = Join-Path $DossierOutils '7zr.exe'
  Ecrire-Journal 'Téléchargement de 7zr.exe (extracteur officiel 7-Zip)...'
  Invoke-WebRequest -UseBasicParsing -Uri 'https://www.7-zip.org/a/7zr.exe' -OutFile $dest
  return $dest
}

function Derniere-Version($cle) {
  $o = $Outils[$cle]
  $rel = Invoke-RestMethod -UseBasicParsing -Uri ("https://api.github.com/repos/{0}/releases/latest" -f $o.Depot) -Headers @{ 'User-Agent' = 'MenuCOTW' }
  $asset = $rel.assets | Where-Object { $_.name -match $o.Archive } | Select-Object -First 1
  if (-not $asset) { throw "Aucune archive Windows trouvée pour $($o.Nom)." }
  return [pscustomobject]@{ Version = $rel.tag_name; Url = $asset.browser_download_url; Nom = $asset.name; Taille = $asset.size }
}

function Exe-Outil($cle) {
  $dossier = Join-Path $DossierOutils $cle
  if (-not (Test-Path -LiteralPath $dossier)) { return '' }
  $exe = Get-ChildItem -LiteralPath $dossier -Recurse -Filter $Outils[$cle].Exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($exe) { return $exe.FullName } else { return '' }
}

function Version-Installee($cle) {
  $f = Join-Path (Join-Path $DossierOutils $cle) 'VERSION-MENU.txt'
  if (Test-Path -LiteralPath $f) { return (Get-Content -LiteralPath $f -Raw).Trim() } else { return '' }
}

function Installer-Outil($cle) {
  Initialiser-Dossiers
  $o = $Outils[$cle]
  $v = Derniere-Version $cle
  if ((Version-Installee $cle) -eq $v.Version -and (Exe-Outil $cle)) { Ecrire-Journal "$($o.Nom) est déjà à jour ($($v.Version))."; return }
  $archive = Join-Path $env:TEMP $v.Nom
  Ecrire-Journal ("Téléchargement de {0} {1} ({2:N0} Mo)..." -f $o.Nom, $v.Version, ($v.Taille / 1MB))
  Invoke-WebRequest -UseBasicParsing -Uri $v.Url -OutFile $archive
  if ((Get-Item -LiteralPath $archive).Length -ne $v.Taille) { throw "Téléchargement incomplet de $($o.Nom)." }
  $dossier = Join-Path $DossierOutils $cle
  if (Test-Path -LiteralPath $dossier) { Remove-Item -LiteralPath $dossier -Recurse -Force }
  New-Item -ItemType Directory -Path $dossier | Out-Null
  Ecrire-Journal "Extraction de $($o.Nom)..."
  $z = Obtenir-7z
  & $z x $archive ("-o" + $dossier) -y | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Extraction de $($o.Nom) en échec (code $LASTEXITCODE)." }
  Remove-Item -LiteralPath $archive -Force
  Set-Content -LiteralPath (Join-Path $dossier 'VERSION-MENU.txt') -Value $v.Version
  if (-not (Exe-Outil $cle)) { throw "$($o.Exe) introuvable après extraction." }
  Ecrire-Journal "$($o.Nom) $($v.Version) installé."
}

function Lancer-Outil($cle) {
  $exe = Exe-Outil $cle
  if (-not $exe) {
    Ecrire-Journal "$($Outils[$cle].Nom) n'est pas encore installé : installation..."
    Installer-Outil $cle
    $exe = Exe-Outil $cle
  }
  Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe)
  Ecrire-Journal "$($Outils[$cle].Nom) ouvert."
}

# --- Sauvegardes du jeu --------------------------------------------------------------------------------------------

function Copier-Sauvegardes([string]$saves, [string]$motif) {
  if (-not $saves -or -not (Test-Path -LiteralPath $saves)) { throw 'Dossier des sauvegardes introuvable : choisis-le avec « Choisir… ».' }
  Initialiser-Dossiers
  $zip = Join-Path $DossierCopies ("sauvegardes-{0}-{1}.zip" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $motif)
  Compress-Archive -Path (Join-Path $saves '*') -DestinationPath $zip -CompressionLevel Optimal
  Ecrire-Journal "Copie des sauvegardes : $zip"
  return $zip
}

function Restaurer-Sauvegardes([string]$saves, [string]$zip) {
  if (Jeu-EnCours) { throw 'Ferme le jeu avant de restaurer.' }
  Copier-Sauvegardes $saves 'avant-restauration' | Out-Null
  Get-ChildItem -LiteralPath $saves -Force | Remove-Item -Recurse -Force
  Expand-Archive -LiteralPath $zip -DestinationPath $saves -Force
  Ecrire-Journal "Sauvegardes restaurées depuis : $zip"
}

function Regenerer-Populations([string]$saves) {
  if (Jeu-EnCours) { throw 'Ferme le jeu avant de régénérer les populations.' }
  $fichiers = @(Get-ChildItem -LiteralPath $saves -Filter 'animal_population_*' -File -ErrorAction SilentlyContinue)
  if ($fichiers.Count -eq 0) { Ecrire-Journal 'Aucun fichier de population à supprimer.'; return }
  Copier-Sauvegardes $saves 'avant-regeneration' | Out-Null
  $fichiers | Remove-Item -Force
  Ecrire-Journal "$($fichiers.Count) fichier(s) de population supprimé(s) : le jeu les recrée au prochain chargement de chaque réserve."
}

# --- Interface ---------------------------------------------------------------------------------------------------

function Ecrire-Journal([string]$texte) {
  $ligne = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $texte
  if ($script:Journal) {
    $script:Journal.AppendText($ligne + [Environment]::NewLine)
    [System.Windows.Forms.Application]::DoEvents()
  } else { Write-Host $ligne }
}

function Executer([scriptblock]$action) {
  try { $script:Fenetre.UseWaitCursor = $true; & $action }
  catch { Ecrire-Journal ('ERREUR : ' + $_.Exception.Message); [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Menu COTW', 'OK', 'Error') | Out-Null }
  finally { $script:Fenetre.UseWaitCursor = $false; Mettre-AJour-Etat }
}

function Mettre-AJour-Etat {
  $script:LabelJeu.Text = 'Jeu : ' + $(if ($script:Reglages.jeu) { $script:Reglages.jeu } else { 'non trouvé' })
  $script:LabelSaves.Text = 'Sauvegardes : ' + $(if ($script:Reglages.sauvegardes) { $script:Reglages.sauvegardes } else { 'non trouvées' })
  $va = Version-Installee 'apc'; $vm = Version-Installee 'modbuilder'
  $script:LabelOutils.Text = 'Outils : APC ' + $(if ($va) { $va } else { 'non installé' }) + '  ·  Mod Builder ' + $(if ($vm) { $vm } else { 'non installé' })
}

function Nouveau-Bouton($parent, [string]$texte, [int]$x, [int]$y, [int]$l, [scriptblock]$clic) {
  $b = New-Object System.Windows.Forms.Button
  $b.Text = $texte; $b.Location = New-Object System.Drawing.Point($x, $y); $b.Size = New-Object System.Drawing.Size($l, 34)
  $b.Add_Click($clic); $parent.Controls.Add($b); return $b
}

function Afficher-Menu {
  Add-Type -AssemblyName System.Windows.Forms, System.Drawing
  [System.Windows.Forms.Application]::EnableVisualStyles()
  $script:Reglages = Lire-Reglages
  if (-not $script:Reglages.jeu -or -not (Test-Path -LiteralPath (Join-Path $script:Reglages.jeu $ExeJeu))) { $script:Reglages.jeu = Trouver-Jeu }
  if (-not $script:Reglages.sauvegardes -or -not (Test-Path -LiteralPath $script:Reglages.sauvegardes)) { $script:Reglages.sauvegardes = Trouver-Sauvegardes }
  Ecrire-Reglages $script:Reglages

  $f = New-Object System.Windows.Forms.Form
  $f.Text = "Menu COTW $Version — theHunter: Call of the Wild (solo)"; $f.Size = New-Object System.Drawing.Size(760, 700)
  $f.StartPosition = 'CenterScreen'; $f.FormBorderStyle = 'FixedSingle'; $f.MaximizeBox = $false
  $script:Fenetre = $f

  $titre = New-Object System.Windows.Forms.Label
  $titre.Text = 'MENU COTW'; $titre.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
  $titre.Location = New-Object System.Drawing.Point(16, 10); $titre.AutoSize = $true; $f.Controls.Add($titre)

  $script:LabelJeu = New-Object System.Windows.Forms.Label; $script:LabelJeu.Location = New-Object System.Drawing.Point(18, 50); $script:LabelJeu.Size = New-Object System.Drawing.Size(600, 18); $f.Controls.Add($script:LabelJeu)
  $script:LabelSaves = New-Object System.Windows.Forms.Label; $script:LabelSaves.Location = New-Object System.Drawing.Point(18, 72); $script:LabelSaves.Size = New-Object System.Drawing.Size(600, 18); $f.Controls.Add($script:LabelSaves)
  $script:LabelOutils = New-Object System.Windows.Forms.Label; $script:LabelOutils.Location = New-Object System.Drawing.Point(18, 94); $script:LabelOutils.Size = New-Object System.Drawing.Size(600, 18); $f.Controls.Add($script:LabelOutils)
  Nouveau-Bouton $f 'Choisir…' 630 46 100 { Executer {
    $d = New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description = "Dossier du jeu (celui qui contient $ExeJeu)"
    if ($d.ShowDialog() -eq 'OK') { if (Test-Path -LiteralPath (Join-Path $d.SelectedPath $ExeJeu)) { $script:Reglages.jeu = $d.SelectedPath; Ecrire-Reglages $script:Reglages } else { throw "$ExeJeu introuvable dans ce dossier." } } } } | Out-Null
  Nouveau-Bouton $f 'Choisir…' 630 82 100 { Executer {
    $d = New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description = 'Dossier des sauvegardes (contient les fichiers animal_population_*)'
    if ($d.ShowDialog() -eq 'OK') { $script:Reglages.sauvegardes = $d.SelectedPath; Ecrire-Reglages $script:Reglages } } } | Out-Null

  $g1 = New-Object System.Windows.Forms.GroupBox; $g1.Text = 'Animaux'; $g1.Location = New-Object System.Drawing.Point(16, 124); $g1.Size = New-Object System.Drawing.Size(714, 112); $f.Controls.Add($g1)
  Nouveau-Bouton $g1 'Diamants, Great Ones, pelages rares, sexe (APC)' 12 24 340 { Executer { Lancer-Outil 'apc' } } | Out-Null
  Nouveau-Bouton $g1 'Population : nombre par espèce et par réserve' 362 24 340 { Executer { Lancer-Outil 'modbuilder'; Ecrire-Journal 'Mod Builder : « Modify Animal Population » ou « Increase Reserve Population », puis « Régénérer les populations ».' } } | Out-Null
  Nouveau-Bouton $g1 'Régénérer les populations (après un mod de population)' 12 66 340 { Executer {
    if ([System.Windows.Forms.MessageBox]::Show("Supprimer les fichiers de population ? Une copie complète des sauvegardes est faite avant.`nLe jeu recrée chaque population au prochain chargement de la réserve (animaux replacés dans leurs zones).", 'Menu COTW', 'YesNo', 'Question') -eq 'Yes') { Regenerer-Populations $script:Reglages.sauvegardes } } } | Out-Null
  Nouveau-Bouton $g1 'Sens, agressivité, diamants et pelages plus fréquents' 362 66 340 { Executer { Lancer-Outil 'modbuilder'; Ecrire-Journal 'Mod Builder : « Modify Animal Senses », « Modify Animal Aggression », « Increase Diamond Spawns », « Increase Rare Furs ».' } } | Out-Null

  $g2 = New-Object System.Windows.Forms.GroupBox; $g2.Text = 'Armes, munitions, joueur'; $g2.Location = New-Object System.Drawing.Point(16, 244); $g2.Size = New-Object System.Drawing.Size(714, 112); $f.Controls.Add($g2)
  Nouveau-Bouton $g2 'Munitions, armes, chargeurs, lunettes (Mod Builder)' 12 24 340 { Executer { Lancer-Outil 'modbuilder'; Ecrire-Journal 'Mod Builder : « Modify Ammo », « Modify Weapon », « Increase Weapon Magazine », « Modify Scope Zoom ».' } } | Out-Null
  Nouveau-Bouton $g2 'Boutique, argent, équipement de départ' 362 24 340 { Executer { Lancer-Outil 'modbuilder'; Ecrire-Journal 'Mod Builder : « Modify Store » (prix), « Increase Cash Reward », « Custom Starting Loadout ».' } } | Out-Null
  Nouveau-Bouton $g2 'Compétences, endurance, vitesse, sac' 12 66 340 { Executer { Lancer-Outil 'modbuilder'; Ecrire-Journal 'Mod Builder : « Modify Skills », « Enhanced Endurance », « Increase Speed », « Enhanced Pack Mule ».' } } | Out-Null
  Nouveau-Bouton $g2 'Ouvrir le dossier des mods (dropzone)' 362 66 340 { Executer {
    if (-not $script:Reglages.jeu) { throw 'Dossier du jeu inconnu : choisis-le avec « Choisir… ».' }
    $dz = Join-Path $script:Reglages.jeu 'dropzone'; if (-not (Test-Path -LiteralPath $dz)) { New-Item -ItemType Directory -Path $dz | Out-Null }
    Start-Process explorer.exe $dz } } | Out-Null

  $g3 = New-Object System.Windows.Forms.GroupBox; $g3.Text = 'Activer, sauvegarder, mettre à jour'; $g3.Location = New-Object System.Drawing.Point(16, 364); $g3.Size = New-Object System.Drawing.Size(714, 112); $f.Controls.Add($g3)
  Nouveau-Bouton $g3 'Activer les mods : copier les options de lancement' 12 24 340 { Executer {
    Set-Clipboard -Value $OptionsLancement
    Ecrire-Journal 'Options copiées. Steam : clic droit sur le jeu > Propriétés > Options de lancement > Ctrl+V.'
    [System.Windows.Forms.MessageBox]::Show("Copié dans le presse-papiers :`n`n$OptionsLancement`n`nSteam : clic droit sur theHunter: Call of the Wild > Propriétés > Général > Options de lancement, puis Ctrl+V.", 'Menu COTW') | Out-Null } } | Out-Null
  Nouveau-Bouton $g3 'Copier mes sauvegardes maintenant' 362 24 340 { Executer { Copier-Sauvegardes $script:Reglages.sauvegardes 'manuelle' | Out-Null } } | Out-Null
  Nouveau-Bouton $g3 'Restaurer une copie de sauvegardes…' 12 66 340 { Executer {
    $d = New-Object System.Windows.Forms.OpenFileDialog; $d.InitialDirectory = $DossierCopies; $d.Filter = 'Copies (*.zip)|*.zip'
    if ($d.ShowDialog() -eq 'OK') { Restaurer-Sauvegardes $script:Reglages.sauvegardes $d.FileName } } } | Out-Null
  Nouveau-Bouton $g3 'Installer / mettre à jour les deux outils' 362 66 340 { Executer { Installer-Outil 'apc'; Installer-Outil 'modbuilder' } } | Out-Null

  $script:Journal = New-Object System.Windows.Forms.TextBox
  $script:Journal.Multiline = $true; $script:Journal.ReadOnly = $true; $script:Journal.ScrollBars = 'Vertical'
  $script:Journal.Location = New-Object System.Drawing.Point(16, 486); $script:Journal.Size = New-Object System.Drawing.Size(714, 160); $f.Controls.Add($script:Journal)

  Mettre-AJour-Etat
  Ecrire-Journal 'Bienvenue. Mode solo uniquement. Ferme le jeu avant de modifier les sauvegardes.'
  if (Jeu-EnCours) { Ecrire-Journal 'Attention : le jeu est ouvert.' }
  [void]$f.ShowDialog()
}

if ($MyInvocation.InvocationName -ne '.') { Afficher-Menu }
