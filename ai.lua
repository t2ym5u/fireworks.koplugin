-- ---------------------------------------------------------------------------
-- Fireworks computer teammate (pure Lua)
--
-- A simple convention bot. It only reads what its seat may see: the other
-- hands, its own clue knowledge, stacks, discards and public play marks.
-- In order of preference:
--   1. play a card it knows is playable (count elimination included);
--   2. play a card marked "play" by a clue, if it can still be playable and
--      at most one fuse has burnt;
--   3. clue a teammate's playable card so that it becomes that clue's focus;
--   4. save a teammate's critical card on chop (a 5, or a last copy);
--   5. discard: known trash first, else the oldest unclued card;
--   6. with all 8 tokens (no discard allowed), give the least harmful clue.
-- Every action it returns is legal (Game:isLegal); see test_fireworks_spec.
-- ---------------------------------------------------------------------------

local AI = {}

local function nextSeats(game, p)
    local out = {}
    for k = 1, game.num_players - 1 do
        out[#out + 1] = (p - 1 + k) % game.num_players + 1
    end
    return out
end

-- Is identity (s, r) already being taken care of: a teammate (not p) holding
-- it with a play mark or full playable knowledge, other than `except` card?
local function alreadyCovered(game, p, s, r, except)
    for q = 1, game.num_players do
        if q ~= p then
            for _, c in ipairs(game.hands[q]) do
                if c ~= except and c.s == s and c.r == r then
                    if c.play or game:knownPlayable(game:knowledgeCandidates(c)) then return true end
                end
            end
        end
    end
    return false
end

-- Would a clue to `t` make card `card` (actually playable) get played?
-- Returns a score (higher is better) or nil when the clue doesn't do it, or
-- when it would also lead the receiver to misplay another card.
local function playClueScore(game, t, clue, card)
    local focus, play = game:interpretClue(t, clue)
    local hand = game.hands[t]
    local score = 0
    local target_ok = false
    for i, c in ipairs(hand) do
        local touched = game:touches(c, clue)
        local ks, kr = game:_knowledgeAfter(c, clue, touched)
        local cands = game:knowledgeCandidates({ ks = ks, kr = kr })
        local known_play = game:knownPlayable(cands)
        local was_known = game:knownPlayable(game:knowledgeCandidates(c))
        local marked = i == focus and play
        if c == card and (known_play or marked) then target_ok = true end
        -- A new mark or "known playable" landing on an unplayable card is a bomb.
        if (marked or (known_play and not was_known)) and not game:isPlayable(c.s, c.r) then
            return nil
        end
        if touched and not c.clued then
            if game:isPlayable(c.s, c.r) then score = score + 3
            elseif game:isTrash(c.s, c.r) then score = score - 2
            else score = score + 0.5 end
        end
        if c == card and known_play then score = score + 2 end
    end
    if not target_ok then return nil end
    return score
end

-- A save clue keeps the focus card (no play mark), and mustn't mark or
-- reveal-as-playable anything unplayable.
local function saveClueOk(game, t, clue, slot)
    local focus, play = game:interpretClue(t, clue)
    if focus ~= slot or play then return false end
    for _, c in ipairs(game.hands[t]) do
        local touched = game:touches(c, clue)
        local ks, kr = game:_knowledgeAfter(c, clue, touched)
        local was_known = game:knownPlayable(game:knowledgeCandidates(c))
        if not was_known and game:knownPlayable(game:knowledgeCandidates({ ks = ks, kr = kr }))
                and not game:isPlayable(c.s, c.r) then
            return false
        end
    end
    return true
end

local function cluesFor(game, card)
    local out = { { kind = "rank", v = card.r } }
    for _, s in ipairs(game:clueSuits()) do
        if game:suitMatches(card.s, s) then out[#out + 1] = { kind = "suit", v = s } end
    end
    return out
end

function AI.choose(game, p)
    local hand = game.hands[p]

    -- 1. Certain plays (lowest rank first: it unlocks more).
    local best_slot, best_r
    for i = 1, #hand do
        local cands = game:candidates(p, i)
        if game:knownPlayable(cands) then
            local r = cands[1].r
            if not best_r or r < best_r then best_slot, best_r = i, r end
        end
    end
    if best_slot then return { kind = "play", slot = best_slot } end

    -- 2. Play marks.
    if game.fuses <= 1 then
        for i = 1, #hand do
            if hand[i].play and game:maybePlayable(game:candidates(p, i)) then
                return { kind = "play", slot = i }
            end
        end
    end

    -- 3. Play clues, nearest teammate first.
    if game:canClue() then
        for _, t in ipairs(nextSeats(game, p)) do
            local best, best_score
            for _, c in ipairs(game.hands[t]) do
                if game:isPlayable(c.s, c.r) and not c.play
                        and not game:knownPlayable(game:knowledgeCandidates(c))
                        and not alreadyCovered(game, p, c.s, c.r, c) then
                    for _, clue in ipairs(cluesFor(game, c)) do
                        local sc = playClueScore(game, t, clue, c)
                        if sc and (not best_score or sc > best_score) then
                            best, best_score = { kind = "clue", target = t, clue = clue }, sc
                        end
                    end
                end
            end
            if best then return best end
        end

        -- 4. Saves, for the teammate who plays next only when they could
        -- discard (fewer than 8 tokens after this clue is always true).
        for k, t in ipairs(nextSeats(game, p)) do
            if k > 2 then break end
            local chop = game:chopSlot(t)
            local c = chop and game.hands[t][chop]
            if c and game:isCritical(c.s, c.r) and not game:isPlayable(c.s, c.r) then
                for _, clue in ipairs(cluesFor(game, c)) do
                    if saveClueOk(game, t, clue, chop) then
                        return { kind = "clue", target = t, clue = clue }
                    end
                end
            end
        end
    end

    -- 5. Discard.
    if game:canDiscard() then
        for i = #hand, 1, -1 do
            if game:knownTrash(game:candidates(p, i)) then return { kind = "discard", slot = i } end
        end
        local chop = game:chopSlot(p)
        if chop then return { kind = "discard", slot = chop } end
        for i = #hand, 1, -1 do
            if not hand[i].play then return { kind = "discard", slot = i } end
        end
        return { kind = "discard", slot = #hand }
    end

    -- 6. 8 tokens and nothing to play: the least harmful clue.
    local best, best_score
    for _, a in ipairs(game:legalClues(p)) do
        local t, clue = a.target, a.clue
        local focus, play = game:interpretClue(t, clue)
        local sc = 0
        for i, c in ipairs(game.hands[t]) do
            local touched = game:touches(c, clue)
            local ks, kr = game:_knowledgeAfter(c, clue, touched)
            local known_play = game:knownPlayable(game:knowledgeCandidates({ ks = ks, kr = kr }))
                and not game:knownPlayable(game:knowledgeCandidates(c))
            local marked = i == focus and play
            if (marked or known_play) and not game:isPlayable(c.s, c.r) then sc = sc - 100 end
            if touched and not c.clued then
                if game:isCritical(c.s, c.r) then sc = sc + 2
                elseif game:isTrash(c.s, c.r) then sc = sc - 1 end
            elseif touched then
                sc = sc + 1   -- fills in a clued card: no new card to protect
            end
        end
        if not best_score or sc > best_score then best, best_score = a, sc end
    end
    if best then return best end
    -- Unreachable with 8 tokens (some teammate holds a card), but stay legal.
    return { kind = "play", slot = 1 }
end

return AI
