local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

local Game = require("game")
local AI   = require("ai")

-- Deterministic RNG (LCG) so a failing seed can be replayed.
local function lcg(seed)
    local x = seed
    return function(n)
        x = (x * 1103515245 + 12345) % 2147483648
        return x % n + 1
    end
end

local function players(n, ai)
    local t = {}
    for i = 1, n do t[i] = { name = "P" .. i, ai = ai } end
    return t
end

-- Put a known card list on top of the deck (last element is drawn first).
local function newGameWith(n, opts)
    local g = Game.new{ players = players(n, true), rainbow = opts and opts.rainbow, rng = lcg(1) }
    return g
end

local function cardCount(g)
    local n = #g.deck + #g.discards
    for p = 1, g.num_players do n = n + #g.hands[p] end
    for s = 1, g.num_suits do n = n + g.stacks[s] end
    return n
end

describe("Fireworks game", function()
    it("builds the right deck", function()
        local g = Game.new{ players = players(3), rng = lcg(2) }
        assert.are.equal(50, cardCount(g))
        local counts = {}
        local function add(c) local k = c.s .. ":" .. c.r; counts[k] = (counts[k] or 0) + 1 end
        for _, c in ipairs(g.deck) do add(c) end
        for p = 1, 3 do for _, c in ipairs(g.hands[p]) do add(c) end end
        for s = 1, 5 do
            assert.are.equal(3, counts[s .. ":1"]); assert.are.equal(2, counts[s .. ":2"])
            assert.are.equal(2, counts[s .. ":3"]); assert.are.equal(2, counts[s .. ":4"])
            assert.are.equal(1, counts[s .. ":5"])
        end
        local rg = Game.new{ players = players(2), rainbow = true, rng = lcg(3) }
        assert.are.equal(60, cardCount(rg))
        assert.are.equal(30, rg:maxScore())
    end)

    it("deals 5 cards to 2-3 players and 4 to 4-5", function()
        for n = 2, 5 do
            local g = Game.new{ players = players(n), rng = lcg(n) }
            for p = 1, n do assert.are.equal(n <= 3 and 5 or 4, #g.hands[p]) end
        end
    end)

    it("starts with 8 tokens and 0 fuses", function()
        local g = Game.new{ players = players(2), rng = lcg(4) }
        assert.are.equal(8, g.tokens); assert.are.equal(0, g.fuses)
    end)

    it("forbids discarding at 8 tokens and clueing at 0", function()
        local g = Game.new{ players = players(2), rng = lcg(5) }
        assert.is_false(g:isLegal(1, { kind = "discard", slot = 1 }))
        g.tokens = 0
        assert.are.equal(0, #g:legalClues(1))
        assert.is_false(g:isLegal(1, { kind = "clue", target = 2, clue = { kind = "rank", v = g.hands[2][1].r } }))
    end)

    it("rejects clues that touch nothing, self-clues and the rainbow suit", function()
        local g = Game.new{ players = players(2), rainbow = true, rng = lcg(6) }
        local hand = g.hands[2]
        local present = {}
        for _, c in ipairs(hand) do present[c.r] = true end
        for r = 1, 5 do
            assert.are.equal(present[r] or false,
                g:isLegal(1, { kind = "clue", target = 2, clue = { kind = "rank", v = r } }))
        end
        assert.is_false(g:isLegal(1, { kind = "clue", target = 1, clue = { kind = "rank", v = g.hands[1][1].r } }))
        assert.is_false(g:isLegal(1, { kind = "clue", target = 2, clue = { kind = "suit", v = 6 } }))
        assert.is_false(g:isLegal(2, { kind = "play", slot = 1 }))   -- not their turn
    end)

    it("updates positive and negative knowledge, rainbow touched by every suit clue", function()
        local g = Game.new{ players = players(2), rainbow = true, rng = lcg(7) }
        g.hands[2] = {}
        for _, id in ipairs({ { 1, 3 }, { 6, 2 }, { 2, 3 }, { 3, 1 } }) do
            local c = { s = id[1], r = id[2] }
            g:_freshKnowledge(c)
            g.hands[2][#g.hands[2] + 1] = c
        end
        local e = g:apply({ kind = "clue", target = 2, clue = { kind = "suit", v = 1 } })
        assert.are.same({ 1, 2 }, e.slots)
        local h = g.hands[2]
        assert.is_true(h[1].ks[1] and h[1].ks[6]); assert.is_false(h[1].ks[2])
        assert.is_true(h[2].ks[1] and h[2].ks[6])
        assert.is_false(h[3].ks[1]); assert.is_false(h[3].ks[6]); assert.is_true(h[3].ks[2])
        assert.are.equal(7, g.tokens)
        g:apply({ kind = "play", slot = 1 })    -- player 2 plays whatever it is
        g:apply({ kind = "clue", target = 2, clue = { kind = "rank", v = 3 } })
        -- After player 2's play a new card sits in slot 1; old slots shift.
        local after = g.hands[2]
        for _, c in ipairs(after) do
            if c.r == 3 then assert.are.equal(3, g:knownRank(c))
            else assert.is_false(c.kr[3]) end
        end
    end)

    it("plays, misfires and regains a token on a 5", function()
        local g = Game.new{ players = players(2), rng = lcg(8) }
        g.hands[1][1] = { s = 2, r = 1 }; g:_freshKnowledge(g.hands[1][1])
        local e = g:apply({ kind = "play", slot = 1 })
        assert.is_true(e.ok); assert.are.equal(1, g.stacks[2])
        g.hands[2][1] = { s = 2, r = 3 }; g:_freshKnowledge(g.hands[2][1])
        e = g:apply({ kind = "play", slot = 1 })
        assert.is_false(e.ok); assert.are.equal(1, g.fuses); assert.are.equal(1, #g.discards)
        g.stacks[4] = 4; g.tokens = 5
        g.hands[1][1] = { s = 4, r = 5 }; g:_freshKnowledge(g.hands[1][1])
        e = g:apply({ kind = "play", slot = 1 })
        assert.is_true(e.ok and e.bonus); assert.are.equal(6, g.tokens)
    end)

    it("ends on the third fuse", function()
        local g = Game.new{ players = players(2), rng = lcg(9) }
        for _ = 1, 3 do
            g.hands[g.current][1] = { s = 1, r = 5 }; g:_freshKnowledge(g.hands[g.current][1])
            g:apply({ kind = "play", slot = 1 })
        end
        assert.is_true(g.over); assert.are.equal("fuses", g.end_reason)
        assert.is_nil(g:apply({ kind = "play", slot = 1 }))
    end)

    it("ends when every stack is complete", function()
        local g = Game.new{ players = players(2), rng = lcg(10) }
        for s = 1, 5 do g.stacks[s] = 5 end
        g.stacks[3] = 4
        g.hands[1][1] = { s = 3, r = 5 }; g:_freshKnowledge(g.hands[1][1])
        g:apply({ kind = "play", slot = 1 })
        assert.is_true(g.over); assert.are.equal("perfect", g.end_reason)
        assert.are.equal(25, g:score()); assert.are.equal(6, g:scoreBand())
    end)

    it("gives everyone exactly one more turn after the last card", function()
        local g = Game.new{ players = players(3), rng = lcg(11) }
        g.tokens = 7
        while #g.deck > 1 do table.remove(g.deck) end
        local drawer = g.current
        g:apply({ kind = "discard", slot = 1 })
        assert.are.equal(0, #g.deck); assert.are.equal(3, g.turns_left)
        local turns = 0
        while not g.over do
            g.tokens = math.min(g.tokens, 7)
            g:apply({ kind = "discard", slot = 1 })
            turns = turns + 1
        end
        assert.are.equal(3, turns)
        assert.are.equal("deck", g.end_reason)
        assert.are.equal(drawer, g.log[#g.log].p)   -- the drawer had the final turn
    end)

    it("scores the sum of the stacks with bands", function()
        local g = Game.new{ players = players(2), rng = lcg(12) }
        g.stacks = { 5, 5, 3, 2, 0 }
        assert.are.equal(15, g:score()); assert.are.equal(3, g:scoreBand())
        g.stacks = { 0, 1, 0, 0, 0 }; assert.are.equal(1, g:scoreBand())
        g.stacks = { 5, 5, 5, 5, 4 }; assert.are.equal(5, g:scoreBand())
    end)

    it("knows trash and critical cards", function()
        local g = Game.new{ players = players(2), rng = lcg(13) }
        g.stacks[1] = 2
        assert.is_true(g:isTrash(1, 2)); assert.is_false(g:isTrash(1, 3))
        assert.is_true(g:isCritical(1, 5))
        g.discards = { { s = 2, r = 2 }, { s = 2, r = 2 } }
        assert.is_true(g:isTrash(2, 4))     -- no 2 left: 3, 4, 5 unreachable
        g.discards[#g.discards + 1] = { s = 3, r = 4 }
        assert.is_true(g:isCritical(3, 4))
    end)

    it("builds each variant's 6th suit", function()
        local b = Game.new{ players = players(2), variant = "black", rng = lcg(31) }
        assert.are.equal(55, cardCount(b)); assert.are.equal(30, b:maxScore())
        assert.are.equal(1, b:copies(6, 1)); assert.are.equal(7, b:shapeOf(6))
        assert.is_true(b:isCritical(6, 1))           -- single copies: all critical
        local s6 = Game.new{ players = players(2), variant = "sixth", rng = lcg(32) }
        assert.are.equal(60, cardCount(s6)); assert.are.equal(6, #s6:clueSuits())
        local c = { s = 6, r = 2 }
        assert.is_false(s6:touches(c, { kind = "suit", v = 1 }))
        assert.is_true(s6:touches(c, { kind = "suit", v = 6 }))
        local rb = Game.new{ players = players(2), variant = "rainbow", rng = lcg(33) }
        assert.are.equal(5, #rb:clueSuits())
        assert.is_true(rb:touches(c, { kind = "suit", v = 1 }))
        -- old saves stored rainbow = true
        assert.are.equal("rainbow", Game.new{ players = players(2), rainbow = true }.variant)
    end)

    it("lets a named 6th suit be clued only when it isn't wild", function()
        for _, v in ipairs({ "sixth", "black" }) do
            local g = Game.new{ players = players(2), variant = v, rng = lcg(34) }
            local card = g.hands[2][1]
            card.s = 6
            assert.is_true(g:isLegal(1, { kind = "clue", target = 2, clue = { kind = "suit", v = 6 } }))
        end
    end)

    it("ends a short game as soon as the last card is drawn", function()
        local g = Game.new{ players = players(3), short = true, rng = lcg(35) }
        g.tokens = 7
        while #g.deck > 1 do table.remove(g.deck) end
        g:apply({ kind = "discard", slot = 1 })
        assert.is_true(g.over); assert.are.equal("short", g.end_reason)
    end)

    it("scores 0 on the third fuse with that rule, the stacks otherwise", function()
        for _, zero in ipairs({ true, false }) do
            local g = Game.new{ players = players(2), zero_on_fuses = zero, rng = lcg(36) }
            g.stacks[1] = 3
            for _ = 1, 3 do
                g.hands[g.current][1] = { s = 2, r = 5 }; g:_freshKnowledge(g.hands[g.current][1])
                g:apply({ kind = "play", slot = 1 })
            end
            assert.are.equal(zero and 0 or 3, g:score()); assert.are.equal(3, g:stackTotal())
        end
    end)

    it("deals a rigged top of the deck in order", function()
        local top = { { s = 1, r = 1 }, { s = 2, r = 1 }, { s = 1, r = 1 }, { s = 3, r = 5 } }
        local g = Game.new{ players = players(2), top = top, rng = lcg(37) }
        -- player 1 draws first, newest card in slot 1
        local h = g.hands[1]
        assert.are.same({ 3, 5 }, { h[2].s, h[2].r })
        assert.are.same({ 1, 1 }, { h[5].s, h[5].r })
        assert.are.same({ 2, 1 }, { h[4].s, h[4].r })
        assert.are.equal(50, cardCount(g))
    end)

    it("round-trips through serialize/load", function()
        local g = Game.new{ players = players(4, true), variant = "black", short = true,
            zero_on_fuses = true, rng = lcg(14) }
        for _ = 1, 10 do g:apply(AI.choose(g, g.current)) end
        local data = g:serialize()
        assert.are.equal("black", Game.load(data).variant)
        assert.is_true(Game.load(data).short and Game.load(data).zero_on_fuses)
        local g2 = Game.load(data)
        assert.are.same(data, g2:serialize())
        assert.is_nil(Game.load({ v = 2 }))
        assert.is_nil(Game.load(nil))
    end)

    it("lists the entries since a player's last turn", function()
        local g = Game.new{ players = players(3, true), rng = lcg(15) }
        for _ = 1, 5 do g:apply(AI.choose(g, g.current)) end
        local since = g:entriesSince(g.current)
        assert.are.equal(2, #since)
    end)
end)

describe("Fireworks verdicts", function()
    it("has at least 10 verdicts per score band, in English and French", function()
        for _, lang in ipairs({ "en", "fr" }) do
            local t = dofile(DIR .. "labels_" .. lang .. ".lua")
            assert.are.equal(6, #t)
            for band = 1, 6 do assert.is_true(#t[band] >= 10, lang .. " band " .. band) end
        end
    end)
end)

describe("Fireworks AI", function()
    local function runGame(n, seed, variant, short)
        local g = Game.new{ players = players(n, true), variant = variant or "none", short = short, rng = lcg(seed) }
        local steps = 0
        while not g.over do
            local a = AI.choose(g, g.current)
            assert.is_true(g:isLegal(g.current, a), "illegal action at seed " .. seed)
            assert.is_truthy(g:apply(a))
            steps = steps + 1
            assert.is_true(steps < 200)
            assert.are.equal(g.variant == "black" and 55 or g.num_suits * 10, cardCount(g))
        end
        return g
    end

    it("never makes an illegal move and keeps every card, 2-5 players, every variant", function()
        for _, v in ipairs(Game.VARIANTS) do
            for n = 2, 5 do
                for seed = 1, 20 do
                    local g = runGame(n, seed * 7 + n, v, seed % 4 == 0)
                    assert.is_true(g:score() >= 0 and g:score() <= g:maxScore())
                end
            end
        end
    end)

    it("reports average scores per variant", function()
        for _, v in ipairs(Game.VARIANTS) do
            local total, bombs = 0, 0
            for seed = 1, 60 do
                local g = runGame(3, seed, v)
                total = total + g:score()
                if g.end_reason == "fuses" then bombs = bombs + 1 end
            end
            print(string.format("\n  %-8s 3p bots: avg %.1f / %d, %d/60 lost to fuses", v, total / 60,
                v == "none" and 25 or 30, bombs))
            assert.is_true(total / 60 >= 10)
        end
    end)

    it("scores reasonably as an all-bot team", function()
        local total, games, bombs = 0, 0, 0
        for seed = 1, 100 do
            local g = runGame(3, seed, "none")
            total = total + g:score(); games = games + 1
            if g.end_reason == "fuses" then bombs = bombs + 1 end
        end
        local avg = total / games
        print(string.format("\n  all-bot 3p average score %.1f, %d/100 games lost to fuses", avg, bombs))
        assert.is_true(avg >= 12)
    end)

    it("plays a card it knows is playable", function()
        local g = Game.new{ players = players(2, true), rng = lcg(20) }
        local c = g.hands[1][3]
        c.s, c.r = 2, 1
        for s = 1, 5 do c.ks[s] = (s == 2) end
        for r = 1, 5 do c.kr[r] = (r == 1) end
        assert.are.same({ kind = "play", slot = 3 }, AI.choose(g, 1))
    end)

    it("does not discard at 8 tokens", function()
        for seed = 30, 60 do
            local g = Game.new{ players = players(2, true), rng = lcg(seed) }
            local a = AI.choose(g, 1)
            assert.are_not.equal("discard", a.kind)
        end
    end)
end)
