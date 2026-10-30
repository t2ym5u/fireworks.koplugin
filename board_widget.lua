-- ---------------------------------------------------------------------------
-- Fireworks table widget: the stacks, the info line and every hand, painted
-- in one widget so a tap maps straight to (player, slot).
--
-- Suits are told apart without colour: each has a vector shape (drawn here,
-- not a font glyph, so it looks the same with any font) and a name.
-- ---------------------------------------------------------------------------

local Blitbuffer     = require("ffi/blitbuffer")
local Device         = require("device")
local Font           = require("ui/font")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local UIManager      = require("ui/uimanager")

local DeviceScreen = Device.screen

local C_INK   = Blitbuffer.COLOR_BLACK
local C_BG    = Blitbuffer.COLOR_WHITE
local C_GRAY  = Blitbuffer.COLOR_GRAY
local C_HIDE  = Blitbuffer.COLOR_GRAY_E     -- own (hidden) cards
local C_DIM   = Blitbuffer.COLOR_GRAY_5

-- ---------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------

-- Font:getFace() scales by DPI; sizes here are worked out in pixels.
local DPI_SCALE = DeviceScreen:scaleBySize(1000) / 1000
local face_cache = {}

local function pxFace(px, bold)
    local size = math.max(6, math.floor(px / DPI_SCALE))
    local key = (bold and "b" or "r") .. size
    if not face_cache[key] then
        face_cache[key] = Font:getFace(bold and "tfont" or "cfont", size)
    end
    return face_cache[key]
end

-- Largest face up to `px` pixels whose text fits `max_w`.
local function fitFace(text, px, max_w, bold)
    px = math.floor(px)
    local face = pxFace(px, bold)
    while px > 8 do
        local m = RenderText:sizeUtf8Text(0, max_w * 10, face, text, true, false)
        if m.x <= max_w then break end
        px = math.floor(px * 0.9)
        face = pxFace(px, bold)
    end
    return face
end

-- Draw text centred on (cx, cy) (align "center") or starting at x = cx
-- (align "left"), shrunk to fit max_w.
local function drawText(bb, text, cx, cy, px, max_w, opts)
    opts = opts or {}
    local face = fitFace(text, px, max_w, opts.bold)
    local m = RenderText:sizeUtf8Text(0, max_w * 10, face, text, true, false)
    local x = opts.align == "left" and cx or (cx - math.floor(m.x / 2))
    local baseline = cy + math.floor((m.y_top - m.y_bottom) / 2)
    RenderText:renderUtf8Text(bb, x, baseline, face, text, true, false, opts.color or C_INK)
    return m.x
end

-- ---------------------------------------------------------------------------
-- Suit shapes
--
-- Each shape is a function of normalised coordinates (u, v in -1..1, v down)
-- returning nil (outside), 1 (ink) or 2 (grey). Painted as horizontal runs.
-- ---------------------------------------------------------------------------

