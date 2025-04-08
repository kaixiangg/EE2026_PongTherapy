`timescale 1ns / 1ps

// Module to permanently display a mouse graphic with arrows
module Tutorial_Level_Instructions(
    input [6:0] current_pixel_x,    // Current X coordinate being drawn
    input [5:0] current_pixel_y,    // Current Y coordinate being drawn

    // Output for the combined mouse graphic
    output mouse_graphic_pixel
    );

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    // Mouse Graphic Positioning & Dimensions
    localparam MOUSE_OVAL_H = 15;
    localparam MOUSE_OVAL_W = 13;
    localparam MOUSE_CENTER_X = 96 / 2;
    localparam MOUSE_CENTER_Y = 64 / 2;

    localparam OVAL_X_START = MOUSE_CENTER_X - (MOUSE_OVAL_W / 2); // 42
    localparam OVAL_Y_START = MOUSE_CENTER_Y - (MOUSE_OVAL_H / 2); // 25
    localparam OVAL_X_END   = OVAL_X_START + MOUSE_OVAL_W - 1;      // 54
    localparam OVAL_Y_END   = OVAL_Y_START + MOUSE_OVAL_H - 1;      // 39

    // Internal Lines & Wheel
    localparam HLINE_Y     = OVAL_Y_START + (MOUSE_OVAL_H / 3) + 1; // Adjusted slightly lower: 25 + 5 + 1 = 31
    localparam HLINE_X_START = OVAL_X_START + 2;                   // 44
    localparam HLINE_X_END   = OVAL_X_END - 2;                     // 52

    localparam VLINE_X     = MOUSE_CENTER_X;                       // 48 (Center X for lines/wheel)

    // Scroll Wheel dimensions and position
    localparam SCROLL_W    = 3;
    localparam SCROLL_H    = 3;
    // Vertically center wheel between (oval top + 1) and (hline - 1)
    localparam SCROLL_CENTER_Y = ( (OVAL_Y_START + 1) + (HLINE_Y - 1) ) / 2; // (26 + 30) / 2 = 28
    localparam SCROLL_Y_START = SCROLL_CENTER_Y - (SCROLL_H / 2);    // 28 - 1 = 27
    localparam SCROLL_Y_END   = SCROLL_Y_START + SCROLL_H - 1;      // 27 + 3 - 1 = 29
    localparam SCROLL_X_START = VLINE_X - (SCROLL_W / 2);          // 48 - 1 = 47
    localparam SCROLL_X_END   = SCROLL_X_START + SCROLL_W - 1;      // 47 + 3 - 1 = 49

    // Thin Vertical Line Segments
    localparam VLINE_TOP_START_Y = OVAL_Y_START + 1;                // 26
    localparam VLINE_TOP_END_Y   = SCROLL_Y_START - 1;             // 26
    localparam VLINE_BOT_START_Y = SCROLL_Y_END + 1;                // 30
    localparam VLINE_BOT_END_Y   = HLINE_Y - 1;                    // 30

    // Arrows
    localparam ARROW_Y_CENTER = MOUSE_CENTER_Y;                   // 32
    localparam ARROW_OFFSET_X = 4;
    localparam L_ARROW_TIP_X = OVAL_X_START - ARROW_OFFSET_X;      // 38
    localparam R_ARROW_TIP_X = OVAL_X_END + ARROW_OFFSET_X;        // 58
    localparam ARROW_HALF_HEIGHT = 2;
    localparam ARROW_DEPTH = 2;

    //--------------------------------------------------------------------------
    // Wires for drawing components
    //--------------------------------------------------------------------------
    wire oval_border_pixel;
    wire h_line_pixel;
    wire top_vline_pixel;   // NEW
    wire scroll_wheel_pixel;// NEW
    wire bot_vline_pixel;   // NEW
    wire l_arrow_pixel;
    wire r_arrow_pixel;

    //--------------------------------------------------------------------------
    // Mouse Graphic Pixel Generation (Combinational)
    //--------------------------------------------------------------------------

    // 1. Oval Border
    wire is_on_oval_horizontal_edge = ((current_pixel_y == OVAL_Y_START) || (current_pixel_y == OVAL_Y_END)) &&
                                      (current_pixel_x > OVAL_X_START) && (current_pixel_x < OVAL_X_END);
    wire is_on_oval_vertical_edge = ((current_pixel_x == OVAL_X_START) || (current_pixel_x == OVAL_X_END)) &&
                                    (current_pixel_y > OVAL_Y_START) && (current_pixel_y < OVAL_Y_END);
    assign oval_border_pixel = is_on_oval_horizontal_edge || is_on_oval_vertical_edge;

    // 2. Horizontal Line (Button Divider)
    assign h_line_pixel = (current_pixel_y == HLINE_Y) &&
                          (current_pixel_x >= HLINE_X_START) && (current_pixel_x <= HLINE_X_END);

    // 3. Top Vertical Line Segment (1px wide)
    assign top_vline_pixel = (current_pixel_x == VLINE_X) &&
                             (current_pixel_y >= VLINE_TOP_START_Y) && (current_pixel_y <= VLINE_TOP_END_Y);

    // 4. Scroll Wheel Rectangle
    assign scroll_wheel_pixel = (current_pixel_x >= SCROLL_X_START) && (current_pixel_x <= SCROLL_X_END) &&
                                (current_pixel_y >= SCROLL_Y_START) && (current_pixel_y <= SCROLL_Y_END);

    // 5. Bottom Vertical Line Segment (1px wide)
    assign bot_vline_pixel = (current_pixel_x == VLINE_X) &&
                             (current_pixel_y >= VLINE_BOT_START_Y) && (current_pixel_y <= VLINE_BOT_END_Y);

    // 6. Left Arrow '<' Shape
    wire is_l_arrow_wing = (current_pixel_y >= ARROW_Y_CENTER - ARROW_HALF_HEIGHT) &&
                           (current_pixel_y <= ARROW_Y_CENTER + ARROW_HALF_HEIGHT) &&
                           (current_pixel_x > L_ARROW_TIP_X) &&
                           (current_pixel_x <= L_ARROW_TIP_X + ARROW_DEPTH) &&
                           ((current_pixel_x - L_ARROW_TIP_X) == ((current_pixel_y > ARROW_Y_CENTER) ? (current_pixel_y - ARROW_Y_CENTER) : (ARROW_Y_CENTER - current_pixel_y)));
    wire is_l_arrow_tip = (current_pixel_x == L_ARROW_TIP_X) && (current_pixel_y == ARROW_Y_CENTER);
    assign l_arrow_pixel = is_l_arrow_tip || is_l_arrow_wing;

    // 7. Right Arrow '>' Shape
     wire is_r_arrow_wing = (current_pixel_y >= ARROW_Y_CENTER - ARROW_HALF_HEIGHT) &&
                            (current_pixel_y <= ARROW_Y_CENTER + ARROW_HALF_HEIGHT) &&
                            (current_pixel_x < R_ARROW_TIP_X) &&
                            (current_pixel_x >= R_ARROW_TIP_X - ARROW_DEPTH) &&
                           ((R_ARROW_TIP_X - current_pixel_x) == ((current_pixel_y > ARROW_Y_CENTER) ? (current_pixel_y - ARROW_Y_CENTER) : (ARROW_Y_CENTER - current_pixel_y)));
    wire is_r_arrow_tip = (current_pixel_x == R_ARROW_TIP_X) && (current_pixel_y == ARROW_Y_CENTER);
    assign r_arrow_pixel = is_r_arrow_tip || is_r_arrow_wing;

    // Combine all components for final output
    assign mouse_graphic_pixel = (oval_border_pixel || h_line_pixel ||
                                  top_vline_pixel || scroll_wheel_pixel || bot_vline_pixel ||
                                  l_arrow_pixel || r_arrow_pixel);

endmodule