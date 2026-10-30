-- Fireworks UI strings. Keys shared with game-common or other plugins keep
-- the same translations (one global table: a different value would win or
-- lose depending on load order).
return {
    ["Fireworks"] = { fr = "Feux d'artifice", es = "Fuegos artificiales", de = "Feuerwerk" },
    ["Cooperative hidden-hand card game: build five fireworks together, seeing every hand but your own. Pass the reader for 2-5 players, or play solo with AI teammates."]
        = { fr = "Jeu de cartes coopératif à main cachée : construisez ensemble cinq feux d'artifice en voyant toutes les mains sauf la vôtre. Liseuse passée de main en main pour 2 à 5 joueurs, ou en solo avec des partenaires IA.",
            es = "Juego de cartas cooperativo con la mano oculta: construid juntos cinco fuegos artificiales viendo todas las manos menos la vuestra. Pasad el lector entre 2 y 5 jugadores, o jugad solo con compañeros IA.",
            de = "Kooperatives Kartenspiel mit verdeckter Hand: Baut gemeinsam fünf Feuerwerke und seht alle Hände außer der eigenen. Reader weiterreichen für 2–5 Spieler, oder solo mit KI-Mitspielern." },

    -- Suits
    ["Star"]    = { fr = "Étoile", es = "Estrella", de = "Stern" },
    ["Moon"]    = { fr = "Lune", es = "Luna", de = "Mond" },
    ["Heart"]   = { fr = "Cœur", es = "Corazón", de = "Herz" },
    ["Diamond"] = { fr = "Losange", es = "Rombo", de = "Raute" },
    ["Clover"]  = { fr = "Trèfle", es = "Trébol", de = "Klee" },
    ["Rainbow"] = { fr = "Arc-en-ciel", es = "Arcoíris", de = "Regenbogen" },


    -- Settings / menu
    ["Players"]                 = { fr = "Joueurs", es = "Jugadores", de = "Spieler" },
    ["Player %1"]               = { fr = "Joueur %1", es = "Jugador %1", de = "Spieler %1" },
    ["Mode"]                    = { fr = "Mode", es = "Modo", de = "Modus" },
    ["Mode: %1"]                = { fr = "Mode : %1", es = "Modo: %1", de = "Modus: %1" },
    ["Variant"]                 = { fr = "Variante", es = "Variante", de = "Variante" },
    ["Variant: %1"]             = { fr = "Variante : %1", es = "Variante: %1", de = "Variante: %1" },
    ["Pass the reader"]         = { fr = "Passer la liseuse", es = "Pasar el lector", de = "Reader weiterreichen" },
    ["Solo with AI teammates"]  = { fr = "Solo avec partenaires IA", es = "Solo con compañeros IA", de = "Solo mit KI-Mitspielern" },
    ["5 suits"]                 = { fr = "5 couleurs", es = "5 palos", de = "5 Farben" },
    ["Player names"]            = { fr = "Noms des joueurs", es = "Nombres de los jugadores", de = "Spielernamen" },
    ["Name of player %1"]       = { fr = "Nom du joueur %1", es = "Nombre del jugador %1", de = "Name von Spieler %1" },
    ["%1. %2"]                  = { fr = "%1. %2", es = "%1. %2", de = "%1. %2" },
    ["%1: %2"]                  = { fr = "%1 : %2", es = "%1: %2", de = "%1: %2" },
    ["Cancel"]                  = { fr = "Annuler", es = "Cancelar", de = "Abbrechen" },
    ["OK"]                      = { fr = "OK", es = "OK", de = "OK" },
    ["Continue"]                = { fr = "Continuer", es = "Continuar", de = "Weiter" },
    ["Applies to the next game."] = { fr = "S'appliquera à la prochaine partie.", es = "Se aplicará en la próxima partida.", de = "Gilt ab dem nächsten Spiel." },
    ["Discard pile"]            = { fr = "Défausse", es = "Descartes", de = "Ablagestapel" },
    ["History"]                 = { fr = "Historique", es = "Historial", de = "Verlauf" },
    ["Nothing has happened yet."] = { fr = "Rien ne s'est encore passé.", es = "Todavía no ha pasado nada.", de = "Bisher ist nichts passiert." },
    ["Copies of each card: three 1s, two 2s, two 3s, two 4s, one 5."]
        = { fr = "Exemplaires de chaque carte : trois 1, deux 2, deux 3, deux 4, un 5.", es = "Copias de cada carta: tres 1, dos 2, dos 3, dos 4, un 5.", de = "Exemplare je Karte: drei 1er, zwei 2er, zwei 3er, zwei 4er, eine 5." },

    -- Setup / hand-over
    ["Start game"]              = { fr = "Commencer la partie", es = "Empezar la partida", de = "Spiel starten" },
    ["Build the fireworks together — everyone sees every hand but their own."]
        = { fr = "Construisez les feux d'artifice ensemble — chacun voit toutes les mains sauf la sienne.", es = "Construid juntos los fuegos artificiales: cada uno ve todas las manos menos la suya.", de = "Baut die Feuerwerke gemeinsam – jeder sieht alle Hände außer der eigenen." },
    ["Settings are in the menu."] = { fr = "Les réglages sont dans le menu.", es = "Los ajustes están en el menú.", de = "Einstellungen im Menü." },
    ["%1 (AI)"]                 = { fr = "%1 (IA)", es = "%1 (IA)", de = "%1 (KI)" },
    ["Pass the reader to %1"]   = { fr = "Passez la liseuse à %1", es = "Pasa el lector a %1", de = "Reader an %1 weitergeben" },
    ["Tap when ready — nobody else should look."] = { fr = "Touchez quand vous êtes prêt — personne d'autre ne doit regarder.", es = "Toca cuando estés listo: que nadie más mire.", de = "Tippen, wenn bereit – niemand sonst darf hinsehen." },
    ["Your turn, %1"]           = { fr = "À vous, %1", es = "Tu turno, %1", de = "Du bist dran, %1" },
    ["Tap to see the table."]   = { fr = "Touchez pour voir la table.", es = "Toca para ver la mesa.", de = "Tippen, um den Tisch zu sehen." },
    ["I'm %1: show my turn"]    = { fr = "Je suis %1 : voir mon tour", es = "Soy %1: ver mi turno", de = "Ich bin %1: meinen Zug zeigen" },
    ["Since your last turn:"]   = { fr = "Depuis votre dernier tour :", es = "Desde tu último turno:", de = "Seit deinem letzten Zug:" },
    ["The game begins. Good luck!"] = { fr = "La partie commence. Bonne chance !", es = "Empieza la partida. ¡Suerte!", de = "Das Spiel beginnt. Viel Glück!" },

    -- Table
    ["Your hand (%1)"]          = { fr = "Votre main (%1)", es = "Tu mano (%1)", de = "Deine Hand (%1)" },
    ["Clues: %1/%2"]            = { fr = "Indices : %1/%2", es = "Pistas: %1/%2", de = "Hinweise: %1/%2" },
    ["Fuses: %1/%2"]            = { fr = "Mèches : %1/%2", es = "Mechas: %1/%2", de = "Lunten: %1/%2" },
    ["Deck: %1"]                = { fr = "Pioche : %1", es = "Mazo: %1", de = "Stapel: %1" },
    ["Score: %1"]               = { fr = "Score : %1", es = "Puntuación: %1", de = "Punkte: %1" },
    ["Score: %1/%2"]            = { fr = "Score : %1/%2", es = "Puntuación: %1/%2", de = "Punkte: %1/%2" },
    ["Play"]                    = { fr = "Jouer", es = "Jugar", de = "Spielen" },
    ["Discard"]                 = { fr = "Défausser", es = "Descartar", de = "Abwerfen" },
    ["Clue: %1"]                = { fr = "Indice : %1", es = "Pista: %1", de = "Hinweis: %1" },
    ["Clue: rank"]              = { fr = "Indice : valeur", es = "Pista: valor", de = "Hinweis: Wert" },
    ["Clue: shape"]             = { fr = "Indice : forme", es = "Pista: forma", de = "Hinweis: Form" },
    ["Give this clue"]          = { fr = "Donner cet indice", es = "Dar esta pista", de = "Diesen Hinweis geben" },
    ["Tap a card to act."]      = { fr = "Touchez une carte pour agir.", es = "Toca una carta para actuar.", de = "Tippe auf eine Karte." },
    ["Your card %1: play it or discard it?"] = { fr = "Votre carte %1 : la jouer ou la défausser ?", es = "Tu carta %1: ¿jugarla o descartarla?", de = "Deine Karte %1: spielen oder abwerfen?" },
    ["Clue %1: shape or rank?"] = { fr = "Indice à %1 : forme ou valeur ?", es = "Pista a %1: ¿forma o valor?", de = "Hinweis an %1: Form oder Wert?" },
    ["Last round: %1 turns left"] = { fr = "Dernier tour : %1 tours restants", es = "Última ronda: quedan %1 turnos", de = "Letzte Runde: noch %1 Züge" },
    ["All 8 clue tokens are there: you can't discard."] = { fr = "Les 8 jetons d'indice sont là : impossible de défausser.", es = "Están las 8 fichas de pista: no puedes descartar.", de = "Alle 8 Hinweisplättchen sind da: Abwerfen nicht möglich." },
    ["No clue token left: play or discard."] = { fr = "Plus de jeton d'indice : jouez ou défaussez.", es = "No quedan fichas de pista: juega o descarta.", de = "Kein Hinweisplättchen mehr: spielen oder abwerfen." },
    ["That move is not allowed."] = { fr = "Ce coup n'est pas permis.", es = "Esa jugada no está permitida.", de = "Dieser Zug ist nicht erlaubt." },

    -- Log
    ["%1 gave %2 a clue: %3."]  = { fr = "%1 a donné un indice à %2 : %3.", es = "%1 dio una pista a %2: %3.", de = "%1 gab %2 einen Hinweis: %3." },
    ["two|three|four|five"]     = { fr = "deux|trois|quatre|cinq", es = "dos|tres|cuatro|cinco", de = "zwei|drei|vier|fünf" },
    ["%1 played %2: it lights up!"] = { fr = "%1 a joué %2 : ça s'illumine !", es = "%1 jugó %2: ¡se ilumina!", de = "%1 spielte %2: es leuchtet!" },
    ["%1 played %2: misfire! A fuse burns."] = { fr = "%1 a joué %2 : raté ! Une mèche brûle.", es = "%1 jugó %2: ¡fallo! Arde una mecha.", de = "%1 spielte %2: Fehlzündung! Eine Lunte brennt." },
    ["%1 discarded %2."]        = { fr = "%1 a défaussé %2.", es = "%1 descartó %2.", de = "%1 warf %2 ab." },
    ["Firework complete: a clue token comes back."] = { fr = "Feu complet : un jeton d'indice revient.", es = "Fuego completo: vuelve una ficha de pista.", de = "Feuerwerk komplett: ein Hinweisplättchen kommt zurück." },
    ["Last card drawn: everyone plays one more turn."] = { fr = "Dernière carte piochée : chacun joue encore un tour.", es = "Última carta robada: cada uno juega un turno más.", de = "Letzte Karte gezogen: jeder spielt noch einen Zug." },

    -- Game over
    ["The third fuse burnt: the show is over."] = { fr = "La troisième mèche a brûlé : le spectacle est fini.", es = "Ardió la tercera mecha: se acabó el espectáculo.", de = "Die dritte Lunte ist abgebrannt: die Show ist vorbei." },
    ["Every firework is complete!"] = { fr = "Tous les feux d'artifice sont complets !", es = "¡Todos los fuegos artificiales están completos!", de = "Alle Feuerwerke sind komplett!" },
    ["The deck is empty and everyone has played."] = { fr = "La pioche est vide et chacun a joué.", es = "El mazo está vacío y todos han jugado.", de = "Der Stapel ist leer und alle haben gespielt." },

    -- Suit name packs
    ["Planets"]    = { fr = "Planètes", es = "Planetas", de = "Planeten" },
    ["Gems"]       = { fr = "Pierres précieuses", es = "Gemas", de = "Edelsteine" },
    ["Shadow"]     = { fr = "Ombre", es = "Sombra", de = "Schatten" },
    ["Sun"]        = { fr = "Soleil", es = "Sol", de = "Sonne" },
    ["Venus"]      = { fr = "Vénus", es = "Venus", de = "Venus" },
    ["Mars"]       = { fr = "Mars", es = "Marte", de = "Mars" },
    ["Earth"]      = { fr = "Terre", es = "Tierra", de = "Erde" },
    ["Saturn"]     = { fr = "Saturne", es = "Saturno", de = "Saturn" },
    ["Black hole"] = { fr = "Trou noir", es = "Agujero negro", de = "Schwarzes Loch" },
    ["Sapphire"]   = { fr = "Saphir", es = "Zafiro", de = "Saphir" },
    ["Pearl"]      = { fr = "Perle", es = "Perla", de = "Perle" },
    ["Ruby"]       = { fr = "Rubis", es = "Rubí", de = "Rubin" },
    ["Topaz"]      = { fr = "Topaze", es = "Topacio", de = "Topas" },
    ["Emerald"]    = { fr = "Émeraude", es = "Esmeralda", de = "Smaragd" },
    ["Opal"]       = { fr = "Opale", es = "Ópalo", de = "Opal" },
    ["Onyx"]       = { fr = "Onyx", es = "Ónix", de = "Onyx" },

    -- Variants and options
    ["Rainbow (wild)"]        = { fr = "Arc-en-ciel (joker)", es = "Arcoíris (comodín)", de = "Regenbogen (Joker)" },
    ["Rainbow (own colour)"]  = { fr = "Arc-en-ciel (à part)", es = "Arcoíris (palo propio)", de = "Regenbogen (eigene Farbe)" },
    ["Black (single cards)"]  = { fr = "Noire (cartes uniques)", es = "Negro (cartas únicas)", de = "Schwarz (Einzelkarten)" },
    ["Settings"]              = { fr = "Réglages", es = "Ajustes", de = "Einstellungen" },
    ["Short game: yes"]       = { fr = "Partie courte : oui", es = "Partida corta: sí", de = "Kurzes Spiel: ja" },
    ["Short game: no"]        = { fr = "Partie courte : non", es = "Partida corta: no", de = "Kurzes Spiel: nein" },
    ["Third fuse: %1"]        = { fr = "Troisième mèche : %1", es = "Tercera mecha: %1", de = "Dritte Lunte: %1" },
    ["score 0"]               = { fr = "score 0", es = "puntuación 0", de = "0 Punkte" },
    ["keep the score"]        = { fr = "on garde le score", es = "se mantiene la puntuación", de = "Punkte bleiben" },
    ["Suit names: %1"]        = { fr = "Noms des couleurs : %1", es = "Nombres de los palos: %1", de = "Farbnamen: %1" },
    ["short game"]            = { fr = "partie courte", es = "partida corta", de = "kurzes Spiel" },
    ["3rd fuse scores 0"]     = { fr = "3e mèche = score 0", es = "3.ª mecha = 0 puntos", de = "3. Lunte = 0 Punkte" },
    ["%1: a single card of each rank."] = { fr = "%1 : une seule carte de chaque valeur.", es = "%1: una sola carta de cada valor.", de = "%1: nur eine Karte je Wert." },
    ["The deck is empty: the short game ends."] = { fr = "La pioche est vide : la partie courte s'arrête.", es = "El mazo está vacío: la partida corta termina.", de = "Der Stapel ist leer: das kurze Spiel endet." },
    ["Last card drawn: the short game ends."] = { fr = "Dernière carte piochée : la partie courte s'arrête.", es = "Última carta robada: la partida corta termina.", de = "Letzte Karte gezogen: das kurze Spiel endet." },
    ["By the rule chosen, the %1 points built count for nothing."] = { fr = "Selon la règle choisie, les %1 points construits ne comptent pas.", es = "Según la regla elegida, los %1 puntos construidos no cuentan.", de = "Nach der gewählten Regel zählen die %1 gebauten Punkte nicht." },
    ["New to the game? Try the Tutorial in the menu."] = { fr = "Nouveau venu ? Essayez le Tutoriel dans le menu.", es = "¿Primera vez? Prueba el tutorial del menú.", de = "Neu hier? Probier das Tutorial im Menü." },

    -- Clue wording
    ["one %1"]                = { fr = "un %1", es = "un %1", de = "eine %1" },
    ["%1 %2s"]                = { fr = "%1 cartes %2", es = "%1 cartas %2", de = "%1 Karten %2" },
    ["a %1"]                  = { fr = "une carte %1", es = "una carta %1", de = "eine Karte %1" },
    ["%1 %2 cards"]           = { fr = "%1 cartes %2", es = "%1 cartas %2", de = "%1 Karten %2" },
    ["%1 (card %2)"]          = { fr = "%1 (carte %2)", es = "%1 (carta %2)", de = "%1 (Karte %2)" },
    ["%1 (cards %2)"]         = { fr = "%1 (cartes %2)", es = "%1 (cartas %2)", de = "%1 (Karten %2)" },
    ["Tell %1: %2?"]          = { fr = "Dire à %1 : %2 ?", es = "¿Decir a %1: %2?", de = "%1 sagen: %2?" },
    ["Your hand"]             = { fr = "Votre main", es = "Tu mano", de = "Deine Hand" },

    -- Tutorial
    ["Tutorial"] = { fr = "Tutoriel", es = "Tutorial", de = "Tutorial" },
    ["Welcome to the tutorial!\n\nAt the top: the five fireworks, each built from 1 to 5. Then Ada's hand — you see her cards, she doesn't. At the bottom: your own hand, hidden from you. You only see what clues tell you about it."]
        = { fr = "Bienvenue dans le tutoriel !\n\nEn haut : les cinq feux d'artifice, chacun construit de 1 à 5. Ensuite la main d'Ada — vous voyez ses cartes, elle non. En bas : votre propre main, cachée pour vous. Vous n'en voyez que ce que les indices vous apprennent.",
            es = "¡Bienvenido al tutorial!\n\nArriba: los cinco fuegos artificiales, cada uno de 1 a 5. Luego la mano de Ada: tú ves sus cartas, ella no. Abajo: tu propia mano, oculta para ti. Solo ves lo que te dicen las pistas.",
            de = "Willkommen im Tutorial!\n\nOben: die fünf Feuerwerke, jedes von 1 bis 5 gebaut. Dann Adas Hand – du siehst ihre Karten, sie nicht. Unten: deine eigene Hand, vor dir verborgen. Du siehst nur, was dir Hinweise verraten." },
    ["Ada's clue points at your card %1: under the convention it is playable. Tap it, then Play."]
        = { fr = "L'indice d'Ada désigne votre carte %1 : selon la convention, elle est jouable. Touchez-la, puis Jouer.",
            es = "La pista de Ada señala tu carta %1: según la convención, se puede jugar. Tócala y luego Jugar.",
            de = "Adas Hinweis zeigt auf deine Karte %1: nach der Konvention ist sie spielbar. Tippe sie an, dann Spielen." },
    ["Ada's card %1 (%2) can be played right now, but she doesn't know it. Tap it, then a clue button, check the highlighted cards and confirm. Each clue costs one of the 8 clue tokens."]
        = { fr = "La carte %1 d'Ada (%2) peut être jouée tout de suite, mais elle ne le sait pas. Touchez-la, puis un bouton d'indice, vérifiez les cartes surlignées et confirmez. Chaque indice coûte un des 8 jetons d'indice.",
            es = "La carta %1 de Ada (%2) se puede jugar ya, pero ella no lo sabe. Tócala, luego un botón de pista, revisa las cartas resaltadas y confirma. Cada pista cuesta una de las 8 fichas.",
            de = "Adas Karte %1 (%2) ist sofort spielbar, aber sie weiß es nicht. Tippe sie an, dann eine Hinweis-Taste, prüfe die markierten Karten und bestätige. Jeder Hinweis kostet eines der 8 Plättchen." },
    ["A misfire burns a fuse. At the third one, the show is over."]
        = { fr = "Un raté fait brûler une mèche. À la troisième, le spectacle est fini.", es = "Un fallo quema una mecha. A la tercera, se acaba el espectáculo.", de = "Eine Fehlzündung brennt eine Lunte ab. Bei der dritten ist die Show vorbei." },
    ["Clue tokens are running low. Discarding a card wins one back: discard your oldest card without a clue (the rightmost), it is the least likely to be needed."]
        = { fr = "Les jetons d'indice s'épuisent. Défausser une carte en regagne un : défaussez votre plus ancienne carte sans indice (la plus à droite), c'est la moins susceptible de servir.",
            es = "Quedan pocas fichas de pista. Descartar una carta recupera una: descarta tu carta más antigua sin pista (la de más a la derecha), es la que menos falta hará.",
            de = "Die Hinweisplättchen werden knapp. Abwerfen bringt eines zurück: wirf deine älteste Karte ohne Hinweis ab (ganz rechts), sie wird am wenigsten gebraucht." },
    ["The deck is empty: everyone plays one last turn."]
        = { fr = "La pioche est vide : chacun joue un dernier tour.", es = "El mazo está vacío: cada uno juega un último turno.", de = "Der Stapel ist leer: jeder spielt noch einen letzten Zug." },
    ["Tutorial complete! Start a regular game from the menu: choose the players, the mode and the variants there. The Rules explain everything in detail."]
        = { fr = "Tutoriel terminé ! Lancez une vraie partie depuis le menu : choisissez-y les joueurs, le mode et les variantes. Les Règles expliquent tout en détail.",
            es = "¡Tutorial terminado! Empieza una partida normal desde el menú: elige allí los jugadores, el modo y las variantes. Las Reglas lo explican todo.",
            de = "Tutorial beendet! Starte ein normales Spiel über das Menü: dort wählst du Spieler, Modus und Varianten. Die Regeln erklären alles im Detail." },
}
