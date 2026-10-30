-- ---------------------------------------------------------------------------
-- Fireworks rules engine (pure Lua, no UI)
--
-- A cooperative hidden-hand card game: 5 suits (6 with a variant), ranks 1-5
-- (three 1s, two 2s/3s/4s, one 5 per suit).
--
-- Variants (opts.variant), all adding a 6th suit:
--   "rainbow" -- wild: every shape clue touches it, it can't be named (10 cards)
--   "sixth"   -- rainbow as its own colour, named like any other (10 cards)
--   "black"   -- a single copy of each rank (5 cards): every card is critical
-- Options: opts.short (the game ends as soon as the last card is drawn),
-- opts.zero_on_fuses (the 3rd fuse scores 0, as in some editions). Players see every hand
-- but their own and build each suit's stack from 1 to 5 together.
--
-- Hands are ordered newest first: a drawn card goes to slot 1, so the last
-- slot holds the oldest card. Each card carries the public knowledge its
-- holder has from clues: ks[s] / kr[r] = "suit s / rank r is still possible".
--
-- Clue convention (what the computer teammates assume, and what they follow
-- when they clue): a clue's *focus* is the oldest-unclued card ("chop") if the
-- clue newly touches it, else the newest newly touched card. If the focus can
-- still be playable, it is marked "play" (card.play) -- the receiver should
-- play it; otherwise the clue is a save and the card is kept.
-- ---------------------------------------------------------------------------

local Game = {}
Game.__index = Game

Game.MAX_TOKENS  = 8
Game.MAX_FUSES   = 3
Game.RANK_COUNTS = { 3, 2, 2, 2, 1 }
Game.RAINBOW     = 6       -- suit index of the 6th suit (variants only)
Game.VARIANTS    = { "none", "rainbow", "sixth", "black" }

local MAX_TOKENS, MAX_FUSES, RANK_COUNTS = Game.MAX_TOKENS, Game.MAX_FUSES, Game.RANK_COUNTS

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

local function handSizeFor(n)
    return n <= 3 and 5 or 4
end
Game.handSizeFor = handSizeFor

local function normVariant(v, rainbow)
    for _, id in ipairs(Game.VARIANTS) do if id == v then return v end end
    return rainbow and "rainbow" or "none"
end

function Game:_setVariant(variant, opts)
    self.variant   = variant
    self.rainbow   = variant == "rainbow"      -- the wild suit
    self.num_suits = variant == "none" and 5 or 6
    self.short     = opts.short and true or false
    self.zero_on_fuses = opts.zero_on_fuses and true or false
end

