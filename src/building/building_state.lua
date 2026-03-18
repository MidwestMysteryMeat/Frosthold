local State = {
    placed = {},
}

function State.key(x, y, depth)
    return (depth or 0) * 100000000 + y * 10000 + x
end

function State.reset()
    State.placed = {}
    return State.placed
end

return State
