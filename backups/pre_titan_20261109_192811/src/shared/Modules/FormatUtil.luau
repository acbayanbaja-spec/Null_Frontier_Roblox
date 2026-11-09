local FormatUtil = {}

function FormatUtil.Round(num: number, decimals: number?): number
    local mult = 10 ^ (decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

function FormatUtil.LerpColor(c1: Color3, c2: Color3, alpha: number): Color3
    return Color3.new(
        c1.R + (c2.R - c1.R) * alpha,
        c1.G + (c2.G - c1.G) * alpha,
        c1.B + (c2.B - c1.B) * alpha
    )
end

return FormatUtil
