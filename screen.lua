local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local InfoMessage     = require("ui/widget/infomessage")
local InputDialog     = require("ui/widget/inputdialog")
local RenderText      = require("ui/rendertext")
local Size            = require("ui/size")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local TextViewer      = require("ui/widget/textviewer")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local Device          = require("device")
local _               = require("i18n")
local T               = require("ffi/util").template

local ScreenBase = require("screen_base")
local MenuHelper = require("menu_helper")

local Game        = lrequire("game")
local AI          = lrequire("ai")
local BoardWidget = lrequire("board_widget")

local DeviceScreen = Device.screen
local DPI_SCALE = DeviceScreen:scaleBySize(1000) / 1000

local function pxFace(px, bold)
    return Font:getFace(bold and "tfont" or "cfont", math.max(8, math.floor(px / DPI_SCALE)))
end

-- One line at up to `px` pixels, shrunk until it fits `max_w`.
local function fitLine(text, px, max_w, bold)
    local face = pxFace(px, bold)
    while px > 12 do
        local m = RenderText:sizeUtf8Text(0, max_w * 10, face, text, true, false)
        if m.x <= max_w then break end
        px   = math.floor(px * 0.9)
        face = pxFace(px, bold)
    end
    return TextWidget:new{ text = text, face = face, max_width = max_w }
end

local function wrapText(text, face, width, align)
    return TextBoxWidget:new{ text = text, face = face, width = width, alignment = align or "center" }
end

-- Suit names per theme: indices 1-5, 6 = the rainbow suit, 7 = the black
-- suit. The shapes don't change; only the names do. Translated at use time.
local SUIT_PACKS = {
    fireworks = { "Star", "Moon", "Heart", "Diamond", "Clover", "Rainbow", "Shadow" },
    planets   = { "Sun", "Moon", "Venus", "Mars", "Earth", "Saturn", "Black hole" },
    gems      = { "Sapphire", "Pearl", "Ruby", "Topaz", "Emerald", "Opal", "Onyx" },
}
local PACK_ORDER = { "fireworks", "planets", "gems" }
local PACK_LABELS = {
    fireworks = _("Fireworks"),
    planets   = _("Planets"),
    gems      = _("Gems"),
}

local VARIANT_LABELS = {
    none    = _("5 suits"),
    rainbow = _("Rainbow (wild)"),
    sixth   = _("Rainbow (own colour)"),
    black   = _("Black (single cards)"),
}

-- Computer teammates, named after computing pioneers.
local AI_NAMES = { "Ada", "Alan", "Grace", "Hedy", "Linus", "Margaret", "Charles", "Katherine" }

local DEFAULT_PLAYERS = 3
local MAX_PLAYERS     = 5

-- The tutorial deck: what the two hands start with (first card listed is
-- dealt first, i.e. ends up as the oldest card, position 5). The rest of the
-- deck is shuffled as usual.
local TUTORIAL_TOP = {
    -- you
    { s = 5, r = 4 }, { s = 4, r = 5 }, { s = 2, r = 1 }, { s = 3, r = 3 }, { s = 1, r = 2 },
    -- Ada
    { s = 5, r = 2 }, { s = 3, r = 1 }, { s = 4, r = 4 }, { s = 2, r = 3 }, { s = 1, r = 1 },
}

