module Ball(
    input clk_100MHz,
    input rst,
    input [6:0] paddle_x_pos, // Leftmost of paddle I think
    input [6:0] current_pixel_x,    // Current X coordinate being drawn by display controller
    input [5:0] current_pixel_y,    // Current Y coordinate being drawn by display controller

    output ball_pixel,        // High (1) if current_pixel_x/y is part of the ball
    output reg ball_lost,          // High (1) if ball has gone below the screen
    output reg signed [8:0] ball_pixel_x, // Ball x coordinates, LEFT of ball
    output reg signed [7:0] ball_pixel_y, // Ball y coordinates, TOP of ball
    
    output portal1_pixel,
    output portal2_pixel,
    output portal1_spark_pixel,
    output portal2_spark_pixel,
    output portal1_edge_pixel,
    output portal2_edge_pixel 
);

    parameter BALL_SIZE = 3;        // Ball width/height in pixels (Square shape)
    parameter SCREEN_WIDTH = 96;
    parameter SCREEN_HEIGHT = 64;
    parameter PADDLE_WIDTH = 14;
    parameter PADDLE_HEIGHT = 3;

    // --- Initial State Constants ---
    localparam START_X_POS = (SCREEN_WIDTH / 2) - 1; // x = 47
    localparam START_Y_POS = SCREEN_HEIGHT / 2;      // y = 31
    
    // --- Paddle Zone Constants (0-indexed based on hit_pixel_on_paddle) ---
    // Total Paddle Width: 14 pixels (0 to 13)
    // 7 Zones, 2 pixels each
    localparam PADDLE_LLL_END = 1;
    localparam PADDLE_LL_END  = 3;
    localparam PADDLE_L_END   = 5;
    localparam PADDLE_C_END   = 7;
    localparam PADDLE_R_END   = 9;
    localparam PADDLE_RR_END  = 11;
    localparam PADDLE_RRR_END = 13;

    // --- Portal Constants ---
    localparam PORTAL_WIDTH = 10;
    localparam PORTAL_HEIGHT = 3;
    // Portal 1 (Left Side, e.g., Neon Cyan)
    localparam PORTAL1_X = 15;
    localparam PORTAL1_Y = 20;
    // Portal 2 (Right Side, e.g., Neon Magenta)
    localparam PORTAL2_X = SCREEN_WIDTH - PORTAL1_X - PORTAL_WIDTH; // 96 - 15 - 10 = 71
    localparam PORTAL2_Y = SCREEN_HEIGHT - PORTAL1_Y - PORTAL_HEIGHT; // 64 - 20 - 3 = 41

    // --- Speed Settings ---
    wire clk_24Hz; 
    Clock_Divider inst_24Hz (clk_100MHz, rst, 2083332, clk_24Hz);

    // Change in horizontal velocity (DX) upon collision with parts of the paddle
    // Pixels moved per update cycle (driven by clk_24Hz or similar)
    localparam PADDLE_LLL_DX = -3; // Far Left
    localparam PADDLE_LL_DX  = -2; // Mid Left
    localparam PADDLE_L_DX   = -1; // Near Lefts
    localparam PADDLE_C_DX   = 0;  // Center
    localparam PADDLE_R_DX   = 1;  // Near Right
    localparam PADDLE_RR_DX  = 2;  // Mid Right
    localparam PADDLE_RRR_DX = 3;  // Far Right
    // Velocity Limits
    localparam MAX_DX = 3;
    
    // --- Reg Declarations ---
    reg signed [3:0] dx; // Horizontal velocity
    reg signed [3:0] dy; // Vertical velocity
    reg [1:0] dy_counter = 0;
    reg [2:0] portal_cooldown_timer = 0;
    reg teleported_this_cycle = 0;
    
    // Initial dx = 0, dy = -24pix/s
    initial begin
        ball_pixel_x = START_X_POS;
        ball_pixel_y = START_Y_POS;
        dx = 0;
        dy = 1;
        
        ball_lost = 0;
    end
    always @ (posedge clk_24Hz, posedge rst) begin
        if (rst) begin
            ball_pixel_x = START_X_POS;
            ball_pixel_y = START_Y_POS;      
            dx = 0;
            dy = 1;
            dy_counter = 0;     
            ball_lost = 0;
            portal_cooldown_timer = 0;
            teleported_this_cycle = 0;
        end
        else if (!ball_lost) begin
        
            teleported_this_cycle = 0;
            // --- Decrement Portal Cooldown ---
            if (portal_cooldown_timer > 0) begin
                portal_cooldown_timer = portal_cooldown_timer - 1;
            end
            
            // --- Collision Checks ---
            // Check Portals FIRST (only if cooldown is over)
            if (portal_cooldown_timer == 0) begin
                // Check Portal 1 Entry
                if ((ball_pixel_x + 1 >= PORTAL1_X) && (ball_pixel_x + 1 < PORTAL1_X + PORTAL_WIDTH) &&
                    (ball_pixel_y + 1 >= PORTAL1_Y) && (ball_pixel_y + 1 < PORTAL1_Y + PORTAL_HEIGHT)) begin

                    // Teleport to Portal 2's entrance
                    ball_pixel_x = PORTAL2_X; // Place top-left at portal top-left
                    ball_pixel_y = PORTAL2_Y;
                    portal_cooldown_timer = 3'b111; // Start cooldown (e.g., 2 cycles)
                    teleported_this_cycle = 1'b1; // Mark teleport occurred
                end
                // Check Portal 2 Entry (only if didn't hit portal 1)
                else if ((ball_pixel_x + 1 >= PORTAL2_X) && (ball_pixel_x + 1 < PORTAL2_X + PORTAL_WIDTH) &&
                         (ball_pixel_y + 1 >= PORTAL2_Y) && (ball_pixel_y + 1 < PORTAL2_Y + PORTAL_HEIGHT)) begin

                    // Teleport to Portal 1's entrance
                    ball_pixel_x = PORTAL1_X; // Place top-left at portal top-left
                    ball_pixel_y = PORTAL1_Y;
                    portal_cooldown_timer = 3'b111; // Start cooldown (e.g., 2 cycles)
                    teleported_this_cycle = 1'b1; // Mark teleport occurred
                end
            end // end portal check (if cooldown == 0)            
            
            if (!teleported_this_cycle) begin            
                // DEATH CHECK
                if (ball_pixel_y + BALL_SIZE >= SCREEN_HEIGHT) begin
                    ball_lost = 1;
                end
                // LEFT BOUNDARY CHECK
                else if ( (dx < 0) && (ball_pixel_x + dx <= 0)) begin
                    dx = -dx;
                end
                // RIGHT BOUNDARY CHECK
                else if ( (dx > 0) && (ball_pixel_x + BALL_SIZE + dx >= SCREEN_WIDTH)) begin
                    dx = -dx;             
                end
                // TOP BOUNDARY CHECK
                else if ( (dy < 0) && (ball_pixel_y + dy <= 0)) begin
                    dy = -dy;
                end
                // PADDLE CHECK
                else if ((ball_pixel_y + 2 >= SCREEN_HEIGHT - PADDLE_HEIGHT) && (ball_pixel_x + 1 < paddle_x_pos + PADDLE_WIDTH) &&(ball_pixel_x + 1 >= paddle_x_pos)) begin
                    if (ball_pixel_x + 1 <= paddle_x_pos + PADDLE_LLL_END) begin // Zone LLL (Pixels 0, 1)
                        // Apply far-left paddle effect (-3) if not at speed limit
                        // Note: Consider if adding DX could *exceed* MAX_DX. This check only prevents modification if *already* at MAX_DX.
                        if (dx > -MAX_DX + 3) begin
                            dx = dx + PADDLE_LLL_DX; // Add -3
                        end
                        dy = -dy;
                    end
                    else if (ball_pixel_x + 1 <= paddle_x_pos + PADDLE_LL_END) begin // Zone LL (Pixels 2, 3)
                        // Apply mid-left paddle effect (-2) if not at speed limit
                        if (dx > -MAX_DX + 2) begin
                            dx = dx + PADDLE_LL_DX; // Add -2
                        end
                        dy = -dy;
                    end
                    else if (ball_pixel_x + 1 <= paddle_x_pos + PADDLE_L_END) begin // Zone L (Pixels 4, 5)
                        // Apply near-left paddle effect (-1) if not at speed limit
                        if (dx > -MAX_DX + 1) begin
                            dx = dx + PADDLE_L_DX; // Add -1
                        end
                        dy = -dy;
                    end
                    else if (ball_pixel_x + 1 <= paddle_x_pos + PADDLE_C_END) begin // Zone C (Pixels 6, 7)
                        dy = -dy; // Reflect vertically
                    end
                    else if (ball_pixel_x + 1 <= paddle_x_pos + PADDLE_R_END) begin // Zone R (Pixels 8, 9)
                        // Apply near-right paddle effect (+1) if not at speed limit
                        if (dx < MAX_DX - 1) begin
                            dx = dx + PADDLE_R_DX; // Add +1
                        end
                        dy = -dy;
                    end
                    else if (ball_pixel_x + 1 <= paddle_x_pos + PADDLE_RR_END) begin // Zone RR (Pixels 10, 11)
                        // Apply mid-right paddle effect (+2) if not at speed limit
                        if (dx < MAX_DX - 2) begin
                            dx = dx + PADDLE_RR_DX; // Add +2
                        end
                        dy = -dy;
                    end
                    else begin // Zone RRR (Pixels 12, 13) - Assumes ball_pixel_x is within paddle width
                        // Apply far-right paddle effect (+3) if not at speed limit
                        if (dx < MAX_DX - 3) begin
                            dx = dx + PADDLE_RRR_DX; // Add +3
                        end
                        dy = -dy;
                    end
                end              
            end
            
            if (!teleported_this_cycle) begin
                // Keep moving
                ball_pixel_x = ball_pixel_x + dx;
    
                // --- Vertical Speed Adjustment (Smoothed with 4 Tiers) ---
    
                // Tier 4 Check: Max Horizontal Speed (>= MAX_DX or <= -MAX_DX) -> 1/4 Vertical Speed
                if (dx >= MAX_DX || dx <= -MAX_DX) begin // abs(dx) >= 6
                    if (dy_counter == 2'b00) begin // Update y only when counter is 00
                        ball_pixel_y = ball_pixel_y + dy;
                    end
                end
                // Tier 3 Check: Very High Horizontal Speed (abs(dx) == 4 or 5) -> 1/2 Vertical Speed
                // (Condition adjusted from original Tier 2)
                else if (dx == 4 || dx == 5 || dx == -4 || dx == -5) begin
                     if (dy_counter[0] == 1'b0) begin // Update y when counter LSB is 0 (states 00 and 10)
                         ball_pixel_y = ball_pixel_y + dy;
                     end
                end
                // Tier 2 Check: High Horizontal Speed (abs(dx) == 3) -> 3/4 Vertical Speed (NEW TIER)
                else if (dx == 3 || dx == -3) begin
                     if (dy_counter != 2'b11) begin // Update unless counter is 11 (skip 1 cycle out of 4)
                        ball_pixel_y = ball_pixel_y + dy;
                     end
                end
                // Tier 1: Normal Horizontal Speed (abs(dx) < 3) -> Full Vertical Speed
                else begin // Covers abs(dx) == 0, 1, 2
                     ball_pixel_y = ball_pixel_y + dy; // Update y every cycle
                end
    
                // Increment counter regardless of which tier was active
                dy_counter = dy_counter + 1;
            end
        end
        
        // else game is frozen if ball_lost until rst
    end
    
    
    // --- ASSIGNS ---    
    // Determine if the current pixel being drawn is part of the ball
    assign ball_pixel = (current_pixel_x >= ball_pixel_x) && (current_pixel_x < (ball_pixel_x + BALL_SIZE)) &&
                    (current_pixel_y >= ball_pixel_y) && (current_pixel_y < (ball_pixel_y + BALL_SIZE));      
    // Portal 1 Display (Draw only the border)
    assign portal1_pixel =
        // Check if pixel is within the general bounds of the portal area
        (current_pixel_x >= PORTAL1_X) && (current_pixel_x < (PORTAL1_X + PORTAL_WIDTH)) &&
        (current_pixel_y >= PORTAL1_Y) && (current_pixel_y < (PORTAL1_Y + PORTAL_HEIGHT)) &&
        // AND check if it's specifically on one of the edges
        (
            (current_pixel_x == PORTAL1_X) ||                              // Left edge
            (current_pixel_x == (PORTAL1_X + PORTAL_WIDTH - 1)) ||          // Right edge
            (current_pixel_y == PORTAL1_Y) ||                              // Top edge
            (current_pixel_y == (PORTAL1_Y + PORTAL_HEIGHT - 1))            // Bottom edge
        );

    // Portal 2 Display (Draw only the border)
    assign portal2_pixel =
        // Check if pixel is within the general bounds of the portal area
        (current_pixel_x >= PORTAL2_X) && (current_pixel_x < (PORTAL2_X + PORTAL_WIDTH)) &&
        (current_pixel_y >= PORTAL2_Y) && (current_pixel_y < (PORTAL2_Y + PORTAL_HEIGHT)) &&
        // AND check if it's specifically on one of the edges
        (
            (current_pixel_x == PORTAL2_X) ||                              // Left edge
            (current_pixel_x == (PORTAL2_X + PORTAL_WIDTH - 1)) ||          // Right edge
            (current_pixel_y == PORTAL2_Y) ||                              // Top edge
            (current_pixel_y == (PORTAL2_Y + PORTAL_HEIGHT - 1))            // Bottom edge
        );       
                   
    // --- Portal Animation Timing ---
    // (This logic remains the same)
    wire spark_active = (dy_counter == 2'b10); // Corner sparks ON when counter is 10
    wire edge_flash_active = (dy_counter == 2'b00); // Edge flash ON when counter is 00

    // --- Enhanced Flickering Corner Spark Positions ---
    // Now defines 2 pixels extending diagonally from each corner
    // Portal 1 Sparks
    wire p1_spark_tl = ((current_pixel_x == PORTAL1_X - 1) && (current_pixel_y == PORTAL1_Y - 1)) || // Diag out
                       ((current_pixel_x == PORTAL1_X - 2) && (current_pixel_y == PORTAL1_Y - 2));  // One more diag out
    wire p1_spark_tr = ((current_pixel_x == PORTAL1_X + PORTAL_WIDTH) && (current_pixel_y == PORTAL1_Y - 1)) || // Diag out
                       ((current_pixel_x == PORTAL1_X + PORTAL_WIDTH + 1) && (current_pixel_y == PORTAL1_Y - 2)); // One more diag out
    wire p1_spark_bl = ((current_pixel_x == PORTAL1_X - 1) && (current_pixel_y == PORTAL1_Y + PORTAL_HEIGHT)) || // Diag out
                       ((current_pixel_x == PORTAL1_X - 2) && (current_pixel_y == PORTAL1_Y + PORTAL_HEIGHT + 1)); // One more diag out
    wire p1_spark_br = ((current_pixel_x == PORTAL1_X + PORTAL_WIDTH) && (current_pixel_y == PORTAL1_Y + PORTAL_HEIGHT)) || // Diag out
                       ((current_pixel_x == PORTAL1_X + PORTAL_WIDTH + 1) && (current_pixel_y == PORTAL1_Y + PORTAL_HEIGHT + 1)); // One more diag out

    // Portal 2 Sparks
    wire p2_spark_tl = ((current_pixel_x == PORTAL2_X - 1) && (current_pixel_y == PORTAL2_Y - 1)) ||
                       ((current_pixel_x == PORTAL2_X - 2) && (current_pixel_y == PORTAL2_Y - 2));
    wire p2_spark_tr = ((current_pixel_x == PORTAL2_X + PORTAL_WIDTH) && (current_pixel_y == PORTAL2_Y - 1)) ||
                       ((current_pixel_x == PORTAL2_X + PORTAL_WIDTH + 1) && (current_pixel_y == PORTAL2_Y - 2));
    wire p2_spark_bl = ((current_pixel_x == PORTAL2_X - 1) && (current_pixel_y == PORTAL2_Y + PORTAL_HEIGHT)) ||
                       ((current_pixel_x == PORTAL2_X - 2) && (current_pixel_y == PORTAL2_Y + PORTAL_HEIGHT + 1));
    wire p2_spark_br = ((current_pixel_x == PORTAL2_X + PORTAL_WIDTH) && (current_pixel_y == PORTAL2_Y + PORTAL_HEIGHT)) ||
                       ((current_pixel_x == PORTAL2_X + PORTAL_WIDTH + 1) && (current_pixel_y == PORTAL2_Y + PORTAL_HEIGHT + 1));

    // --- Enhanced Flickering Center Edge Positions ---
    // Defines middle 4 pixels for top/bottom and full 3 pixels for left/right
    localparam EDGE_SEGMENT_LEN = 4; // Length of top/bottom flash
    localparam EDGE_SEGMENT_START = (PORTAL_WIDTH - EDGE_SEGMENT_LEN) / 2; // Start index for segment (10-4)/2 = 3

    // Portal 1 Edges
    wire p1_edge_t = (current_pixel_y == PORTAL1_Y) &&
                     (current_pixel_x >= PORTAL1_X + EDGE_SEGMENT_START) &&
                     (current_pixel_x < PORTAL1_X + EDGE_SEGMENT_START + EDGE_SEGMENT_LEN); // Top segment
    wire p1_edge_b = (current_pixel_y == PORTAL1_Y + PORTAL_HEIGHT - 1) &&
                     (current_pixel_x >= PORTAL1_X + EDGE_SEGMENT_START) &&
                     (current_pixel_x < PORTAL1_X + EDGE_SEGMENT_START + EDGE_SEGMENT_LEN); // Bottom segment
    wire p1_edge_l = (current_pixel_x == PORTAL1_X) &&
                     (current_pixel_y >= PORTAL1_Y) &&
                     (current_pixel_y < PORTAL1_Y + PORTAL_HEIGHT); // Full Left edge
    wire p1_edge_r = (current_pixel_x == PORTAL1_X + PORTAL_WIDTH - 1) &&
                     (current_pixel_y >= PORTAL1_Y) &&
                     (current_pixel_y < PORTAL1_Y + PORTAL_HEIGHT); // Full Right edge

    // Portal 2 Edges
    wire p2_edge_t = (current_pixel_y == PORTAL2_Y) &&
                     (current_pixel_x >= PORTAL2_X + EDGE_SEGMENT_START) &&
                     (current_pixel_x < PORTAL2_X + EDGE_SEGMENT_START + EDGE_SEGMENT_LEN); // Top segment
    wire p2_edge_b = (current_pixel_y == PORTAL2_Y + PORTAL_HEIGHT - 1) &&
                     (current_pixel_x >= PORTAL2_X + EDGE_SEGMENT_START) &&
                     (current_pixel_x < PORTAL2_X + EDGE_SEGMENT_START + EDGE_SEGMENT_LEN); // Bottom segment
    wire p2_edge_l = (current_pixel_x == PORTAL2_X) &&
                     (current_pixel_y >= PORTAL2_Y) &&
                     (current_pixel_y < PORTAL2_Y + PORTAL_HEIGHT); // Full Left edge
    wire p2_edge_r = (current_pixel_x == PORTAL2_X + PORTAL_WIDTH - 1) &&
                     (current_pixel_y >= PORTAL2_Y) &&
                     (current_pixel_y < PORTAL2_Y + PORTAL_HEIGHT); // Full Right edge

    // --- Assign Final Outputs ---
    assign portal1_spark_pixel = spark_active && (p1_spark_tl || p1_spark_tr || p1_spark_bl || p1_spark_br);
    assign portal2_spark_pixel = spark_active && (p2_spark_tl || p2_spark_tr || p2_spark_bl || p2_spark_br);
    assign portal1_edge_pixel = edge_flash_active && (p1_edge_t || p1_edge_b || p1_edge_l || p1_edge_r);
    assign portal2_edge_pixel = edge_flash_active && (p2_edge_t || p2_edge_b || p2_edge_l || p2_edge_r);
    
    endmodule