-- opts: { players = { { name =, ai = bool }, ... }, variant = id, short = bool,
--         zero_on_fuses = bool, rng = fn(n) -> 1..n,
--         top = { {s=,r=}, ... } -- cards dealt first, in order (tutorial) }
function Game.new(opts)
    local self = setmetatable({}, Game)
    self.rng     = opts.rng or math.random
    self:_setVariant(normVariant(opts.variant, opts.rainbow), opts)
    self.players = {}
    for i, p in ipairs(opts.players) do
        self.players[i] = { name = p.name or ("P" .. i), ai = p.ai and true or false }
    end
    self.num_players = #self.players
    assert(self.num_players >= 2 and self.num_players <= 5, "2-5 players")
    self.hand_size = handSizeFor(self.num_players)

    self.deck = {}
    local id = 0
    for s = 1, self.num_suits do
        for r = 1, 5 do
            for _ = 1, self:copies(s, r) do
                id = id + 1
                self.deck[#self.deck + 1] = { s = s, r = r, id = id }
            end
        end
    end
    for i = #self.deck, 2, -1 do
        local j = self.rng(i)
        self.deck[i], self.deck[j] = self.deck[j], self.deck[i]
    end
    -- Rigged top of the deck: the first card listed is drawn first (cards
    -- are drawn from the end of the list).
    if opts.top then
        local moved = 0
        for k = #opts.top, 1, -1 do
            local want = opts.top[k]
            for i = 1, #self.deck - moved do
                local c = self.deck[i]
                if c.s == want.s and c.r == want.r then
                    table.remove(self.deck, i)
                    self.deck[#self.deck + 1] = c
                    moved = moved + 1
                    break
                end
            end
        end
    end

    self.stacks = {}
    for s = 1, self.num_suits do self.stacks[s] = 0 end
    self.discards = {}
    self.tokens   = MAX_TOKENS
    self.fuses    = 0
    self.current  = 1
    self.turn     = 1
    self.turns_left = nil   -- set when the deck runs out: turns left in the game
    self.over     = false
    self.end_reason = nil   -- "fuses" | "perfect" | "deck"
    self.log      = {}

    self.hands = {}
    for p = 1, self.num_players do
        self.hands[p] = {}
        for _ = 1, self.hand_size do self:_draw(p) end
    end
    return self
end

function Game:_freshKnowledge(card)
    card.ks, card.kr = {}, {}
    for s = 1, self.num_suits do card.ks[s] = true end
    for r = 1, 5 do card.kr[r] = true end
    card.clued, card.play = false, false
end

function Game:_draw(p)
    local card = table.remove(self.deck)
    if not card then return false end
    self:_freshKnowledge(card)
    table.insert(self.hands[p], 1, card)
    return true
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

function Game:maxScore()
    return 5 * self.num_suits
end

-- Sum of the stacks.
function Game:stackTotal()
    local n = 0
    for s = 1, self.num_suits do n = n + self.stacks[s] end
    return n
end

-- The score: the stacks, or 0 after the 3rd fuse with that rule on.
function Game:score()
    if self.over and self.end_reason == "fuses" and self.zero_on_fuses then return 0 end
    return self:stackTotal()
end

-- Copies of (s, r) in the deck.
function Game:copies(s, r)
    if s == Game.RAINBOW and self.variant == "black" then return 1 end
    return RANK_COUNTS[r]
end

-- Which drawn shape a suit uses: 1-5, 6 (rainbow arcs) or 7 (black hexagon).
function Game:shapeOf(s)
    if s == Game.RAINBOW and self.variant == "black" then return 7 end
    return s
end

function Game:isPlayable(s, r)
    return self.stacks[s] == r - 1
end

function Game:totalCopies(r, s)
    return self:copies(s or 1, r)
end

function Game:discardedCount(s, r)
    local n = 0
    for _, c in ipairs(self.discards) do
        if c.s == s and c.r == r then n = n + 1 end
    end
    return n
end

-- Already played, or unreachable because every copy of a lower rank is gone.
function Game:isTrash(s, r)
    if self.stacks[s] >= r then return true end
    for lower = self.stacks[s] + 1, r - 1 do
        if self:discardedCount(s, lower) >= self:copies(s, lower) then return true end
    end
    return false
end

-- The last copy still in play of a card the stacks still need.
function Game:isCritical(s, r)
    return not self:isTrash(s, r) and self:discardedCount(s, r) == self:copies(s, r) - 1
end

-- Suit values a player can name in a clue. The rainbow suit can't be named:
-- every suit clue touches its cards.
function Game:clueSuits()
    local t = {}
    for s = 1, self.rainbow and 5 or self.num_suits do t[#t + 1] = s end
    return t
end

function Game:suitMatches(card_suit, clue_suit)
    return card_suit == clue_suit or (self.rainbow and card_suit == Game.RAINBOW)
end

function Game:touches(card, clue)
    if clue.kind == "rank" then return card.r == clue.v end
    return self:suitMatches(card.s, clue.v)
end

-- Slots of `target`'s hand a clue would touch.
function Game:touchedSlots(target, clue)
    local slots = {}
    for i, c in ipairs(self.hands[target]) do
        if self:touches(c, clue) then slots[#slots + 1] = i end
    end
    return slots
end

function Game:chopSlot(p)
    local hand = self.hands[p]
    for i = #hand, 1, -1 do
        if not hand[i].clued then return i end
    end
    return nil
end

-- Identities (s, r) a card's knowledge still allows, ignoring card counts.
function Game:knowledgeCandidates(card)
    local out = {}
    for s = 1, self.num_suits do
        if card.ks[s] then
            for r = 1, 5 do
                if card.kr[r] then out[#out + 1] = { s = s, r = r } end
            end
        end
    end
    return out
end

-- Copies of (s, r) player `viewer` can't account for: not played, not
-- discarded, not in a hand the viewer can see.
function Game:unseenCount(viewer, s, r)
    local n = self:copies(s, r) - self:discardedCount(s, r)
    if self.stacks[s] >= r then n = n - 1 end
    for p = 1, self.num_players do
        if p ~= viewer then
            for _, c in ipairs(self.hands[p]) do
                if c.s == s and c.r == r then n = n - 1 end
            end
        end
    end
    return n
end

-- Knowledge candidates of `viewer`'s own card in `slot`, minus identities
-- with no copy left that the viewer can't see.
function Game:candidates(viewer, slot)
    local card = self.hands[viewer][slot]
    local out = {}
    for _, id in ipairs(self:knowledgeCandidates(card)) do
        if self:unseenCount(viewer, id.s, id.r) > 0 then out[#out + 1] = id end
    end
    if #out == 0 then return self:knowledgeCandidates(card) end
    return out
end

local function allOf(list, pred)
    if #list == 0 then return false end
    for _, x in ipairs(list) do if not pred(x) then return false end end
    return true
end

local function anyOf(list, pred)
    for _, x in ipairs(list) do if pred(x) then return true end end
    return false
end
Game._allOf, Game._anyOf = allOf, anyOf

function Game:knownPlayable(cands)
    return allOf(cands, function(id) return self:isPlayable(id.s, id.r) end)
end

function Game:knownTrash(cands)
    return allOf(cands, function(id) return self:isTrash(id.s, id.r) end)
end

function Game:maybePlayable(cands)
    return anyOf(cands, function(id) return self:isPlayable(id.s, id.r) end)
end

-- The known suit / rank of a card, or nil.
function Game:knownSuit(card)
    local found
    for s = 1, self.num_suits do
        if card.ks[s] then
            if found then return nil end
            found = s
        end
    end
    return found
end

function Game:knownRank(card)
    local found
    for r = 1, 5 do
        if card.kr[r] then
            if found then return nil end
            found = r
        end
    end
    return found
end

-- ---------------------------------------------------------------------------
-- Legality
-- ---------------------------------------------------------------------------

function Game:canClue()
    return not self.over and self.tokens > 0
end

function Game:canDiscard()
    return not self.over and self.tokens < MAX_TOKENS
end

function Game:isLegal(p, action)
    if self.over or p ~= self.current or type(action) ~= "table" then return false end
    if action.kind == "play" or action.kind == "discard" then
        local slot = action.slot
        if type(slot) ~= "number" or not self.hands[p][slot] then return false end
        return action.kind == "play" or self:canDiscard()
    elseif action.kind == "clue" then
        local t, clue = action.target, action.clue
        if not self:canClue() or type(t) ~= "number" or t == p or not self.hands[t] then return false end
        if type(clue) ~= "table" or type(clue.v) ~= "number" then return false end
        if clue.kind == "rank" then
            if clue.v < 1 or clue.v > 5 then return false end
        elseif clue.kind == "suit" then
            if clue.v < 1 or clue.v > #self:clueSuits() then return false end
        else
            return false
        end
        return #self:touchedSlots(t, clue) > 0
    end
    return false
end

-- Every clue `p` may give right now.
function Game:legalClues(p)
    local out = {}
    if not self:canClue() then return out end
    for t = 1, self.num_players do
        if t ~= p then
            for r = 1, 5 do
                local clue = { kind = "rank", v = r }
                if #self:touchedSlots(t, clue) > 0 then out[#out + 1] = { kind = "clue", target = t, clue = clue } end
            end
            for _, s in ipairs(self:clueSuits()) do
                local clue = { kind = "suit", v = s }
                if #self:touchedSlots(t, clue) > 0 then out[#out + 1] = { kind = "clue", target = t, clue = clue } end
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Clue knowledge
-- ---------------------------------------------------------------------------

-- Knowledge a card would have after a clue (touched or not), as new ks/kr
-- tables; doesn't modify the card.
function Game:_knowledgeAfter(card, clue, touched)
    local ks, kr = {}, {}
    for s = 1, self.num_suits do ks[s] = card.ks[s] end
    for r = 1, 5 do kr[r] = card.kr[r] end
    if clue.kind == "rank" then
        for r = 1, 5 do
            if (r == clue.v) ~= touched then kr[r] = false end
        end
    else
        for s = 1, self.num_suits do
            if self:suitMatches(s, clue.v) ~= touched then ks[s] = false end
        end
    end
    return ks, kr
end

-- What a clue means under the convention: returns focus slot and whether the
-- focus gets a "play" mark. Pure (simulated on copies).
function Game:interpretClue(target, clue)
    local hand = self.hands[target]
    local chop = self:chopSlot(target)
    local newly = {}
    for i, c in ipairs(hand) do
        if self:touches(c, clue) and not c.clued then newly[#newly + 1] = i end
    end
    if #newly == 0 then return nil, false end
    local focus = newly[1]
    for _, i in ipairs(newly) do
        if i == chop then focus = chop end
    end
    local ks, kr = self:_knowledgeAfter(hand[focus], clue, true)
    local probe = { ks = ks, kr = kr }
    local play = self:maybePlayable(self:knowledgeCandidates(probe))
    return focus, play
end

-- Drop play marks that can no longer be right (every candidate is now
-- unplayable, e.g. the suit moved on).
function Game:_refreshMarks()
    for p = 1, self.num_players do
        for _, c in ipairs(self.hands[p]) do
            if c.play and not self:maybePlayable(self:knowledgeCandidates(c)) then
                c.play = false
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

-- Apply an action for the current player. Returns the log entry, or nil and
-- an error string if the action is illegal.
function Game:apply(action)
    local p = self.current
    if not self:isLegal(p, action) then return nil, "illegal" end
    local entry = { p = p, kind = action.kind, turn = self.turn }

    if action.kind == "clue" then
        local t, clue = action.target, { kind = action.clue.kind, v = action.clue.v }
        local focus, play = self:interpretClue(t, clue)
        local slots = {}
        for i, c in ipairs(self.hands[t]) do
            local touched = self:touches(c, clue)
            c.ks, c.kr = self:_knowledgeAfter(c, clue, touched)
            if touched then
                c.clued = true
                slots[#slots + 1] = i
            end
        end
        if focus and play then self.hands[t][focus].play = true end
        self.tokens = self.tokens - 1
        entry.target, entry.clue, entry.slots = t, clue, slots
    else
        local card = table.remove(self.hands[p], action.slot)
        entry.slot = action.slot
        entry.card = { s = card.s, r = card.r }
        if action.kind == "play" then
            if self:isPlayable(card.s, card.r) then
                self.stacks[card.s] = card.r
                entry.ok = true
                if card.r == 5 and self.tokens < MAX_TOKENS then
                    self.tokens = self.tokens + 1
                    entry.bonus = true
                end
            else
                self.fuses = self.fuses + 1
                self.discards[#self.discards + 1] = { s = card.s, r = card.r }
                entry.ok = false
            end
        else
            self.discards[#self.discards + 1] = { s = card.s, r = card.r }
            self.tokens = self.tokens + 1
        end
        entry.drew = self:_draw(p)
    end

    self:_refreshMarks()
    self.log[#self.log + 1] = entry
    self:_endTurn(entry)
    return entry
end

function Game:_endTurn(entry)
    if self.fuses >= MAX_FUSES then
        self.over, self.end_reason = true, "fuses"
    elseif self:stackTotal() == self:maxScore() then
        self.over, self.end_reason = true, "perfect"
    elseif self.turns_left then
        self.turns_left = self.turns_left - 1
        if self.turns_left <= 0 then self.over, self.end_reason = true, "deck" end
    elseif entry.drew and #self.deck == 0 and self.short then
        -- Short game: no last round.
        self.over, self.end_reason = true, "short"
        entry.last_card = true
    elseif entry.drew and #self.deck == 0 then
        -- The last card was just drawn: everyone, this player included,
        -- gets one more turn.
        self.turns_left = self.num_players
        entry.last_card = true
    end
    if not self.over then
        self.current = self.current % self.num_players + 1
        self.turn = self.turn + 1
    end
end

-- Log entries since `p` last acted (what p has to catch up on), oldest first.
function Game:entriesSince(p)
    local out = {}
    for i = #self.log, 1, -1 do
        local e = self.log[i]
        if e.p == p then break end
        table.insert(out, 1, e)
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Save / restore
-- ---------------------------------------------------------------------------

local function copyCard(c)
    local o = { s = c.s, r = c.r, id = c.id, clued = c.clued or nil, play = c.play or nil }
    if c.ks then
        o.ks, o.kr = {}, {}
        for k, v in pairs(c.ks) do o.ks[k] = v end
        for k, v in pairs(c.kr) do o.kr[k] = v end
    end
    return o
end

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = deepCopy(v) end
    return o
end

function Game:serialize()
    local hands = {}
    for p, h in ipairs(self.hands) do
        hands[p] = {}
        for i, c in ipairs(h) do hands[p][i] = copyCard(c) end
    end
    local deck = {}
    for i, c in ipairs(self.deck) do deck[i] = { s = c.s, r = c.r, id = c.id } end
    return {
        v = 1,
        players = deepCopy(self.players),
        variant = self.variant, short = self.short or nil, zero_on_fuses = self.zero_on_fuses or nil,
        label_pick = self.label_pick,
        deck = deck, hands = hands,
        stacks = deepCopy(self.stacks), discards = deepCopy(self.discards),
        tokens = self.tokens, fuses = self.fuses,
        current = self.current, turn = self.turn, turns_left = self.turns_left,
        over = self.over, end_reason = self.end_reason,
        log = deepCopy(self.log),
    }
end

-- Rebuild a game from serialize() output; nil if the data doesn't look right.
function Game.load(data, rng)
    if type(data) ~= "table" or data.v ~= 1 or type(data.players) ~= "table"
            or type(data.hands) ~= "table" or type(data.deck) ~= "table"
            or type(data.stacks) ~= "table" then
        return nil
    end
    local n = #data.players
    if n < 2 or n > 5 or #data.hands ~= n then return nil end
    local self = setmetatable({}, Game)
    self.rng = rng or math.random
    self:_setVariant(normVariant(data.variant, data.rainbow), data)
    self.label_pick = tonumber(data.label_pick)
    self.players = {}
    for i, p in ipairs(data.players) do
        self.players[i] = { name = tostring(p.name or ("P" .. i)), ai = p.ai and true or false }
    end
    self.num_players = n
    self.hand_size = handSizeFor(n)
    self.deck = {}
    for i, c in ipairs(data.deck) do self.deck[i] = { s = c.s, r = c.r, id = c.id } end
    self.hands = {}
    for p = 1, n do
        self.hands[p] = {}
        for i, c in ipairs(data.hands[p] or {}) do
            local card = copyCard(c)
            card.clued, card.play = c.clued and true or false, c.play and true or false
            if not card.ks then self:_freshKnowledge(card) end
            for s = 1, self.num_suits do card.ks[s] = card.ks[s] and true or false end
            for r = 1, 5 do card.kr[r] = card.kr[r] and true or false end
            self.hands[p][i] = card
        end
    end
    self.stacks = {}
    for s = 1, self.num_suits do self.stacks[s] = tonumber(data.stacks[s]) or 0 end
    self.discards = deepCopy(data.discards or {})
    self.tokens = tonumber(data.tokens) or MAX_TOKENS
    self.fuses  = tonumber(data.fuses) or 0
    self.current = math.max(1, math.min(n, tonumber(data.current) or 1))
    self.turn = tonumber(data.turn) or 1
    self.turns_left = tonumber(data.turns_left)
    self.over = data.over and true or false
    self.end_reason = data.end_reason
    self.log = deepCopy(data.log or {})
    return self
end

-- Score label bands (index into the screen's label list).
function Game:scoreBand()
    local s = self:score()
    if self.over and s == 0 then return 1 end
    if s >= self:maxScore() then return 6 end
    if s <= 5 then return 1 elseif s <= 10 then return 2 elseif s <= 15 then return 3
    elseif s <= 20 then return 4 end
    return 5
end

return Game