local STAR = {}
for k = 0, 9 do
    local a = -math.pi / 2 + k * math.pi / 5
    local rad = (k % 2 == 0) and 1.0 or 0.42
    STAR[#STAR + 1] = { rad * math.cos(a), rad * math.sin(a) + 0.08 }
end

local function inPolygon(poly, x, y)
    local inside, j = false, #poly
    for i = 1, #poly do
        local xi, yi, xj, yj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
        if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then
            inside = not inside
        end
        j = i
    end
    return inside
end

local SHAPES = {
    -- 1 Star
    function(u, v) return inPolygon(STAR, u, v) and 1 or nil end,
    -- 2 Moon: a crescent
    function(u, v)
        if u * u + v * v > 0.95 then return nil end
        local du, dv = u - 0.42, v + 0.22
        if du * du + dv * dv < 0.62 then return nil end
        return 1
    end,
    -- 3 Heart
    function(u, v)
        local x, y = u * 1.22, -v * 1.22 + 0.2
        local a = x * x + y * y - 1
        return (a * a * a - x * x * y * y * y <= 0) and 1 or nil
    end,
    -- 4 Diamond
    function(u, v) return (math.abs(u) / 0.72 + math.abs(v) <= 1) and 1 or nil end,
    -- 5 Clover
    function(u, v)
        local function disc(x, y, r) return (u - x) ^ 2 + (v - y) ^ 2 <= r * r end
        if disc(0, -0.48, 0.4) or disc(-0.46, 0.04, 0.4) or disc(0.46, 0.04, 0.4) or disc(0, -0.05, 0.25) then
            return 1
        end
        if math.abs(u) <= 0.09 and v >= 0 and v <= 0.98 then return 1 end
        return nil
    end,
    -- 6 Rainbow: three arcs, ink / grey / ink
    function(u, v)
        local y = v - 0.32
        if y > 0 then return nil end
        local r = math.sqrt(u * u + y * y)
        if r > 1.0 or r < 0.3 then return nil end
        if r > 0.77 then return 1 end
        if r > 0.53 then return 2 end
        return 1
    end,
    -- 7 Black suit: a solid hexagon with a white core
    function(u, v)
        local au, av = math.abs(u), math.abs(v)
        if av > 0.86 or au * 0.866 + av * 0.5 > 0.866 then return nil end
        if u * u + v * v < 0.07 then return nil end
        return 1
    end,
}

local function drawShape(bb, suit, cx, cy, size, color)
    local f = SHAPES[suit]
    if not f or size < 4 then return end
    local half = size / 2
    local x0, y0 = math.floor(cx - half), math.floor(cy - half)
    local n = math.floor(size)
    local ink = color or C_INK
    for j = 0, n - 1 do
        local v = (j + 0.5) / half - 1
        local run_start, run_col
        for i = 0, n do
            local col
            if i < n then col = f((i + 0.5) / half - 1, v) end
            if col ~= run_col then
                if run_col then
                    bb:paintRect(x0 + run_start, y0 + j, i - run_start, 1, run_col == 2 and C_GRAY or ink)
                end
                run_start, run_col = i, col
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- BoardWidget
-- ---------------------------------------------------------------------------

local BoardWidget = InputContainer:extend{
    width       = nil,
    height      = nil,
    game        = nil,
    viewer      = nil,     -- seat whose turn it is (own hand hidden)
    reveal_all  = false,   -- game over: every hand face up
    selected    = nil,     -- { p =, slot = }
    preview     = nil,     -- { target =, slots = { [i] = true } }
    suit_names  = nil,     -- name per suit index
    labels      = nil,     -- { you =, you_short =, ai = fn(name), info = string }
    onCardTap   = nil,     -- fn(p, slot)
}

-- Own cards are drawn this much taller than the teammates': they only carry
-- small knowledge marks, which need the room more than a face-up card does.
local OWN_SCALE   = 1.45
local STRIP_RATIO = 0.26

function BoardWidget:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    self.paint_rect = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = function() return self.paint_rect end } },
    }
    self:_computeLayout()
end

function BoardWidget:getSize()
    return Geom:new{ w = self.width, h = self.height }
end

