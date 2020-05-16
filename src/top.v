 /********************************************************
 * Title    : Tang-Nano Party Parrot
 * Date     : 2020/05/17
 * Design   : kingyo
 ********************************************************/
module top (
    // CLK
    input   wire            mco,    // 24MHz

    // Button
    input   wire            btn_a,
    input   wire            btn_b,
    
    // LCD
    output  wire            lcd_clk,
    output  wire            lcd_hsync,
    output  wire            lcd_vsync,
    output  wire            lcd_de,
    output  wire    [15:0]  lcd_data
    );

    /**************************************************************
     *  Wires
     *************************************************************/
    wire            clk9m;
    wire            clk36m;

    /**************************************************************
     *  PLL
     *************************************************************/
    Gowin_PLL Gowin_PLL_isnt (
        .clkin ( mco ),         // input clkin
        .clkout ( clk36m ),     // output clkout
        .clkoutd ( clk9m )      // output clkoutd
    );

    /**************************************************************
     *  LCD Controller
     *************************************************************/
    LCD_Controller LCD_Controller_inst (
        .i_clk ( clk9m ),
        .i_clk_fast ( clk36m ),
        .i_res_n ( 1'b1 ),
        .i_btn_a ( btn_a ),
        .i_btn_b ( btn_b ),
        .o_clk ( lcd_clk ),
        .o_hsync ( lcd_hsync ),
        .o_vsync ( lcd_vsync ),
        .o_de ( lcd_de ),
        .o_lcd_data ( lcd_data[15:0] )
    );
    
endmodule
