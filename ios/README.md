# Tron iOS (version de test)

App core pour tester la dictée sur iPhone. Pas de compte ni de Supabase pour l'instant.

## Contenu

- Onboarding court : bienvenue, prénom, langue, micro, bouton Action (iPhone 15 Pro et plus), prêt.
- Accueil : stats de la semaine, gros bouton micro (un appui démarre et arrête, maintenir enregistre tant qu'on appuie, glisser vers le haut annule), ondes et texte en direct, onglets Notes et Historique.
- Note : titre automatique, texte nettoyé (sans "euh"), original, audio réécoutable, copier, partager, supprimer.
- Réglages : prénom, langue, bouton Action, conservation de l'historique, statistiques anonymes (désactivées), version.
- Raccourci "Dicter avec Tron" pour le bouton Action : ouvre Tron, écoute, copie le texte.

## Modèle

NVIDIA Parakeet TDT 0.6B v3 (multilingue : français, anglais, allemand, espagnol, italien...), converti en Core ML par FluidInference et exécuté sur le Neural Engine via [FluidAudio](https://github.com/FluidInference/FluidAudio) 0.17.5.
Les poids (`FluidInference/parakeet-tdt-0.6b-v3-coreml` sur Hugging Face) sont téléchargés une seule fois au premier lancement, ensuite tout marche hors ligne.

## Lancer sur un iPhone

1. Mac avec Xcode 16 ou plus récent, iPhone sous iOS 17 ou plus.
2. Ouvrir `ios/Tron.xcodeproj`. Xcode récupère FluidAudio tout seul.
3. Cible Tron, onglet Signing & Capabilities : choisir votre Team. Si l'identifiant `app.tron.ios` est refusé, le changer (par exemple `com.votrenom.tron`).
4. Brancher l'iPhone, l'activer en mode développeur si iOS le demande, le choisir en haut, puis Run.

Le simulateur marche aussi, mais la transcription y est bien plus lente (pas de Neural Engine).

## Pas encore là

Compte et Supabase, clavier Tron (et donc le collage auto du clavier Tron mini), réunions, polices Instrument Sans et JetBrains Mono (les polices système sont utilisées en attendant).
