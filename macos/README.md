# Tron macOS (version de test)

Dictée dans n'importe quelle app du Mac, sur l'appareil. Pas de compte ni de Supabase pour l'instant.

## Utilisation

- Fenêtre principale, comme sur iPhone : statistiques de la semaine, gros bouton micro pour une note vocale (un clic démarre et arrête, maintenir enregistre), waveform et texte en direct, onglets Notes et Historique. Note : titre modifiable, texte nettoyé ou original, audio réécoutable, copier, partager, supprimer.

- Maintenir **fn / 🌐** : Tron écoute. Relâcher : le texte est collé au curseur.
- **Double appui** sur fn : le micro reste ouvert. Un appui pour finir, Échap pour annuler.
- Pendant la dictée, une île sort de l'encoche (ou en haut au centre sans encoche) avec seulement la waveform, puis la transcription.
- Pas de champ texte actif : le texte est copié, l'île indique ⌘ V.
- Menu barre des menus : langue, dernières dictées (un clic les recopie), autorisations.

## Moteur

Le même que l'app iOS : Parakeet TDT 0.6B v3 via FluidAudio, fichiers partagés depuis `ios/` (voir `project.yml`).

## Compiler

```sh
cd macos
xcodegen generate
xcodebuild -project TronMac.xcodeproj -scheme Tron -configuration Debug -derivedDataPath build -allowProvisioningUpdates build
open build/Build/Products/Debug/Tron.app
```

Au premier lancement : autoriser le micro et l'Accessibilité (touche fn et collage). Conseillé : Réglages Système, Clavier, « Appuyer sur 🌐 » sur « Ne rien faire ».
