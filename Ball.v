module Ball(
    input clk_100MHz,
    input rst,
    input [6:0] paddle_x_pos,
    input [6:0] current_pixel_x,    // Current X coordinate being drawn by display controller
    input [5:0] current_pixel_y,    // Current Y coordinate being drawn by display controller

    output ball_pixel,        // High (1) if current_pixel_x/y is part of the ball
    output reg ball_lost          // High (1) if ball has gone below the screen
);
    parameter BALL_SIZE = 3;        // Ball width/height in pixels (Square shape)
    parameter SCREEN_WIDTH = 96;
    parameter SCREEN_HEIGHT = 64;
    parameter PADDLE_WIDTH = 14;
    parameter PADDLE_HEIGHT = 3;

    // --- Initial State Constants ---
    localparam START_X_POS = (SCREEN_WIDTH / 2) - 1;
    localparam START_Y_POS = SCREEN_HEIGHT / 2;
    
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

    // --- Speed Settings ---
    wire clk_24Hz; 
    Clock_Divider inst_24Hz (clk_100MHz, rst, 2083332, clk_24Hz);

    // Change in horizontal velocity (DX) upon collision with parts of the paddle
    // Pixels moved per update cycle (driven by clk_24Hz or similar)
    localparam PADDLE_LLL_DX = -3; // Far Left
    localparam PADDLE_LL_DX  = -2; // Mid Left
    localparam PADDLE_L_DX   = -1; // Near Left
    localparam PADDLE_C_DX   = 0;  // Center
    localparam PADDLE_R_DX   = 1;  // Near Right
    localparam PADDLE_RR_DX  = 2;  // Mid Right
    localparam PADDLE_RRR_DX = 3;  // Far Right
    // Velocity Limits
    localparam MAX_DX = 3;
    
    // --- Reg Declarations ---
    reg signed [8:0] ball_pixel_x; // Ball x coordinates, LEFT of ball
    reg signed [7:0] ball_pixel_y; // Ball y coordinates, TOP of ball
    reg signed [3:0] dx; // Horizontal velocity
    reg signed [3:0] dy; // Vertical velocity
    reg [1:0] dy_counter = 0;
    
    // Initial dx = 0, dy = -24pix/s
    initial begin
        ball_pixel_x = START_X_POS;
        ball_pixel_y = START_Y_POS;
        dx = 0;
        dy = 1;
        
        ball_lost = 0;
    end
    // ===== Use with caution, I split paddle into 5 sections for dynamic directional change =====
    always @ (posedge clk_24Hz, posedge rst) begin
        if (rst) begin
            ball_pixel_x = START_X_POS;
            ball_pixel_y = START_Y_POS;      
            dx = 0;
            dy = 1;
            dy_counter = 0;     
            ball_lost = 0;
        end
        else if (!ball_lost) begin
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
        
        // else game is frozen if ball_lost until rst
    end
    
    
    // --- ASSIGNS ---    
    // Determine if the current pixel being drawn is part of the ball
    assign ball_pixel = (current_pixel_x >= ball_pixel_x) && (current_pixel_x < (ball_pixel_x + BALL_SIZE)) &&
                    (current_pixel_y >= ball_pixel_y) && (current_pixel_y < (ball_pixel_y + BALL_SIZE));
                        
endmodule