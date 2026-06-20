hl.config({
    input = {
        kb_layout    = "us, ir",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "",
        kb_rules     = "",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad     = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace"
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = 1,
})

hl.config({
    cursor = {
        enable_hyprcursor = false,
    },
})