function BoardWidget:_rowOrder()
    local g, order = self.game, {}
    if self.reveal_all or not self.viewer then
        for p = 1, g.num_players do order[#order + 1] = p end
    else
        for k = 1, g.num_players - 1 do
            order[#order + 1] = (self.viewer - 1 + k) % g.num_players + 1
        end
        order[#order + 1] = self.viewer   -- own hand last, next to the buttons
    end
    return order
end

function BoardWidget:_computeLayout()
    local g = self.game
    local W, H = self.width, self.height
    local gap = math.max(4, math.floor(W / 90))
    self.gap = gap
    local ns = g.num_suits

    -- Header: one small card per stack, then the info line.
    local stack_w = math.floor((W - (ns - 1) * gap) / ns)
    local stack_h = math.floor(math.min(stack_w * 0.62, H * 0.10))
    stack_w = math.min(stack_w, math.floor(stack_h * 1.9))
    self.stack_w, self.stack_h = stack_w, stack_h
    self.info_h = math.floor(math.max(20, math.min(H * 0.04, 48)))
    self.header_h = stack_h + gap + self.info_h + gap

    local order = self:_rowOrder()
    self.order = order
    local rows = #order
    local hs = g.hand_size
    local own_rows = (not self.reveal_all and self.viewer) and 1 or 0
    local strip = self.reveal_all and 0 or STRIP_RATIO
    self.label_h = math.floor(math.max(22, math.min(H * 0.036, 48)))
    self.pos_h = math.floor(self.label_h * 0.8)
    local avail = H - self.header_h

    -- Names above each row, or (when rows are tight and there is width to
    -- spare, as with 4-card hands) in a column on the left: keep whichever
    -- gives the bigger cards.
    local function solve(side)
        local label_w = side and math.floor(W * 0.2) or 0
        local lab_h = side and 0 or self.label_h
        local cw_max = math.floor((W - label_w - (side and gap or 0) - (hs - 1) * gap) / hs)
        local fixed = rows * (lab_h + gap) + own_rows * self.pos_h
        local units = (rows - own_rows) * (1 + strip) + own_rows * OWN_SCALE
        local ch = math.floor((avail - fixed) / units)
        ch = math.min(ch, math.floor(cw_max * 1.3))
        return {
            side = side, label_w = label_w, lab_h = lab_h, ch = ch,
            cw = math.min(cw_max, math.floor(ch * 1.5)),
            -- (but not taller than a card shape: a 5-card row is narrow)
            own_ch = own_rows == 1 and math.min(math.floor(ch * OWN_SCALE), math.floor(cw_max * 1.25)) or ch,
            own_cw = math.min(cw_max, math.floor(ch * OWN_SCALE * 1.5)),
        }
    end
    local top, left = solve(false), solve(true)
    local L = (left.ch > top.ch * 1.08) and left or top
    self.side = L.side
    self.label_w, self.lab_h = L.label_w, L.lab_h
    self.cw, self.ch = L.cw, L.ch
    self.own_cw, self.own_ch = L.own_cw, L.own_ch
    self.strip_h = math.floor(L.ch * strip)
    self.face_cw, self.face_ch = L.cw, L.ch

    local used = 0
    for _, p in ipairs(order) do used = used + self:_rowHeight(p) end
    local spare = avail - used
    self.row_gap = rows > 1 and math.floor(math.max(0, spare) / rows) or 0
    self.rects = {}
end

function BoardWidget:_isOwn(p)
    return p == self.viewer and not self.reveal_all
end

function BoardWidget:_rowHeight(p)
    if self:_isOwn(p) then return self.lab_h + self.own_ch + self.pos_h + self.gap end
    return self.lab_h + self.face_ch + self.strip_h + self.gap
end

-- ---------------------------------------------------------------------------
-- Painting
-- ---------------------------------------------------------------------------

function BoardWidget:_paintStacks(bb, x, y)
    local g, gap = self.game, self.gap
    local ns, sw, sh = g.num_suits, self.stack_w, self.stack_h
    local total = ns * sw + (ns - 1) * gap
    local sx = x + math.floor((self.width - total) / 2)
    local border = math.max(2, math.floor(sw / 45))
    for s = 1, ns do
        local cx = sx + (s - 1) * (sw + gap)
        local top = g.stacks[s]
        bb:paintRect(cx, y, sw, sh, C_BG)
        bb:paintBorder(cx, y, sw, sh, border, C_INK, math.floor(sh / 10))
        local icon = math.floor(math.min(sh * 0.62, sw * 0.42))
        drawShape(bb, g:shapeOf(s), cx + math.floor(sw * 0.3), y + math.floor(sh * 0.5), icon)
        drawText(bb, top > 0 and tostring(top) or "–", cx + math.floor(sw * 0.72),
            y + math.floor(sh * 0.5), sh * 0.62, sw * 0.4, { bold = true, color = top > 0 and C_INK or C_GRAY })
    end
    drawText(bb, self.labels.info or "", x + math.floor(self.width / 2),
        y + sh + gap + math.floor(self.info_h / 2), self.info_h * 0.8, self.width)
end

-- Where a card's rank, shape and name go. Tall cards stack them; wide
-- (short) cards put rank and shape side by side so both stay big.
function BoardWidget:_cardGeom(x, y)
    local cw, ch = self.cw, self.ch
    local show_name = ch * 0.14 >= 11
    local name_px = ch * (show_name and 0.15 or 0)
    if cw >= ch * 1.15 then
        local mid = y + math.floor(show_name and ch * 0.4 or ch * 0.5)
        local body = show_name and ch * 0.62 or ch * 0.85
        return {
            wide = true,
            rank = { x + math.floor(cw * 0.3), mid, body * 0.85, cw * 0.4 },
            icon = { x + math.floor(cw * 0.7), mid, math.floor(math.min(cw * 0.38, body * 0.8)) },
            name = show_name and { x + math.floor(cw / 2), y + math.floor(ch * 0.83), name_px } or nil,
        }
    end
    return {
        wide = false,
        rank = { x + math.floor(cw / 2), y + math.floor(ch * 0.25), ch * 0.34, cw * 0.8 },
        icon = { x + math.floor(cw / 2), y + math.floor(ch * 0.58), math.floor(math.min(cw * 0.5, ch * 0.3)) },
        name = show_name and { x + math.floor(cw / 2), y + math.floor(ch * 0.86), name_px * 0.87 } or nil,
    }
end

-- A face-up card.
function BoardWidget:_paintFace(bb, card, x, y, highlight)
    local g = self.game
    local cw, ch = self.cw, self.ch
    local border = math.max(2, math.floor(cw / 40))
    if highlight then border = border * 3 end
    local radius = math.floor(math.min(cw, ch) / 10)
    bb:paintRoundedRect(x, y, cw, ch, C_BG, radius)
    bb:paintBorder(x, y, cw, ch, border, C_INK, radius)
    local geo = self:_cardGeom(x, y)
    drawText(bb, tostring(card.r), geo.rank[1], geo.rank[2], geo.rank[3], geo.rank[4], { bold = true })
    drawShape(bb, g:shapeOf(card.s), geo.icon[1], geo.icon[2], geo.icon[3])
    if geo.name then
        drawText(bb, self.suit_names[card.s] or "?", geo.name[1], geo.name[2], geo.name[3], cw - 4 * border)
    end
    if card.clued then self:_paintCluedCorner(bb, x, y, cw, border) end
end

function BoardWidget:_paintCluedCorner(bb, x, y, cw, border)
    -- A filled corner triangle: "this card has been clued".
    local t = math.floor(math.min(cw, self.ch) * 0.22)
    for j = 0, t - 1 do
        bb:paintRect(x + cw - t + j, y + j, t - j, 1, C_INK)
    end
end

-- Draw a few shapes in a box, as large as they fit, centred.
function BoardWidget:_paintShapeRow(bb, list, ax, ay, aw, ah, color)
    local g = self.game
    local n = #list
    if n == 0 then return end
    local per_row = n > 3 and math.ceil(n / 2) or n
    local nrows = math.ceil(n / per_row)
    local cell = math.min(aw / per_row, ah / nrows)
    local size = math.floor(cell * 0.86)
    for i, s in ipairs(list) do
        local row = math.floor((i - 1) / per_row)
        local in_row = math.min(per_row, n - row * per_row)
        local col = (i - 1) % per_row
        local rx = ax + math.floor(aw / 2 - in_row * cell / 2 + (col + 0.5) * cell)
        local ry = ay + math.floor(ah / 2 - nrows * cell / 2 + (row + 0.5) * cell)
        drawShape(bb, g:shapeOf(s), rx, ry, size, color)
    end
end

-- A card seen from its holder: only the clue knowledge, as few and as big
-- marks as possible -- the known rank / shape, else "≠ 3" when only one
-- value is ruled out, else the values still possible.
function BoardWidget:_paintHidden(bb, card, x, y, highlight)
    local g = self.game
    local cw, ch = self.cw, self.ch
    local border = math.max(2, math.floor(cw / 40))
    if highlight then border = border * 3 end
    local radius = math.floor(math.min(cw, ch) / 10)
    bb:paintRoundedRect(x, y, cw, ch, C_HIDE, radius)
    bb:paintBorder(x, y, cw, ch, border, C_INK, radius)
    local ks, kr = g:knownSuit(card), g:knownRank(card)
    local suits, ranks, missing_s, missing_r = {}, {}, {}, {}
    for s = 1, g.num_suits do
        if card.ks[s] then suits[#suits + 1] = s else missing_s[#missing_s + 1] = s end
    end
    for r = 1, 5 do
        if card.kr[r] then ranks[#ranks + 1] = r else missing_r[#missing_r + 1] = r end
    end
    if #missing_s == 0 and #missing_r == 0 then
        drawText(bb, "?", x + math.floor(cw / 2), y + math.floor(ch / 2), ch * 0.45, cw * 0.8,
            { bold = true, color = C_GRAY })
        if card.clued then self:_paintCluedCorner(bb, x, y, cw, border) end
        return
    end
    local inner = cw - 4 * border
    -- Two zones: rank on top (or left), shape below (or right).
    local wide = cw >= ch * 1.15
    local rz, sz   -- { cx, cy, w, h }
    if wide then
        rz = { x + math.floor(cw * 0.27), y + math.floor(ch * 0.45), cw * 0.44, ch * 0.75 }
        sz = { x + math.floor(cw * 0.71), y + math.floor(ch * 0.45), cw * 0.48, ch * 0.75 }
    else
        rz = { x + math.floor(cw / 2), y + math.floor(ch * 0.27), inner, ch * 0.4 }
        sz = { x + math.floor(cw / 2), y + math.floor(ch * 0.68), inner, ch * 0.45 }
    end
    -- Rank.
    if kr then
        drawText(bb, tostring(kr), rz[1], rz[2], rz[4] * 0.85, rz[3], { bold = true })
    elseif #missing_r == 1 then
        drawText(bb, "≠" .. missing_r[1], rz[1], rz[2], rz[4] * 0.6, rz[3], { bold = true, color = C_DIM })
    elseif #missing_r > 0 then
        drawText(bb, table.concat(ranks, " "), rz[1], rz[2], rz[4] * (#ranks <= 2 and 0.55 or 0.42), rz[3],
            { bold = true, color = C_DIM })
    end
    -- Shape.
    local sw, sh = sz[3], sz[4]
    local sx, sy = sz[1] - math.floor(sw / 2), sz[2] - math.floor(sh / 2)
    if ks then
        local show_name = not wide and ch * 0.12 >= 11
        local size = math.floor(math.min(sw * 0.6, sh * (show_name and 0.62 or 0.85)))
        drawShape(bb, g:shapeOf(ks), sz[1], sz[2] - (show_name and math.floor(sh * 0.15) or 0), size)
        if show_name then
            drawText(bb, self.suit_names[ks], sz[1], sy + math.floor(sh * 0.85), ch * 0.12, inner)
        end
    elseif #missing_s == 1 then
        -- "not a Heart": a ≠ sign and the ruled-out shape.
        local size = math.floor(math.min(sw * 0.45, sh * 0.7))
        drawText(bb, "≠", sz[1] - math.floor(size * 0.6), sz[2], size * 0.9, sw * 0.4, { bold = true, color = C_DIM })
        drawShape(bb, g:shapeOf(missing_s[1]), sz[1] + math.floor(size * 0.45), sz[2], size, C_DIM)
    elseif #missing_s > 0 then
        self:_paintShapeRow(bb, suits, sx, sy, sw, sh, C_DIM)
    end
    if card.clued then self:_paintCluedCorner(bb, x, y, cw, border) end
end

-- Under a teammate's card: what its holder knows ("knows ★ 3").
function BoardWidget:_paintKnowledgeStrip(bb, card, x, y, inverted)
    local g = self.game
    local cw, sh = self.cw, self.strip_h
    if inverted then bb:paintRect(x, y + 2, cw, sh - 2, C_INK) end
    if not card.clued then return end
    local color = inverted and C_BG or C_INK
    local ks, kr = g:knownSuit(card), g:knownRank(card)
    local cy = y + math.floor(sh / 2) + 1
    local icon = math.floor(sh * 0.85)
    local left = x + math.floor(cw * 0.36)
    local possible = {}
    for s = 1, g.num_suits do if card.ks[s] then possible[#possible + 1] = s end end
    if ks then drawShape(bb, g:shapeOf(ks), left, cy, icon, color)
    elseif #possible == 2 then
        -- e.g. "Heart or Rainbow" after a shape clue in the rainbow variant
        drawShape(bb, g:shapeOf(possible[1]), left - math.floor(icon * 0.45), cy, math.floor(icon * 0.8), color)
        drawShape(bb, g:shapeOf(possible[2]), left + math.floor(icon * 0.45), cy, math.floor(icon * 0.8), color)
    else drawText(bb, "?", left, cy, sh * 0.95, cw * 0.3, { bold = true, color = color }) end
    drawText(bb, kr and tostring(kr) or "?", x + math.floor(cw * 0.64), cy, sh * 0.95, cw * 0.3,
        { bold = true, color = color })
end

function BoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.width, h = self.height }
    self.dimen.x, self.dimen.y = x, y
    bb:paintRect(x, y, self.width, self.height, C_BG)
    local g = self.game
    self:_paintStacks(bb, x, y)
    self.rects = {}

    local hs, gap = g.hand_size, self.gap
    local ry = y + self.header_h + math.floor(self.row_gap / 2)
    for _, p in ipairs(self.order) do
        local own = self:_isOwn(p)
        -- The helpers read self.cw / self.ch: set them for this row.
        self.cw = own and self.own_cw or self.face_cw
        self.ch = own and self.own_ch or self.face_ch
        local cw, ch = self.cw, self.ch
        local cards_w = hs * cw + (hs - 1) * gap
        local row_w = cards_w + (self.side and (self.label_w + gap) or 0)
        local rx = x + math.floor((self.width - row_w) / 2)
        local cards_x = rx + (self.side and (self.label_w + gap) or 0)

        local name = g.players[p].name
        if g.players[p].ai and self.labels.ai then name = self.labels.ai(name) end
        local label = name
        if own then label = self.side and (self.labels.you_short or self.labels.you) or self.labels.you end
        local cur = not g.over and p == g.current
        label = (cur and "▶ " or "") .. label
        if self.side then
            drawText(bb, label, rx, ry + math.floor(ch / 2), self.label_h * 0.9, self.label_w,
                { align = "left", bold = own or cur })
        else
            drawText(bb, label, rx, ry + math.floor(self.lab_h / 2), self.label_h * 0.8, row_w,
                { align = "left", bold = own or cur })
        end
        local cy = ry + self.lab_h
        for i, card in ipairs(g.hands[p]) do
            local cx = cards_x + (i - 1) * (cw + gap)
            local sel = self.selected and self.selected.p == p and self.selected.slot == i
            local prev = self.preview and self.preview.target == p and self.preview.slots[i]
            local below
            if own then
                self:_paintHidden(bb, card, cx, cy, sel)
                drawText(bb, tostring(i), cx + math.floor(cw / 2), cy + ch + math.floor(self.pos_h / 2) + 1,
                    self.pos_h * 0.85, cw, { color = C_DIM })
                below = self.pos_h
            else
                self:_paintFace(bb, card, cx, cy, sel or prev)
                if not self.reveal_all then
                    self:_paintKnowledgeStrip(bb, card, cx, cy + ch, prev)
                end
                below = self.strip_h
            end
            self.rects[#self.rects + 1] = { p = p, slot = i,
                x = cx - x, y = cy - y, w = cw, h = ch + below }
        end
        ry = ry + self:_rowHeight(p) + self.row_gap
    end
    self.cw, self.ch = self.face_cw, self.face_ch
end

function BoardWidget:onTap(_, ges)
    if not (ges and ges.pos) then return false end
    local lx = ges.pos.x - self.paint_rect.x
    local ly = ges.pos.y - self.paint_rect.y
    if lx < 0 or ly < 0 or lx >= self.width or ly >= self.height then return false end
    local half = math.floor(self.gap / 2)
    for _, r in ipairs(self.rects) do
        if lx >= r.x - half and lx < r.x + r.w + half and ly >= r.y - half and ly < r.y + r.h + half then
            if self.onCardTap then self.onCardTap(r.p, r.slot) end
            return true
        end
    end
    return true
end

-- Screen rect of (p, slot), for tests and harnesses.
function BoardWidget:getCardRect(p, slot)
    for _, r in ipairs(self.rects) do
        if r.p == p and r.slot == slot then
            return Geom:new{ x = self.paint_rect.x + r.x, y = self.paint_rect.y + r.y, w = r.w, h = r.h }
        end
    end
end

function BoardWidget:refresh()
    UIManager:setDirty(self, function() return "ui", self.paint_rect end)
end

-- ---------------------------------------------------------------------------
-- Tap-anywhere wrapper (hand-over screen)
-- ---------------------------------------------------------------------------

local TapBox = InputContainer:extend{
    callback = nil,
}

function TapBox:init()
    self.paint_rect = Geom:new{ x = 0, y = 0, w = 0, h = 0 }
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = function() return self.paint_rect end } },
    }
end

function TapBox:getSize()
    return self[1]:getSize()
end

function TapBox:paintTo(bb, x, y)
    local sz = self[1]:getSize()
    self.paint_rect = Geom:new{ x = x, y = y, w = sz.w, h = sz.h }
    self.dimen = self.paint_rect
    self[1]:paintTo(bb, x, y)
end

function TapBox:onTap()
    if self.callback then self.callback() end
    return true
end

-- ---------------------------------------------------------------------------
-- SuitLegend: the suits' shapes with their names, in a row (setup screen)
-- ---------------------------------------------------------------------------

local Widget = require("ui/widget/widget")
local SuitLegend = Widget:extend{
    width = nil, height = nil, shapes = nil, names = nil,
}

function SuitLegend:getSize()
    return Geom:new{ w = self.width, h = self.height }
end

function SuitLegend:paintTo(bb, x, y)
    local n = #self.shapes
    local cell = math.floor(self.width / n)
    local icon = math.floor(math.min(self.height * 0.55, cell * 0.5))
    -- One text size for every name, the largest the longest one allows.
    local px = math.floor(self.height * 0.24)
    if self.names then
        for s = 1, n do
            while px > 8 and RenderText:sizeUtf8Text(0, cell * 10, pxFace(px), self.names[s], true, false).x > cell - 6 do
                px = px - 1
            end
        end
    end
    for s = 1, n do
        local cx = x + (s - 1) * cell + math.floor(cell / 2)
        drawShape(bb, self.shapes[s], cx, y + math.floor(self.height * 0.32), icon)
        if self.names then
            drawText(bb, self.names[s], cx, y + math.floor(self.height * 0.8), px, cell)
        end
    end
end

BoardWidget.TapBox     = TapBox
BoardWidget.SuitLegend = SuitLegend
BoardWidget.drawShape  = drawShape
return BoardWidget