local GAME_RULES_EN = _([[
Fireworks — Rules

A cooperative card game: all players win or lose together. Build five fireworks, one per suit, each from 1 up to 5 in order.

The cards: 5 suits — Star, Moon, Heart, Diamond and Clover, each with its own shape and name — and in each suit three 1s, two 2s, two 3s, two 4s and one 5. (The menu's Settings can rename the suits: Planets, Gems. The shapes stay the same.)

The twist: you see everybody's cards except your own. Your own hand only shows what clues told you:
• the rank if you know it; "≠3" if you only know it is not a 3; otherwise the ranks still possible;
• the shape (and name) if you know it; "≠" and a shape if you only know it is not that one; otherwise the shapes still possible;
• a black corner once a clue touched the card.
Position 1 is your newest card. Under each teammate's card, a small line shows what that player already knows about it.

On your turn, do ONE of these:
• Give a clue (costs 1 of the 8 clue tokens): tap a teammate's card, then "Clue: shape" or "Clue: rank". The clue points out ALL of that player's cards of that shape (or rank) — they learn which cards are, and which are not. Check the highlighted cards and confirm.
• Discard a card (regains 1 clue token; not possible with 8 tokens): tap one of your cards, then Discard.
• Play a card: tap one of your cards, then Play. If it continues its firework it is added; otherwise it is discarded and a fuse burns.

After playing or discarding, you draw a card. Completing a firework with its 5 gives back a clue token. The discard pile and the history are in the menu.

The game ends when the 3rd fuse burns, when all fireworks are complete, or once the deck is empty and everyone has played one last turn. Score: the sum of the fireworks (25 at most).
0-5 horrible · 6-10 mediocre · 11-15 honourable · 16-20 excellent · 21-24 amazing · 25 legendary.

Passing the reader: on your turn a screen first says who should take the reader, with what happened since your last turn. Tap when you are ready — nobody else should look.

Solo mode: you play with computer teammates. They play a card they know is playable, and they read clues with a simple convention: a clue points at a card to PLAY — the oldest unclued card if the clue touches it, otherwise the newest one it touches — unless that card cannot be playable yet (then it is a "save": keep it). Clue them the same way, and read their clues the same way. The Tutorial (menu) is a short guided solo game.

Variants (a 6th suit, 30 points at most):
• Rainbow (wild): ten cards that count as every suit: any shape clue touches them, and they can't be named in a clue.
• Rainbow (own colour): ten cards, a suit like the others, with its own clue.
• Black (single cards): only one card of each rank, 1 to 5 — every one is the last of its kind, never discard them.

Options (menu → Settings):
• Short game: the game ends as soon as the last card is drawn, without a last round.
• Third fuse: score 0 — as in some editions, a show that blows up scores nothing.
]])

local GAME_RULES_FR = [[
Feux d'artifice — Règles

Un jeu de cartes coopératif : tous les joueurs gagnent ou perdent ensemble. Construisez cinq feux d'artifice, un par couleur, chacun de 1 à 5 dans l'ordre.

Les cartes : 5 couleurs — Étoile, Lune, Cœur, Losange et Trèfle, chacune avec sa forme et son nom — et dans chaque couleur trois 1, deux 2, deux 3, deux 4 et un 5. (Les Réglages du menu peuvent renommer les couleurs : Planètes, Pierres précieuses. Les formes restent les mêmes.)

La particularité : vous voyez les cartes de tout le monde, sauf les vôtres. Votre main ne montre que ce que les indices vous ont appris :
• la valeur si vous la connaissez ; « ≠3 » si vous savez seulement que ce n'est pas un 3 ; sinon les valeurs encore possibles ;
• la forme (et son nom) si vous la connaissez ; « ≠ » et une forme si vous savez seulement que ce n'est pas celle-là ; sinon les formes encore possibles ;
• un coin noir dès qu'un indice a touché la carte.
La position 1 est votre carte la plus récente. Sous chaque carte d'un partenaire, une petite ligne indique ce que ce joueur sait déjà d'elle.

À votre tour, faites UNE de ces actions :
• Donner un indice (coûte 1 des 8 jetons d'indice) : touchez une carte d'un partenaire, puis « Indice : forme » ou « Indice : valeur ». L'indice désigne TOUTES les cartes de ce joueur de cette forme (ou valeur) — il apprend lesquelles le sont, et lesquelles ne le sont pas. Vérifiez les cartes surlignées, puis confirmez.
• Défausser une carte (rend 1 jeton d'indice ; impossible avec 8 jetons) : touchez une de vos cartes, puis Défausser.
• Jouer une carte : touchez une de vos cartes, puis Jouer. Si elle prolonge son feu d'artifice, elle est posée ; sinon elle est défaussée et une mèche brûle.

Après avoir joué ou défaussé, vous piochez une carte. Terminer un feu avec son 5 rend un jeton d'indice. La défausse et l'historique sont dans le menu.

La partie s'arrête quand la 3e mèche brûle, quand tous les feux sont complets, ou quand la pioche est vide et que chacun a joué un dernier tour. Score : la somme des feux (25 au maximum).
0-5 horrible · 6-10 médiocre · 11-15 honorable · 16-20 excellent · 21-24 extraordinaire · 25 légendaire.

Passer la liseuse : à votre tour, un écran indique d'abord qui doit prendre la liseuse, avec ce qui s'est passé depuis votre dernier tour. Touchez quand vous êtes prêt — personne d'autre ne doit regarder.

Mode solo : vous jouez avec des partenaires ordinateur. Ils jouent une carte qu'ils savent jouable, et lisent les indices avec une convention simple : un indice désigne une carte à JOUER — la plus ancienne carte sans indice si l'indice la touche, sinon la plus récente qu'il touche — sauf si cette carte ne peut pas encore être jouable (c'est alors une « sauvegarde » : on la garde). Donnez-leur vos indices de la même façon, et lisez les leurs de la même façon. Le Tutoriel (menu) est une courte partie solo guidée.

Variantes (une 6e couleur, 30 points au maximum) :
• Arc-en-ciel (joker) : dix cartes qui comptent pour toutes les couleurs : tout indice de forme les touche, et on ne peut pas les nommer dans un indice.
• Arc-en-ciel (à part) : dix cartes, une couleur comme les autres, avec son propre indice.
• Noire (cartes uniques) : une seule carte de chaque valeur, de 1 à 5 — chacune est la dernière de son espèce, ne la défaussez jamais.

Options (menu → Réglages) :
• Partie courte : la partie s'arrête dès que la dernière carte est piochée, sans dernier tour.
• Troisième mèche : score 0 — comme dans certaines éditions, un spectacle qui explose ne rapporte rien.
]]

-- ---------------------------------------------------------------------------
-- Tutorial tips: shown once each, the first one that applies, when a
-- tutorial turn view opens. `when` reads the game; `text` may use it.
-- ---------------------------------------------------------------------------

local TIPS = {
    {
        id = "welcome",
        when = function(scr, g) return true end,
        text = function(scr, g) return _("Welcome to the tutorial!\n\nAt the top: the five fireworks, each built from 1 to 5. Then Ada's hand — you see her cards, she doesn't. At the bottom: your own hand, hidden from you. You only see what clues tell you about it.") end,
    },
    {
        id = "play_known",
        when = function(scr, g) return scr:tutorialPlayableSlot() ~= nil end,
        text = function(scr, g)
            return T(_("Ada's clue points at your card %1: under the convention it is playable. Tap it, then Play."),
                scr:tutorialPlayableSlot())
        end,
    },
    {
        id = "clue_hint",
        when = function(scr, g) return g:canClue() and scr:tutorialMateCard() ~= nil end,
        text = function(scr, g)
            local p, slot = scr:tutorialMateCard()
            return T(_("Ada's card %1 (%2) can be played right now, but she doesn't know it. Tap it, then a clue button, check the highlighted cards and confirm. Each clue costs one of the 8 clue tokens."),
                slot, scr:cardName(g.hands[p][slot]))
        end,
    },
    {
        id = "misfire",
        when = function(scr, g) return g.fuses > 0 end,
        text = function(scr, g) return _("A misfire burns a fuse. At the third one, the show is over.") end,
    },
    {
        id = "discard",
        when = function(scr, g) return g.tokens <= 4 end,
        text = function(scr, g) return _("Clue tokens are running low. Discarding a card wins one back: discard your oldest card without a clue (the rightmost), it is the least likely to be needed.") end,
    },
    {
        id = "last",
        when = function(scr, g) return g.turns_left ~= nil end,
        text = function(scr, g) return _("The deck is empty: everyone plays one last turn.") end,
    },
}

-- ---------------------------------------------------------------------------
-- FireworksScreen
--
-- Phases:
--   setup    -- no game yet: what the next game will be, and Start
--   handover -- "pass the reader to X", with what happened since X's turn
--   turn     -- X's view: teammates' hands, own knowledge, the actions
--   over     -- final score, every hand face up
-- ---------------------------------------------------------------------------

local FireworksScreen = ScreenBase:extend{}

function FireworksScreen:init()
    local plugin = self.plugin
    self.num_players = plugin:getSetting("num_players", DEFAULT_PLAYERS)
    self.solo        = plugin:getSetting("solo", false)
    -- 1.0.0 stored a "rainbow" boolean.
    self.variant     = plugin:getSetting("variant", plugin:getSetting("rainbow", false) and "rainbow" or "none")
    if not VARIANT_LABELS[self.variant] then self.variant = "none" end
    self.short       = plugin:getSetting("short", false)
    self.zero_on_fuses = plugin:getSetting("zero_on_fuses", false)
    self.pack        = plugin:getSetting("pack", "fireworks")
    if not SUIT_PACKS[self.pack] then self.pack = "fireworks" end
    self.names       = plugin:getSetting("names", {})
    self.phase = "setup"
    local state = plugin:loadState()
    if type(state) == "table" and state.game then
        local g = Game.load(state.game)
        if g then
            self.game = g
            self.phase = g.over and "over" or "handover"
            self.solo_game = state.solo and true or false
            self.tutorial = state.tutorial and true or false
            self.tips_shown = type(state.tips) == "table" and state.tips or {}
        end
    end
    ScreenBase.init(self)
end

function FireworksScreen:serializeState()
    if not self.game then return nil end
    return { game = self.game:serialize(), solo = self.solo_game or nil,
             tutorial = self.tutorial or nil, tips = self.tutorial and self.tips_shown or nil }
end

function FireworksScreen:save()
    self.plugin:saveState(self:serializeState())
end

function FireworksScreen:playerName(i)
    local n = self.names[i]
    if type(n) == "string" and n ~= "" then return n end
    return T(_("Player %1"), i)
end

function FireworksScreen:displayName(p)
    local pl = self.game.players[p]
    if pl.ai then return T(_("%1 (AI)"), pl.name) end
    return pl.name
end

-- `count` computer names, none equal to the human's (ignoring case).
function FireworksScreen:botNames(human, count)
    local out, taken = {}, (human or ""):lower()
    for _i, n in ipairs(AI_NAMES) do
        if #out >= count then break end
        if n:lower() ~= taken then out[#out + 1] = n end
    end
    return out
end

-- Suit names for a game (or the current settings): index 6 is the black
-- suit's name when that variant is on.
function FireworksScreen:suitNames(variant)
    local pack = SUIT_PACKS[self.pack] or SUIT_PACKS.fireworks
    local names = {}
    for s = 1, 5 do names[s] = _(pack[s]) end
    names[6] = _(pack[variant == "black" and 7 or 6])
    return names
end

function FireworksScreen:suitName(s)
    return self:suitNames(self.game and self.game.variant or self.variant)[s]
end

function FireworksScreen:isRoundOver()
    return self.game ~= nil and self.game.over
end

-- ---------------------------------------------------------------------------
-- Game flow
-- ---------------------------------------------------------------------------

function FireworksScreen:onNewGame()
    local players = {}
    if self.solo then
        local human = self:playerName(1)
        players[1] = { name = human, ai = false }
        for i, n in ipairs(self:botNames(human, self.num_players - 1)) do
            players[i + 1] = { name = n, ai = true }
        end
    else
        for i = 1, self.num_players do players[i] = { name = self:playerName(i), ai = false } end
    end
    self.game = Game.new{ players = players, variant = self.variant, short = self.short,
                          zero_on_fuses = self.zero_on_fuses }
    self.solo_game, self.tutorial, self.tips_shown = self.solo, false, {}
    self.selected, self.pending = nil, nil
    -- Solo: nobody to hide anything from, go straight to the table.
    self.phase = self.solo and "turn" or "handover"
    self:save()
    self:rebuild()
end

-- A guided two-player solo game on a friendly deck, with tips.
function FireworksScreen:onTutorial()
    local human = self:playerName(1)
    local bots = self:botNames(human, 1)
    self.game = Game.new{
        players = { { name = human, ai = false }, { name = bots[1], ai = true } },
        variant = "none", top = TUTORIAL_TOP,
    }
    self.solo_game, self.tutorial, self.tips_shown = true, true, {}
    self.selected, self.pending = nil, nil
    self.phase = "turn"
    self:save()
    self:rebuild()
    self:maybeTip()
end

-- Tutorial: the human's card pointed out as playable (play mark, or known).
function FireworksScreen:tutorialPlayableSlot()
    local g = self.game
    for i, c in ipairs(g.hands[g.current]) do
        if c.play or g:knownPlayable(g:candidates(g.current, i)) then return i end
    end
end

-- Tutorial: a teammate's playable card nobody has clued yet.
function FireworksScreen:tutorialMateCard()
    local g = self.game
    for p = 1, g.num_players do
        if p ~= g.current then
            for i, c in ipairs(g.hands[p]) do
                if g:isPlayable(c.s, c.r) and not c.clued then return p, i end
            end
        end
    end
end

function FireworksScreen:maybeTip()
    if not self.tutorial or self.phase ~= "turn" or not self.game then return end
    local g = self.game
    local text
    if g.over then
        if self.tips_shown["end"] then return end
        self.tips_shown["end"] = true
        text = _("Tutorial complete! Start a regular game from the menu: choose the players, the mode and the variants there. The Rules explain everything in detail.")
    else
        -- The first applicable tip; the welcome also brings the one after
        -- it, so the very first turn says what to do, not only what is where.
        for _i, tip in ipairs(TIPS) do
            if not self.tips_shown[tip.id] and tip.when(self, g) then
                self.tips_shown[tip.id] = true
                local t = tip.text(self, g)
                text = text and (text .. "\n\n" .. t) or t
                if tip.id ~= "welcome" then break end
            end
        end
    end
    if text then
        self:save()
        UIManager:show(InfoMessage:new{ text = text })
    end
end

function FireworksScreen:rebuild()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- Apply the current player's action, then let the computer teammates play
-- until it is a human's turn again.
function FireworksScreen:doAction(action)
    local g = self.game
    if not g or g.over then return end
    local entry = g:apply(action)
    if not entry then
        self:updateStatus(_("That move is not allowed."))
        return
    end
    while not g.over and g.players[g.current].ai do
        local a = AI.choose(g, g.current)
        if not g:apply(a) then break end   -- never happens: the bot is legal by construction
    end
    self.selected, self.pending = nil, nil
    if g.over then self:_pickLabel() end
    self.phase = g.over and "over" or "handover"
    self:save()
    self:rebuild()
    if g.over and self.tutorial then
        self.phase = "turn"   -- maybeTip only speaks on a table view
        self:maybeTip()
        self.phase = "over"
    end
end

function FireworksScreen:onReady()
    self.phase = "turn"
    self.selected, self.pending = nil, nil
    self:rebuild()
    self:maybeTip()
end

function FireworksScreen:onCardTap(p, slot)
    if self.phase ~= "turn" then return end
    if self.pending then self.pending = nil end
    if self.selected and self.selected.p == p and self.selected.slot == slot then
        self.selected = nil
    else
        self.selected = { p = p, slot = slot }
    end
    self:rebuild()
end

function FireworksScreen:onPlay()
    local sel = self.selected
    if not sel or sel.p ~= self.game.current then return end
    self:doAction({ kind = "play", slot = sel.slot })
end

function FireworksScreen:onDiscard()
    local sel = self.selected
    if not sel or sel.p ~= self.game.current then return end
    if not self.game:canDiscard() then
        self:updateStatus(_("All 8 clue tokens are there: you can't discard."))
        return
    end
    self:doAction({ kind = "discard", slot = sel.slot })
end

-- First step of a clue: highlight what it would touch, wait for Confirm.
function FireworksScreen:previewClue(clue)
    local sel, g = self.selected, self.game
    if not sel or sel.p == g.current then return end
    if not g:canClue() then
        self:updateStatus(_("No clue token left: play or discard."))
        return
    end
    local slots = {}
    for _i, i in ipairs(g:touchedSlots(sel.p, clue)) do slots[i] = true end
    self.pending = { target = sel.p, clue = clue, slots = slots }
    self:rebuild()
end

function FireworksScreen:onSuitClue()
    local sel, g = self.selected, self.game
    if not sel or sel.p == g.current then return end
    local card = g.hands[sel.p][sel.slot]
    if not (g.rainbow and card.s == Game.RAINBOW) then
        self:previewClue({ kind = "suit", v = card.s })
        return
    end
    -- A wild rainbow card answers to every shape: ask which one to name.
    local items = {}
    for _i, s in ipairs(g:clueSuits()) do items[#items + 1] = { id = s, text = self:suitName(s) } end
    MenuHelper.openPickerMenu{
        title     = _("Clue: shape"),
        items     = items,
        parent    = self,
        on_select = function(s) self:previewClue({ kind = "suit", v = s }) end,
    }
end

function FireworksScreen:onRankClue()
    local sel, g = self.selected, self.game
    if not sel or sel.p == g.current then return end
    self:previewClue({ kind = "rank", v = g.hands[sel.p][sel.slot].r })
end

function FireworksScreen:onConfirmClue()
    local pend = self.pending
    if not pend then return end
    self:doAction({ kind = "clue", target = pend.target, clue = pend.clue })
end

function FireworksScreen:onCancelClue()
    self.pending = nil
    self:rebuild()
end

-- ---------------------------------------------------------------------------
-- Score verdicts: one picked at random per finished game, kept in the save.
-- ---------------------------------------------------------------------------

function FireworksScreen:_labels()
    if not self._label_lists then
        local lang = _.lang() == "fr" and "fr" or "en"
        self._label_lists = lrequire("labels_" .. lang)
    end
    return self._label_lists
end

function FireworksScreen:_pickLabel()
    local g = self.game
    if not g.label_pick then g.label_pick = math.random(1000) end
end

function FireworksScreen:scoreLabel()
    local g = self.game
    local list = self:_labels()[g:scoreBand()]
    local pick = g.label_pick or 1
    return list[(pick - 1) % #list + 1]
end

-- ---------------------------------------------------------------------------
-- Text for log entries
-- ---------------------------------------------------------------------------

local function numberWord(n)
    local words = {}
    for w in _("two|three|four|five"):gmatch("[^|]+") do words[#words + 1] = w end
    return words[n - 1] or tostring(n)
end

function FireworksScreen:cardName(c)
    return T("%1 %2", self:suitName(c.s), c.r)
end

-- "two 5s", "a Star" -- and with with_cards: "two 5s (cards 1, 4)".
function FireworksScreen:clueText(clue, slots, with_cards)
    local n = #slots
    local what
    if clue.kind == "rank" then
        what = n == 1 and T(_("one %1"), clue.v) or T(_("%1 %2s"), numberWord(n), clue.v)
    else
        local name = self:suitName(clue.v)
        what = n == 1 and T(_("a %1"), name) or T(_("%1 %2 cards"), numberWord(n), name)
    end
    if not with_cards then return what end
    local list = table.concat(slots, ", ")
    return n == 1 and T(_("%1 (card %2)"), what, list) or T(_("%1 (cards %2)"), what, list)
end

function FireworksScreen:entryText(e)
    local who = self:displayName(e.p)
    local txt
    if e.kind == "clue" then
        txt = T(_("%1 gave %2 a clue: %3."), who, self:displayName(e.target), self:clueText(e.clue, e.slots, true))
    elseif e.kind == "play" then
        if e.ok then
            txt = T(_("%1 played %2: it lights up!"), who, self:cardName(e.card))
            if e.bonus then txt = txt .. " " .. _("Firework complete: a clue token comes back.") end
        else
            txt = T(_("%1 played %2: misfire! A fuse burns."), who, self:cardName(e.card))
        end
    else
        txt = T(_("%1 discarded %2."), who, self:cardName(e.card))
    end
    if e.last_card then
        txt = txt .. " " .. (self.game.short and _("Last card drawn: the short game ends.")
            or _("Last card drawn: everyone plays one more turn."))
    end
    return txt
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

function FireworksScreen:modeLabel(solo)
    return solo and _("Solo with AI teammates") or _("Pass the reader")
end

function FireworksScreen:fuseRuleLabel(zero)
    return zero and _("score 0") or _("keep the score")
end

function FireworksScreen:_afterSettingChange()
    if self.game and not self.game.over then
        self:updateStatus(_("Applies to the next game."))
    end
    if self.phase == "setup" then self:rebuild() end
end

function FireworksScreen:_setSetting(key, value)
    self[key] = value
    self.plugin:saveSetting(key, value)
    self:_afterSettingChange()
end

function FireworksScreen:openPlayersMenu()
    local items = {}
    for n = 2, MAX_PLAYERS do items[#items + 1] = { id = n, text = tostring(n) } end
    MenuHelper.openPickerMenu{
        title = _("Players"), items = items, current_id = self.num_players, parent = self,
        on_select = function(n) self:_setSetting("num_players", n) end,
    }
end

function FireworksScreen:openModeMenu()
    MenuHelper.openPickerMenu{
        title = _("Mode"),
        items = { { id = false, text = self:modeLabel(false) }, { id = true, text = self:modeLabel(true) } },
        current_id = self.solo, parent = self,
        on_select = function(v) self:_setSetting("solo", v) end,
    }
end

function FireworksScreen:openVariantMenu()
    local items = {}
    for _i, id in ipairs(Game.VARIANTS) do items[#items + 1] = { id = id, text = VARIANT_LABELS[id] } end
    MenuHelper.openPickerMenu{
        title = _("Variant"), items = items, current_id = self.variant, parent = self,
        on_select = function(v) self:_setSetting("variant", v) end,
    }
end

-- Rule options and suit names; re-opens after each change.
function FireworksScreen:openSettingsMenu()
    MenuHelper.openPickerMenu{
        title = _("Settings"),
        items = {
            { id = "short", text = self.short and _("Short game: yes") or _("Short game: no") },
            { id = "zero",  text = T(_("Third fuse: %1"), self:fuseRuleLabel(self.zero_on_fuses)) },
            { id = "pack",  text = T(_("Suit names: %1"), PACK_LABELS[self.pack]) },
        },
        parent = self,
        on_select = function(id)
            if id == "short" then
                self:_setSetting("short", not self.short)
            elseif id == "zero" then
                self:_setSetting("zero_on_fuses", not self.zero_on_fuses)
            else
                local k = 1
                for i, p in ipairs(PACK_ORDER) do if p == self.pack then k = i end end
                -- Names are only flavour: they apply right away, mid-game too.
                self.pack = PACK_ORDER[k % #PACK_ORDER + 1]
                self.plugin:saveSetting("pack", self.pack)
                self:rebuild()
            end
            self:openSettingsMenu()
        end,
    }
end

function FireworksScreen:openNamesMenu()
    local items = {}
    local count = self.solo and 1 or self.num_players
    for i = 1, count do items[#items + 1] = { id = i, text = T(_("%1. %2"), i, self:playerName(i)) } end
    MenuHelper.openPickerMenu{
        title = _("Player names"), items = items, parent = self,
        on_select = function(i) self:editName(i) end,
    }
end

function FireworksScreen:editName(i)
    local dialog
    dialog = InputDialog:new{
        title = T(_("Name of player %1"), i),
        input = self:playerName(i),
        buttons = { {
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            { text = _("OK"), is_enter_default = true, callback = function()
                local name = (dialog:getInputText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
                UIManager:close(dialog)
                self.names[i] = name ~= "" and name or nil
                self.plugin:saveSetting("names", self.names)
                self:_afterSettingChange()
                self:openNamesMenu()
            end },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function FireworksScreen:showText(title, text)
    UIManager:show(TextViewer:new{
        title  = title,
        text   = text,
        width  = math.floor(DeviceScreen:getWidth() * 0.9),
        height = math.floor(DeviceScreen:getHeight() * 0.9),
    })
end

function FireworksScreen:showDiscards()
    local g = self.game
    if not g then return end
    local lines = {}
    for s = 1, g.num_suits do
        local ranks = {}
        for _i, c in ipairs(g.discards) do if c.s == s then ranks[#ranks + 1] = c.r end end
        table.sort(ranks)
        lines[#lines + 1] = T(_("%1: %2"), self:suitName(s), #ranks > 0 and table.concat(ranks, " ") or "–")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = _("Copies of each card: three 1s, two 2s, two 3s, two 4s, one 5.")
    if g.variant == "black" then
        lines[#lines + 1] = T(_("%1: a single card of each rank."), self:suitName(Game.RAINBOW))
    end
    self:showText(_("Discard pile"), table.concat(lines, "\n"))
end

function FireworksScreen:showHistory()
    local g = self.game
    if not g then return end
    local lines = {}
    for _i, e in ipairs(g.log) do lines[#lines + 1] = T(_("%1. %2"), e.turn, self:entryText(e)) end
    if #lines == 0 then lines[1] = _("Nothing has happened yet.") end
    self:showText(_("History"), table.concat(lines, "\n"))
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function FireworksScreen:_titleBar()
    return self:buildTitleBar(_("Fireworks"), function()
        local items = {
            { text = _("New game"), callback = function() self:onNewGame() end },
            { text = T(_("Players: %1"), self.num_players), callback = function() self:openPlayersMenu() end },
            { text = T(_("Mode: %1"), self:modeLabel(self.solo)), callback = function() self:openModeMenu() end },
            { text = T(_("Variant: %1"), VARIANT_LABELS[self.variant]), callback = function() self:openVariantMenu() end },
            { text = _("Settings"), callback = function() self:openSettingsMenu() end },
            { text = _("Player names"), callback = function() self:openNamesMenu() end },
            { text = _("Tutorial"), callback = function() self:onTutorial() end },
        }
        if self.game then
            items[#items + 1] = { text = _("Discard pile"), callback = function() self:showDiscards() end }
            -- Clues and plays are public: the history shows nothing secret,
            -- even opened from the hand-over screen.
            items[#items + 1] = { text = _("History"), callback = function() self:showHistory() end }
        end
        items[#items + 1] = self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR)
        return items
    end)
end

function FireworksScreen:_buildControls(rows)
    self.status_text:setMaxWidth(self:getControlsWidth())
    return VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self:buildActionBar(rows),
    }
end

function FireworksScreen:_placeLayout(title_bar, content, controls)
    if self:isLandscape() then
        self:buildLandscapeLayout(title_bar, HorizontalGroup:new{
            align = "center",
            content,
            HorizontalSpan:new{ width = self:getGutter() },
            controls,
        })
    else
        self:buildPortraitLayout(title_bar, content,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
    end
end

function FireworksScreen:infoLine()
    local g = self.game
    local parts = {
        T(_("Clues: %1/%2"), g.tokens, Game.MAX_TOKENS),
        T(_("Fuses: %1/%2"), g.fuses, Game.MAX_FUSES),
        T(_("Deck: %1"), #g.deck),
        T(_("Score: %1"), g:stackTotal()),
    }
    return self:joinStatus((table.unpack or unpack)(parts))
end

function FireworksScreen:buildLayout()
    self.status_msg = nil
    if not self.game or self.phase == "setup" then
        self:_buildSetup()
    elseif self.phase == "handover" then
        self:_buildHandover()
    elseif self.phase == "over" or self.game.over then
        self.phase = "over"
        self:_buildTable(true)
    else
        self:_buildTable(false)
    end
    self[1] = self.layout
    self:updateStatus(self.status_msg)
end

function FireworksScreen:_shapesFor(variant)
    local shapes = {}
    for s = 1, variant == "none" and 5 or 6 do shapes[s] = s end
    if variant == "black" then shapes[6] = 7 end
    return shapes
end

function FireworksScreen:_buildSetup()
    local title_bar = self:_titleBar()
    local controls = self:_buildControls({ { text = _("Start game"), callback = function() self:onNewGame() end } })
    local bw, bh = self:getBoardBudget(title_bar, controls)
    local short = math.min(bw, bh)
    local vs = Size.span.vertical_large
    local names = {}
    if self.solo then
        names[1] = self:playerName(1)
        for i, n in ipairs(self:botNames(names[1], self.num_players - 1)) do names[i + 1] = T(_("%1 (AI)"), n) end
    else
        for i = 1, self.num_players do names[i] = self:playerName(i) end
    end
    local shapes = self:_shapesFor(self.variant)
    local legend_names = {}
    local all = self:suitNames(self.variant)
    for s = 1, #shapes do legend_names[s] = all[s] end
    local opts = { VARIANT_LABELS[self.variant] }
    if self.short then opts[#opts + 1] = _("short game") end
    if self.zero_on_fuses then opts[#opts + 1] = _("3rd fuse scores 0") end
    -- Landscape has a third of the height: smaller text, or the last lines fall off.
    local body = Font:getFace(self:isLandscape() and "smallinfofont" or "infofont")
    local land = self:isLandscape()
    local content = VerticalGroup:new{
        align = "center",
        fitLine(_("Fireworks"), short * 0.12, bw, true),
        VerticalSpan:new{ width = vs },
        wrapText(land and "" or _("Build the fireworks together — everyone sees every hand but their own."),
            body, bw),
        VerticalSpan:new{ width = land and 0 or vs * 2 },
        BoardWidget.SuitLegend:new{ width = bw, height = math.floor(math.min(bw / #shapes * 1.1, bh * 0.2)),
            shapes = shapes, names = legend_names },
        VerticalSpan:new{ width = vs * 2 },
        wrapText(table.concat({
            T(_("Players: %1"), table.concat(names, ", ")),
            T(_("Mode: %1"), self:modeLabel(self.solo)),
            T(_("Variant: %1"), table.concat(opts, ", ")),
        }, "\n"), body, bw),
        VerticalSpan:new{ width = vs * 2 },
        wrapText(_("New to the game? Try the Tutorial in the menu."), Font:getFace("smallinfofont"), bw),
    }
    self.status_msg = _("Settings are in the menu.")
    self:_placeLayout(title_bar, content, controls)
end

function FireworksScreen:_buildHandover()
    local g = self.game
    local p = g.current
    local name = g.players[p].name
    local title_bar = self:_titleBar()
    local button = self.solo_game and _("Continue") or T(_("I'm %1: show my turn"), name)
    local controls = self:_buildControls({ { text = button, callback = function() self:onReady() end } })
    local bw, bh = self:getBoardBudget(title_bar, controls)
    local short = math.min(bw, bh)
    local vs = Size.span.vertical_large

    local entries = g:entriesSince(p)
    local lines = {}
    for _i, e in ipairs(entries) do lines[#lines + 1] = "• " .. self:entryText(e) end
    local log_text = #lines > 0 and table.concat(lines, "\n") or _("The game begins. Good luck!")
    local frame_pad = Size.padding.large
    local inner_w = bw - 2 * (frame_pad + Size.border.window)
    local log_face = pxFace(math.min(short * 0.045, 40))
    local log_box = FrameContainer:new{
        padding = frame_pad, margin = 0,
        VerticalGroup:new{
            align = "left",
            fitLine(#lines > 0 and _("Since your last turn:") or _("New game"), short * 0.045, inner_w, true),
            VerticalSpan:new{ width = vs },
            wrapText(log_text, log_face, inner_w, "left"),
        },
    }
    local heading = self.solo_game and T(_("Your turn, %1"), name) or T(_("Pass the reader to %1"), name)
    local content = VerticalGroup:new{
        align = "center",
        fitLine(heading, short * 0.08, bw, true),
        VerticalSpan:new{ width = vs },
        wrapText(self.solo_game and _("Tap to see the table.")
            or _("Tap when ready — nobody else should look."), Font:getFace("infofont"), bw),
        VerticalSpan:new{ width = vs * 2 },
        log_box,
        VerticalSpan:new{ width = vs },
        wrapText(self:infoLine(), Font:getFace("smallinfofont"), bw),
    }
    self.status_msg = ""
    self:_placeLayout(title_bar, BoardWidget.TapBox:new{ callback = function() self:onReady() end, content },
        controls)
end

function FireworksScreen:_overReason()
    local g = self.game
    local reason = ({
        fuses   = _("The third fuse burnt: the show is over."),
        perfect = _("Every firework is complete!"),
        deck    = _("The deck is empty and everyone has played."),
        short   = _("The deck is empty: the short game ends."),
    })[g.end_reason] or ""
    if g.end_reason == "fuses" and g.zero_on_fuses then
        reason = reason .. " " .. T(_("By the rule chosen, the %1 points built count for nothing."), g:stackTotal())
    end
    return reason
end

function FireworksScreen:_buildTable(over)
    local g = self.game
    local title_bar = self:_titleBar()
    local sel, pend = self.selected, self.pending
    local rows
    if over then
        rows = { { text = _("New game"), callback = function() self:onNewGame() end } }
    elseif pend then
        -- Two rows, like the normal bar, so the table doesn't move.
        rows = {
            { { text = _("Give this clue"), callback = function() self:onConfirmClue() end } },
            { { text = _("Cancel"), callback = function() self:onCancelClue() end } },
        }
    else
        local own = sel and sel.p == g.current
        local mate = sel and sel.p ~= g.current
        local card = mate and g.hands[sel.p][sel.slot]
        local rank_label, suit_label = _("Clue: rank"), _("Clue: shape")
        if card then
            rank_label = T(_("Clue: %1"), card.r)
            suit_label = (g.rainbow and card.s == Game.RAINBOW) and _("Clue: shape")
                or T(_("Clue: %1"), self:suitName(card.s))
        end
        rows = {
            {
                { text = _("Play"), enabled = own and true or false, callback = function() self:onPlay() end },
                { text = _("Discard"), enabled = (own and g:canDiscard()) and true or false,
                  callback = function() self:onDiscard() end },
            },
            {
                { text = suit_label, enabled = (mate and g:canClue()) and true or false,
                  callback = function() self:onSuitClue() end },
                { text = rank_label, enabled = (mate and g:canClue()) and true or false,
                  callback = function() self:onRankClue() end },
            },
        }
    end
    local controls = self:_buildControls(rows)
    local bw, bh = self:getBoardBudget(title_bar, controls)

    -- Game over: the score, the verdict and why it ended, above the table.
    local heading
    if over then
        local short = math.min(bw, bh)
        heading = VerticalGroup:new{
            align = "center",
            fitLine(T(_("Score: %1/%2"), g:score(), g:maxScore()), short * 0.08, bw, true),
            wrapText(self:scoreLabel(), pxFace(short * 0.055), bw),
            wrapText(self:_overReason(), pxFace(short * 0.036), bw),
            VerticalSpan:new{ width = Size.span.vertical_large },
        }
        bh = bh - heading:getSize().h
    end

    self.board_widget = BoardWidget:new{
        width = bw, height = bh, game = g,
        viewer = g.current, reveal_all = over,
        selected = sel, preview = pend and { target = pend.target, slots = pend.slots } or nil,
        suit_names = self:suitNames(g.variant),
        labels = {
            you       = T(_("Your hand (%1)"), g.players[g.current].name),
            you_short = _("Your hand"),
            ai        = function(n) return T(_("%1 (AI)"), n) end,
            info      = self:infoLine(),
        },
        onCardTap = function(p, slot) self:onCardTap(p, slot) end,
    }

    if over then
        self.status_msg = ""
    elseif pend then
        local t = {}
        for i = 1, #g.hands[pend.target] do if pend.slots[i] then t[#t + 1] = i end end
        self.status_msg = T(_("Tell %1: %2?"), self:displayName(pend.target), self:clueText(pend.clue, t))
    elseif sel and sel.p == g.current then
        self.status_msg = T(_("Your card %1: play it or discard it?"), sel.slot)
    elseif sel then
        self.status_msg = T(_("Clue %1: shape or rank?"), self:displayName(sel.p))
    else
        local left = g.turns_left and T(_("Last round: %1 turns left"), g.turns_left) or nil
        self.status_msg = self:joinStatus(_("Tap a card to act."), left)
    end
    local content = self.board_widget
    if heading then content = VerticalGroup:new{ align = "center", heading, self.board_widget } end
    self:_placeLayout(title_bar, content, controls)
end

function FireworksScreen:updateStatus(msg)
    ScreenBase.updateStatus(self, msg or self.status_msg or "")
end

return FireworksScreen
