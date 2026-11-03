# Changelog

All notable changes to this project will be documented in this file.

## [1.0.3] - 2026-11-03

### Changed
- Picks up game-common 1.11.0: the shared on-screen keyboard (where used)
  gives every key the same letter size, and the no-repeat history helper.

## [1.0.2] - 2026-11-02

### Changed
- Picks up game-common 1.10.0: the shared Tools → Games menu also lists
  the games' new "· multiplayer" entries under Party & quiz.

## [1.0.1] - 2026-11-02

### Changed
- Listed under **Tools → Games**, grouped by category, instead of its own
  entry in the Tools menu (game-common 1.9.1).

## [1.0.0] - 2026-10-30

### Added
- First release: a cooperative hidden-hand card game for 2-5 players. Five
  suits (Star, Moon, Heart, Diamond, Clover) told apart by drawn shapes and
  names, ranks 1-5 (three 1s, two 2s/3s/4s, one 5), 8 clue tokens, 3 fuses,
  hands of 5 (2-3 players) or 4 (4-5 players).
- Pass the reader: a hand-over screen before each turn, with what happened
  since that player's last turn; the turn view shows the teammates' hands and
  only the clue knowledge of your own cards.
- Clues by shape or rank with a highlighted preview before confirming,
  discards, plays, last round once the deck is empty, score with labels.
- Solo mode with convention-based computer teammates, and a guided
  tutorial game with contextual tips.
- Variants (a 6th suit, 30 points): wild rainbow (touched by every shape
  clue), rainbow as its own colour, black with a single card of each rank.
- Options: short game (ends when the deck runs out), 0 points on the third
  fuse; suit-name themes (Fireworks, Planets, Gems).
- Over sixty end-of-game verdicts in English and French, picked at random.
- Discard pile and history views, game saved and restored on close,
  French/Spanish/German translations.
