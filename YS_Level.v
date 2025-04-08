`timescale 1ns / 1ps

module YS_Level(
    input clk_100MHz,
    input rst,          // Use this for resetting game state
    inout PS2Clk,
    inout PS2Data,
    output [7:0] JC     // Pmod connector for OLED
    );

    //-------------------------------------------------------------------------
    // Parameters
    //-------------------------------------------------------------------------
    localparam SCREEN_WIDTH = 96;
    localparam SCREEN_HEIGHT = 64;
    localparam PADDLE_WIDTH = 14;
    localparam PADDLE_HEIGHT = 3; // Ensure this matches Paddle module internal logic if not parameterized
    localparam BALL_SIZE = 3;     // Ensure this matches Ball module parameter
    localparam COLOR_LIME_GREEN = 16'h07E0; // (R=0, G=63, B=0) - Pure bright green.
    localparam COLOR_ELECTRIC_BLUE = 16'h051F;// (R=0, G=40, B=31) - Bright blue, less green than cyan.
    localparam COLOR_ORANGE = 16'hFC00; // (R=31, G=32, B=0) - Bright orange.
    localparam COLOR_HOT_PINK = 16'hF95F; // (R=31, G=10, B=31) - Bright, less "purple" than magenta.
    localparam COLOR_SPRING_GREEN = 16'h07EF;// (R=0, G=63, B=15) - Bright green with a hint of blue.
    localparam COLOR_BLUE = 16'h001F;
    localparam COLOR_VIOLET = 16'h781F;

    // Mouse Parameters (kept from original)
    localparam MOUSE_SENSITIVITY_DIVIDER = 16;
    localparam SCALED_X_BOUNDARY = (SCREEN_WIDTH * MOUSE_SENSITIVITY_DIVIDER) - 1; // Max raw mouse value reported

    // Ball Update Rate Control (~60 Hz update rate)
    // Period = 100MHz / 60Hz = 1,666,667 cycles
    localparam BALL_UPDATE_PERIOD = 1666667;
    // Bits needed for counter: ceil(log2(1666667)) = 20 bits
    localparam BALL_COUNTER_BITS = 21;

    // Color Definitions (16-bit RGB565)
    localparam PADDLE_COLOR = 16'hFFFF; // White
    localparam BALL_COLOR   = 16'hF800; // Red
    localparam BG_COLOR     = 16'h0000; // Black
    localparam COLOR_PORTAL1 = 16'h07FF; // Neon Cyan
    localparam COLOR_PORTAL2 = 16'hF81F; // Neon Magenta
    localparam COLOR_SPARK_EDGE1 = 16'hFFE0; // Bright Yellow for Portal 1 effects
    localparam COLOR_SPARK_EDGE2 = 16'hFFFF; // Bright White for Portal 2 effects (Example)

    //-------------------------------------------------------------------------
    // Wires & Regs
    //-------------------------------------------------------------------------

    // --- Clocking ---
    wire clk_6p25MHz; // For OLED

    // --- OLED Interface ---
    wire [15:0] oled_data;      // Pixel data TO the OLED driver
    wire [12:0] pixel_index;    // Current pixel index FROM the OLED driver
    wire frame_begin;           // Signal FROM OLED driver
    wire sending_pixels;        // Signal FROM OLED driver
    wire sample_pixel;          // Signal FROM OLED driver
    wire [6:0] pixel_x;         // Calculated current pixel X
    wire [5:0] pixel_y;         // Calculated current pixel Y

    // --- Mouse Interface ---
    wire left, middle, right;   // Button states FROM MouseCtl
    wire [11:0] xpos;           // Raw X position FROM MouseCtl (0 to SCALED_X_BOUNDARY)
    wire [11:0] ypos;           // Raw Y position FROM MouseCtl (unused here)
    wire [3:0] zpos;            // Scroll wheel FROM MouseCtl (unused here)
    wire new_event;             // New data flag FROM MouseCtl
    wire [11:0] inverted_xpos;
    assign inverted_xpos = SCALED_X_BOUNDARY - xpos;

    // --- Paddle Interface ---
    wire paddle_pixel;          // Pixel is paddle? FROM Paddle
    wire [6:0] paddle_x_pos;    // Paddle X position FROM Paddle

    // --- Ball Interface ---
    wire [8:0] ball_left_pixel; // Ball x coordinates, LEFT of ball
    wire [7:0] ball_top_pixel; // Ball y coordinates, TOP of ball
    wire ball_pixel;            // Pixel is ball? FROM Ball
    wire ball_lost;             // Ball below screen? FROM Ball
    
    // --- Portal Interface ---
    wire portal1_on, portal2_on;
    wire portal1_spark_on, portal2_spark_on;
    wire portal1_edge_spark_on, portal2_edge_spark_on;
    
    // --- Instruction Text Interface ---
    wire portal1_text_on;
    wire portal2_text_on;

    //-------------------------------------------------------------------------
    // Clock Generation
    //-------------------------------------------------------------------------
    Clock_Divider (clk_100MHz, rst, 7, clk_6p25MHz);

    //-------------------------------------------------------------------------
    // Pixel Coordinate Calculation
    //-------------------------------------------------------------------------
    // Translate linear pixel index from OLED driver to X, Y coordinates
    assign pixel_x = pixel_index % SCREEN_WIDTH; // Remainder gives X
    assign pixel_y = pixel_index / SCREEN_WIDTH; // Integer division gives Y

    //-------------------------------------------------------------------------
    // Module Instantiations
    //-------------------------------------------------------------------------

    // --- OLED Driver ---
    Oled_Display oled_display(
        .clk(clk_6p25MHz),      // Use divided clock
        .reset(rst),
        // --- Control/Status Signals ---
        .frame_begin(frame_begin),     // Output: Start of frame
        .sending_pixels(sending_pixels),// Output: Actively sending pixel data
        .sample_pixel(sample_pixel),    // Output: Request for pixel data for 'pixel_index'
        // --- Pixel Data ---
        .pixel_index(pixel_index),      // Output: Linear index (0 to 6143) of current pixel
        .pixel_data(oled_data),         // Input: 16-bit color data for the current pixel
        // --- Physical Interface (Pmod JC) ---
        .cs(JC[0]),             // Chip Select
        .sdin(JC[1]),           // Data In (MOSI)
        .sclk(JC[3]),           // Serial Clock
        .d_cn(JC[4]),           // Data/Command
        .resn(JC[5]),           // Reset
        .vccen(JC[6]),          // VCC Enable
        .pmoden(JC[7])          // PMOD Enable
    );

    // --- PS/2 Mouse Controller ---
     MouseCtl mouse_control (
        .clk(clk_100MHz),
        .rst(rst), // Connect system reset now
         // Set initial mouse position/boundaries (only on config pulse if needed)
        .value(SCALED_X_BOUNDARY), // Value used for setx/sety/setmax_x/y
        .setx(1'b0), .sety(1'b0),   // Don't force position
        .setmax_x(1'b1),           // Set the max X value mouse reports
        .setmax_y(1'b0),           // Don't set max Y
        // Outputs
        .xpos(xpos), .ypos(ypos), .zpos(zpos),
        .left(left), .right(right), .middle(middle),
        .new_event(new_event),     // Flag indicates new xpos/button data is valid
        // Bidirectional PS/2 Interface
        .ps2_clk(PS2Clk),
        .ps2_data(PS2Data)
    );

    // --- Paddle Logic ---
    Paddle #(
        .PADDLE_WIDTH(PADDLE_WIDTH),
        .PADDLE_HEIGHT(PADDLE_HEIGHT), // Pass relevant params
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .MOUSE_SENSITIVITY_DIVIDER(MOUSE_SENSITIVITY_DIVIDER)
    ) paddle_instance (
        .clk(clk_100MHz),
        .reset(rst),
        .new_event(new_event),       // From MouseCtl
        .x_position(inverted_xpos),           // Raw mouse X from MouseCtl
        .current_pixel_y(pixel_y),   // Current scanline Y
        .current_pixel_x(pixel_x),   // Current scanline X
        .paddle_x_pos(paddle_x_pos), // Output: Paddle's logical X position
        .paddle_pixel(paddle_pixel)  // Output: Should current pixel be paddle color?
    );

    // --- Ball Logic & Physics ---
    Ball ball_instance (
        .clk_100MHz(clk_100MHz),
        .rst(rst),
        .paddle_x_pos(paddle_x_pos),        // From Paddle instance
        .current_pixel_x(pixel_x),
        .current_pixel_y(pixel_y),
        .ball_pixel(ball_pixel),            // Output: Should current pixel be ball color?
        .ball_lost(ball_lost),               // Output: Has ball gone off bottom?
        .ball_pixel_x(ball_left_pixel),
        .ball_pixel_y(ball_top_pixel),
        .portal1_pixel(portal1_on),
        .portal2_pixel(portal2_on),
        .portal1_spark_pixel(portal1_spark_on),
        .portal2_spark_pixel(portal2_spark_on),
        .portal1_edge_pixel(portal1_edge_spark_on),  
        .portal2_edge_pixel(portal2_edge_spark_on)   
    );

    // --- Instruction Text Display Logic ---
    YS_Level_Instructions instruction_display (
        .clk_100MHz(clk_100MHz),
        .rst(rst),
        .current_pixel_x(pixel_x),         // From coordinate calc
        .current_pixel_y(pixel_y),         // From coordinate calc
        .portal1_text_pixel(portal1_text_on), // Output wire
        .portal2_text_pixel(portal2_text_on)  // Output wire
    );
    //-------------------------------------------------------------------------
    // Pixel Color Multiplexing
    //-------------------------------------------------------------------------
    // Can uncomment the edge_sparks for potentially more complex patterns
    // but looks messy for now
    assign oled_data =
       portal1_text_on ? PADDLE_COLOR :                // 1. Instruction Text 1
       portal2_text_on ? PADDLE_COLOR :     
       ball_pixel ? BALL_COLOR :                     // Ball
       paddle_pixel ? PADDLE_COLOR :                 // Paddle
       
       // Portal 1 Effects (Sparks/Edges first)
       portal1_spark_on ? COLOR_SPARK_EDGE1 :
       //portal1_edge_spark_on ? COLOR_ELECTRIC_BLUE :
       portal1_on ? COLOR_PORTAL1 :                  // Portal 1 Border last for P1
       
       // Portal 2 Effects (Sparks/Edges first)
       portal2_spark_on ? COLOR_SPARK_EDGE2 :
       //portal2_edge_spark_on ? COLOR_VIOLET :
       portal2_on ? COLOR_PORTAL2 :                  // Portal 2 Border last for P2
       
       // Default Background
       BG_COLOR;
endmodule