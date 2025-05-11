

-- Buttons
buttons = {
    retry = {
        click_function = "retry",
        function_owner = self,
        label          = "Fix missing objects \n and click me \nto retry",
        position       = {1.75, -0.99, 0},
        scale          = {2.2, 1.0, 2.2 },
        rotation       = {0, 270, 0},
        width          = 1000,
        height         = 500,
        font_size      = 110,
        color          = hexToColor("#823030"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Place missing objects and retry", 
    },
    setup = {
        click_function = "chronicleSetup",
        function_owner = self,
        label          = "Setup Initial\nAtlas Box, Sites, \n& World Deck",
        position       = {1.75, -0.99, 0},
        scale          = {2.2, 1.0, 2.2 },
        rotation       = {0, 270, 0},
        width          = 1000,
        height         = 500,
        font_size      = 130,
        color          = hexToColor("#4a915d"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Set Up the Atlas Box for a new Chronicle", 
    }
}