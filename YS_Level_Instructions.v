`timescale 1ns / 1ps

// Include the provided Clock_Divider module here if it's not in a separate file
// module Clock_Divider (...) ... endmodule

module YS_Level_Instructions(
    input clk_100MHz,
    input rst,
    input [6:0] current_pixel_x,    // Current X coordinate being drawn
    input [5:0] current_pixel_y,    // Current Y coordinate being drawn

    output portal1_text_pixel,      // High if current pixel is part of "PORTALS" text
    output portal2_text_pixel       // High if current pixel is part of "TELEPORT" text
    );

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    // Timing
    localparam DIVISOR_1HZ = 32'd49_999_999;
    localparam DISPLAY_DURATION_S = 6;
    localparam DURATION_COUNTER_BITS = 3;

    // Text Content & Positioning
    // NOTE: Adjust X, Y if needed for smaller font
    localparam TEXT1 = "PORTALS";
    localparam TEXT1_LEN = 7;
    localparam TEXT1_X = 7; // Start X for "PORTALS"
    localparam TEXT1_Y = 10; // Start Y for "PORTALS" (top row)

    localparam TEXT2 = "TELEPORT";
    localparam TEXT2_LEN = 8;
    localparam TEXT2_X = 61; // Start X for "TELEPORT"
    localparam TEXT2_Y = 30; // Start Y for "TELEPORT" (top row)

    // Font Definition (Smaller 3x5 Font)
    localparam FONT_WIDTH = 3;          // CHANGED
    localparam FONT_HEIGHT = 5;         // CHANGED
    localparam FONT_CHAR_SPACING = 1;
    localparam FONT_TOTAL_WIDTH = FONT_WIDTH + FONT_CHAR_SPACING; // Now 4

    //--------------------------------------------------------------------------
    // Registers & Wires
    //--------------------------------------------------------------------------
    wire clk_1Hz;
    reg [DURATION_COUNTER_BITS-1:0] seconds_counter = 0;
    reg display_active_reg = 1'b0;
    wire is_display_active;

    // Wires for text 1 processing
    wire text1_y_match;
    wire signed [8:0] text1_rel_x;
    wire [4:0] text1_char_index;
    wire [1:0] text1_col_index; // Max value is FONT_WIDTH-1 = 2
    wire [2:0] text1_row_index; // Max value is FONT_HEIGHT-1 = 4
    wire text1_x_match;
    reg [7:0] text1_char_code;
    reg [FONT_WIDTH-1:0] text1_font_row_data_comb; // CHANGED width to 3 bits (reg [2:0])
    wire text1_font_pixel;

    // Wires for text 2 processing
    wire text2_y_match;
    wire signed [8:0] text2_rel_x;
    wire [4:0] text2_char_index;
    wire [1:0] text2_col_index; // Max value is FONT_WIDTH-1 = 2
    wire [2:0] text2_row_index; // Max value is FONT_HEIGHT-1 = 4
    wire text2_x_match;
    reg [7:0] text2_char_code;
    reg [FONT_WIDTH-1:0] text2_font_row_data_comb; // CHANGED width to 3 bits (reg [2:0])
    wire text2_font_pixel;

    //--------------------------------------------------------------------------
    // 1 Hz Clock Generation
    //--------------------------------------------------------------------------
    Clock_Divider inst_clk_1Hz (
        .clk_100MHz(clk_100MHz),
        .rst(rst),
        .divisor(DIVISOR_1HZ),
        .clk(clk_1Hz)
    );

    //--------------------------------------------------------------------------
    // 6 Second Duration Timer
    //--------------------------------------------------------------------------
    assign is_display_active = display_active_reg;

    always @(posedge clk_1Hz or posedge rst) begin
        if (rst) begin
            seconds_counter <= 0;
            display_active_reg <= 1'b1;
        end else begin
            if (display_active_reg) begin
                if (seconds_counter == DISPLAY_DURATION_S - 1) begin
                    display_active_reg <= 1'b0;
                end else begin
                    seconds_counter <= seconds_counter + 1;
                end
            end
        end
    end

    //--------------------------------------------------------------------------
    // Text Pixel Generation Logic (Combinational)
    //--------------------------------------------------------------------------

    // --- Text 1 ("PORTALS") Calculations ---
    assign text1_y_match = (current_pixel_y >= TEXT1_Y) && (current_pixel_y < TEXT1_Y + FONT_HEIGHT);
    assign text1_rel_x = current_pixel_x - TEXT1_X;
    assign text1_char_index = text1_rel_x / FONT_TOTAL_WIDTH;
    assign text1_col_index = text1_rel_x % FONT_TOTAL_WIDTH;
    assign text1_row_index = current_pixel_y - TEXT1_Y;
    assign text1_x_match = (text1_rel_x >= 0) && (text1_char_index < TEXT1_LEN) && (text1_col_index < FONT_WIDTH);

    always @(*) begin // Character code lookup for Text 1
        case(text1_char_index)
            0: text1_char_code = "P"; 1: text1_char_code = "O"; 2: text1_char_code = "R";
            3: text1_char_code = "T"; 4: text1_char_code = "A"; 5: text1_char_code = "L";
            6: text1_char_code = "S"; default: text1_char_code = " ";
        endcase
    end

    // Font Data Lookup for Text 1 (Combinational 3x5 Font)
    always @(*) begin
        text1_font_row_data_comb = 3'b000; // Default to blank
        case (text1_char_code)
            "A": case(text1_row_index) // 3x5 'A'
                0: text1_font_row_data_comb = 3'b110; 1: text1_font_row_data_comb = 3'b101;
                2: text1_font_row_data_comb = 3'b111; 3: text1_font_row_data_comb = 3'b101;
                4: text1_font_row_data_comb = 3'b101; default: text1_font_row_data_comb = 3'b000;
             endcase
            "E": case(text1_row_index) // 3x5 'E'
                0: text1_font_row_data_comb = 3'b111; 1: text1_font_row_data_comb = 3'b100;
                2: text1_font_row_data_comb = 3'b110; 3: text1_font_row_data_comb = 3'b100;
                4: text1_font_row_data_comb = 3'b111; default: text1_font_row_data_comb = 3'b000;
             endcase
            "L": case(text1_row_index) // 3x5 'L'
                0: text1_font_row_data_comb = 3'b100; 1: text1_font_row_data_comb = 3'b100;
                2: text1_font_row_data_comb = 3'b100; 3: text1_font_row_data_comb = 3'b100;
                4: text1_font_row_data_comb = 3'b111; default: text1_font_row_data_comb = 3'b000;
             endcase
             "O": case(text1_row_index) // 3x5 'O'
                0: text1_font_row_data_comb = 3'b111; 1: text1_font_row_data_comb = 3'b101;
                2: text1_font_row_data_comb = 3'b101; 3: text1_font_row_data_comb = 3'b101;
                4: text1_font_row_data_comb = 3'b111; default: text1_font_row_data_comb = 3'b000;
             endcase
            "P": case(text1_row_index) // 3x5 'P'
                0: text1_font_row_data_comb = 3'b111; 1: text1_font_row_data_comb = 3'b101;
                2: text1_font_row_data_comb = 3'b111; 3: text1_font_row_data_comb = 3'b100;
                4: text1_font_row_data_comb = 3'b100; default: text1_font_row_data_comb = 3'b000;
             endcase
             "R": case(text1_row_index) // 3x5 'R'
                0: text1_font_row_data_comb = 3'b111; 1: text1_font_row_data_comb = 3'b101;
                2: text1_font_row_data_comb = 3'b110; 3: text1_font_row_data_comb = 3'b101;
                4: text1_font_row_data_comb = 3'b101; default: text1_font_row_data_comb = 3'b000;
             endcase
            "S": case(text1_row_index) // 3x5 'S'
                0: text1_font_row_data_comb = 3'b111; 1: text1_font_row_data_comb = 3'b100;
                2: text1_font_row_data_comb = 3'b111; 3: text1_font_row_data_comb = 3'b001;
                4: text1_font_row_data_comb = 3'b111; default: text1_font_row_data_comb = 3'b000;
             endcase
             "T": case(text1_row_index) // 3x5 'T'
                0: text1_font_row_data_comb = 3'b111; 1: text1_font_row_data_comb = 3'b010;
                2: text1_font_row_data_comb = 3'b010; 3: text1_font_row_data_comb = 3'b010;
                4: text1_font_row_data_comb = 3'b010; default: text1_font_row_data_comb = 3'b000;
             endcase
            default: text1_font_row_data_comb = 3'b000;
        endcase
    end

    // Extract the specific pixel bit for Text 1
    // Index is FONT_WIDTH - 1 - col = 2 - col
    assign text1_font_pixel = text1_font_row_data_comb[2 - text1_col_index];
    assign portal1_text_pixel = is_display_active && text1_y_match && text1_x_match && text1_font_pixel;


    // --- Text 2 ("TELEPORT") Calculations ---
    assign text2_y_match = (current_pixel_y >= TEXT2_Y) && (current_pixel_y < TEXT2_Y + FONT_HEIGHT);
    assign text2_rel_x = current_pixel_x - TEXT2_X;
    assign text2_char_index = text2_rel_x / FONT_TOTAL_WIDTH;
    assign text2_col_index = text2_rel_x % FONT_TOTAL_WIDTH;
    assign text2_row_index = current_pixel_y - TEXT2_Y;
    assign text2_x_match = (text2_rel_x >= 0) && (text2_char_index < TEXT2_LEN) && (text2_col_index < FONT_WIDTH);

    always @(*) begin // Character code lookup for Text 2
        case(text2_char_index)
            0: text2_char_code = "T"; 1: text2_char_code = "E"; 2: text2_char_code = "L";
            3: text2_char_code = "E"; 4: text2_char_code = "P"; 5: text2_char_code = "O";
            6: text2_char_code = "R"; 7: text2_char_code = "T"; default: text2_char_code = " ";
        endcase
    end

    // Font Data Lookup for Text 2 (Combinational 3x5 Font)
    always @(*) begin
        text2_font_row_data_comb = 3'b000; // Default to blank
        case (text2_char_code)
            // --- Copy 3x5 character definitions from above ---
             "A": case(text2_row_index) 0: text2_font_row_data_comb = 3'b110; 1: text2_font_row_data_comb = 3'b101; 2: text2_font_row_data_comb = 3'b111; 3: text2_font_row_data_comb = 3'b101; 4: text2_font_row_data_comb = 3'b101; default: text2_font_row_data_comb = 3'b000; endcase
             "E": case(text2_row_index) 0: text2_font_row_data_comb = 3'b111; 1: text2_font_row_data_comb = 3'b100; 2: text2_font_row_data_comb = 3'b110; 3: text2_font_row_data_comb = 3'b100; 4: text2_font_row_data_comb = 3'b111; default: text2_font_row_data_comb = 3'b000; endcase
             "L": case(text2_row_index) 0: text2_font_row_data_comb = 3'b100; 1: text2_font_row_data_comb = 3'b100; 2: text2_font_row_data_comb = 3'b100; 3: text2_font_row_data_comb = 3'b100; 4: text2_font_row_data_comb = 3'b111; default: text2_font_row_data_comb = 3'b000; endcase
             "O": case(text2_row_index) 0: text2_font_row_data_comb = 3'b111; 1: text2_font_row_data_comb = 3'b101; 2: text2_font_row_data_comb = 3'b101; 3: text2_font_row_data_comb = 3'b101; 4: text2_font_row_data_comb = 3'b111; default: text2_font_row_data_comb = 3'b000; endcase
             "P": case(text2_row_index) 0: text2_font_row_data_comb = 3'b111; 1: text2_font_row_data_comb = 3'b101; 2: text2_font_row_data_comb = 3'b111; 3: text2_font_row_data_comb = 3'b100; 4: text2_font_row_data_comb = 3'b100; default: text2_font_row_data_comb = 3'b000; endcase
             "R": case(text2_row_index) 0: text2_font_row_data_comb = 3'b111; 1: text2_font_row_data_comb = 3'b101; 2: text2_font_row_data_comb = 3'b110; 3: text2_font_row_data_comb = 3'b101; 4: text2_font_row_data_comb = 3'b101; default: text2_font_row_data_comb = 3'b000; endcase
             "S": case(text2_row_index) 0: text2_font_row_data_comb = 3'b111; 1: text2_font_row_data_comb = 3'b100; 2: text2_font_row_data_comb = 3'b111; 3: text2_font_row_data_comb = 3'b001; 4: text2_font_row_data_comb = 3'b111; default: text2_font_row_data_comb = 3'b000; endcase
             "T": case(text2_row_index) 0: text2_font_row_data_comb = 3'b111; 1: text2_font_row_data_comb = 3'b010; 2: text2_font_row_data_comb = 3'b010; 3: text2_font_row_data_comb = 3'b010; 4: text2_font_row_data_comb = 3'b010; default: text2_font_row_data_comb = 3'b000; endcase
            default: text2_font_row_data_comb = 3'b000;
        endcase
    end

    // Extract the specific pixel bit for Text 2
    // Index is FONT_WIDTH - 1 - col = 2 - col
    assign text2_font_pixel = text2_font_row_data_comb[2 - text2_col_index];
    assign portal2_text_pixel = is_display_active && text2_y_match && text2_x_match && text2_font_pixel;

endmodule