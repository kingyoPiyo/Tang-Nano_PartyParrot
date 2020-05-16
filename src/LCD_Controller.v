 /********************************************************
 * Title    : LCD Controller
 * Date     : 2020/01/26
 * Design   : kingyo
 ********************************************************/
module LCD_Controller (
    input   wire            i_clk,
    input   wire            i_clk_fast,
    input   wire            i_res_n,
    input   wire            i_btn_a,
    input   wire            i_btn_b,
    output  wire            o_clk,
    output  reg             o_hsync,
    output  reg             o_vsync,
    output  reg             o_de,
    output  reg     [ 9:0]  o_x_cnt,
    output  reg     [ 8:0]  o_y_cnt,
    output  reg     [15:0]  o_lcd_data
    );

    /**************************************************************
    *  LCDパラメータ (ATM0430D25)
    *************************************************************/
    localparam DispHPeriodTime  = 531;
    localparam DispWidth        = 480;
    localparam DispHBackPorch   = 43;
    localparam DispHFrontPorch  = 8;
    localparam DispHPulseWidth  = 1;

    localparam DispVPeriodTime  = 288;
    localparam DispHeight       = 272;
    localparam DispVBackPorch   = 12;
    localparam DispVFrontPorch  = 4;
    localparam DispVPulseWidth  = 10;
    
    /**************************************************************
     *  水平/垂直カウンタ
     *************************************************************/
    reg [ 9:0]  r_hPeriodCnt;
    reg [ 8:0]  r_vPeriodCnt;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_hPeriodCnt[9:0] <= 10'd0;
            r_vPeriodCnt[8:0] <= 9'd0;
        end else begin
            // 水平カウンタ
            if (r_hPeriodCnt[9:0] == (DispHPeriodTime - 10'd1)) begin
                r_hPeriodCnt[9:0] <= 10'd0;
            end else begin
                r_hPeriodCnt[9:0] <= r_hPeriodCnt[9:0] + 10'b1;
            end
            // 垂直カウンタ
            if (r_hPeriodCnt[9:0] == (DispHPeriodTime - 10'd1)) begin
                if (r_vPeriodCnt[8:0] == (DispVPeriodTime - 9'd1)) begin
                    r_vPeriodCnt[8:0] <= 9'd0;
                end else begin
                    r_vPeriodCnt[8:0] <= r_vPeriodCnt[8:0] + 9'b1;
                end
            end
        end
    end

    reg         r_hInVisibleArea;
    reg         r_vInVisibleArea;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_hInVisibleArea <= 1'd0;
            r_vInVisibleArea <= 1'd0;
        end else begin
            // 書き込み領域判定
            r_hInVisibleArea <= (r_hPeriodCnt[9:0] == DispHBackPorch)  ? 1'b1 :
                                (r_hPeriodCnt[9:0] == DispHBackPorch + DispWidth) ? 1'b0 : r_hInVisibleArea;
            r_vInVisibleArea <= (r_vPeriodCnt[8:0] == DispVBackPorch)  ? 1'b1 :
                                (r_vPeriodCnt[8:0] == DispVBackPorch + DispHeight) ? 1'b0 : r_vInVisibleArea;
        end
    end


    /**************************************************************
     *  Party Parrot Generator
     *************************************************************/
    reg     [12:0]   r_rom_addr;    // ランレングス圧縮された画像データROMの読み出しアドレス
    wire    [ 7:0]   w_rom_rdata;   // 画像データROM読み出しデータ [7:6]:色情報、[5:0]:X方向の同色連続数
    wire            w_img_en;       // Party Parrot描画有効領域
    reg     [ 5:0]  r_pixel_cnt;    // 連続するpixel数を数えるカウンタ
    wire    [15:0]  w_lcd_data;     // LCDに転送するRGB=565データ
    reg     [ 3:0]  r_imgNum;       // 画像番号
    wire    [12:0]  w_rom_init_addr;// 画像先頭アドレス
    wire    [15:0]  w_party_color;  // 胴体の色（画像番号によって切り替える）
    wire    [15:0]  w_back_color;   // 背景色

    /**************************************************************
     *  ボタン信号同期化FF
     *************************************************************/
    reg [1:0]   r_btn_a_ff;
    reg [1:0]   r_btn_b_ff;
    wire        w_btn_a_sync = r_btn_a_ff[1];
    wire        w_btn_b_sync = r_btn_b_ff[1];
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_btn_a_ff <= 2'b11;
            r_btn_b_ff <= 2'b11;
        end else begin
            r_btn_a_ff <= {r_btn_a_ff[0], i_btn_a};
            r_btn_b_ff <= {r_btn_b_ff[0], i_btn_b};
        end
    end
    
    /**************************************************************
     *  画像ROM
     *  128 x 99ピクセルの画像が10枚分、ランレングス圧縮されて格納されている
     *************************************************************/
    ImgROM ImgROM_inst (
        .i_clk ( i_clk_fast ),
        .i_res_n ( i_res_n ),
        .i_addr ( r_rom_addr[12:0] ),
        .o_data ( w_rom_rdata[7:0] )
    );

    /**************************************************************
     *  画像番号と画像ROMの先頭アドレスを変換する
     *************************************************************/
    assign w_rom_init_addr = (r_imgNum == 4'd0) ? 13'd0 :       // r01.bmp
                             (r_imgNum == 4'd1) ? 13'd630 :     // r02.bmp
                             (r_imgNum == 4'd2) ? 13'd1266 :    // r03.bmp
                             (r_imgNum == 4'd3) ? 13'd1899 :    // r04.bmp
                             (r_imgNum == 4'd4) ? 13'd2533 :    // r05.bmp
                             (r_imgNum == 4'd5) ? 13'd3178 :    // r06.bmp
                             (r_imgNum == 4'd6) ? 13'd3789 :    // r07.bmp
                             (r_imgNum == 4'd7) ? 13'd4376 :    // r08.bmp
                             (r_imgNum == 4'd8) ? 13'd4960 :    // r09.bmp
                             13'd5566;                          // r10.bmp
    
    /**************************************************************
     *  画像番号とParty Parrotの胴体色を対応付ける
     *************************************************************/
    assign w_party_color   = (r_imgNum == 4'd0) ? 16'b11111_111111_11111 :  // r_1
                             (r_imgNum == 4'd1) ? 16'b11111_111111_10010 :  // r_2
                             (r_imgNum == 4'd2) ? 16'b10001_111111_10010 :  // r_3
                             (r_imgNum == 4'd3) ? 16'b10001_111111_11111 :  // r_4
                             (r_imgNum == 4'd4) ? 16'b10001_101111_11111 :  // r_5
                             (r_imgNum == 4'd5) ? 16'b11011_100100_11111 :  // r_6
                             (r_imgNum == 4'd6) ? 16'b11111_100011_11111 :  // r_7
                             (r_imgNum == 4'd7) ? 16'b11111_011010_11111 :  // r_8
                             (r_imgNum == 4'd8) ? 16'b11111_011011_11000 :  // r_9
                                                  16'b11111_011011_01110;   // r_10

    /**************************************************************
     *  描画する画像番号を切り替える
     *  LCDの垂直同期信号の発生回数をカウント
     *  i_btn_a = Lowのときは切り替え高速化
     *************************************************************/
    reg [7:0]   r_imgNumTim;    // 画像切り替えフレーム数カウンタ
    reg [1:0]   r_v_sync_ff;    // 垂直同期信号のエッジ検出用
    reg [5:0]   r_cmov;         // 背景画像のX方向ズレ量
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_v_sync_ff <= 2'b11;
            r_imgNumTim <= 8'd0;
            r_imgNum <= 4'd0;
            r_cmov <= 6'd0;
        end else begin
            r_v_sync_ff <= {r_v_sync_ff[0], o_vsync};
            // 垂直同期信号のエッジで動作
            if (r_v_sync_ff == 2'b10 && w_btn_b_sync) begin
                r_cmov <= r_cmov + 6'd1;
                if ((r_imgNumTim >= 8'd4 & w_btn_a_sync) || (r_imgNumTim >= 8'd2 & ~w_btn_a_sync)) begin
                    r_imgNumTim <= 8'd0;
                    // 画像番号インクリメント
                    if (r_imgNum == 4'd9) begin
                        r_imgNum <= 4'd0;
                    end else begin
                        r_imgNum <= r_imgNum + 4'd1;
                    end
                end else begin
                    r_imgNumTim <= r_imgNumTim + 8'd1;
                end
            end
        end
    end

    /**************************************************************
     *  描画位置制御
     *  例のDVDロゴのパクリでParrotを移動させる
     *************************************************************/
    localparam BITMAP_WIDTH  = 16'd128; // 画像横幅
    localparam BITMAP_HEIGHT = 16'd99;  // 画像縦幅
    localparam BITMAP_LEFT   = 9'd200;  // 初期位置
    localparam BITMAP_TOP    = 9'd100;  // 初期位置
    reg x_vel;
    reg y_vel;
    reg [9:0] x_pos = BITMAP_LEFT;
    reg [9:0] y_pos = BITMAP_TOP;
    always @ (posedge i_clk) begin
        if (r_v_sync_ff == 2'b10 && w_btn_b_sync) begin // 垂直同期で更新
            if (x_pos == 1) begin
                x_vel <= 1;
            end
            if (x_pos == (DispWidth - BITMAP_WIDTH)) begin
                x_vel <= 0;
            end
            if (y_pos == 1) begin
                y_vel <= 1;
            end
            if (y_pos == (DispHeight - BITMAP_HEIGHT)) begin
                y_vel <= 0;
            end
            x_pos <= x_vel == 1 ? (x_pos + 1) : (x_pos - 1);
            y_pos <= y_vel == 1 ? (y_pos + 1) : (y_pos - 1);
        end
    end
    assign w_img_en = (o_x_cnt[9:0] >= x_pos) && (o_x_cnt[9:0] <= (x_pos + 10'd127)) &&
                      (o_y_cnt[8:0] >= y_pos) && (o_y_cnt[8:0] <= (y_pos + 9'd98));

    /**************************************************************
     *  ゲーミング背景生成（虹色）
     *************************************************************/
    wire [5:0] w_sum = o_x_cnt[5:0] + o_y_cnt[5:0] + r_cmov[5:0];   // X方向シフト量計算
    wire [2:0] w_csel = w_sum[5:3]; // 色選択
    assign w_back_color =   (w_csel == 3'd0) ? 16'b11111_000000_00000 : // 赤
                            (w_csel == 3'd1) ? 16'b11111_101001_00000 : // オレンジ
                            (w_csel == 3'd2) ? 16'b11111_111111_00000 : // 黄色
                            (w_csel == 3'd3) ? 16'b00000_100000_00000 : // 緑
                            (w_csel == 3'd4) ? 16'b00000_111111_11111 : // 水色
                            (w_csel == 3'd5) ? 16'b00000_000000_11111 : // 青
                                               16'b10000_000000_10000;  // 柴

    /**************************************************************
     *  LCDデータ
     *************************************************************/
    assign w_lcd_data = (w_rom_rdata[7:6] == 2'd0) ? w_back_color[15:0] :   // 白 => 透過（背景色）
                    (w_rom_rdata[7:6] == 2'd1) ? 16'b00000_000000_00000 :   // 黒 => 輪郭線は黒色
                    (w_rom_rdata[7:6] == 2'd2) ? w_party_color[15:0]    :   // 黄色 => 画像番号に紐付けて着色
                    16'b01000_010000_01000;                                 // グレー => 鼻はいつもグレー色

    /**************************************************************
     *  ランレングス圧縮展開処理
     *************************************************************/
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_rom_addr <= 13'd0;
            r_pixel_cnt <= 6'd1;
        end else begin
            if (w_img_en) begin
                // 画像領域
                if (r_pixel_cnt[5:0] >= w_rom_rdata[5:0] - 1) begin
                    r_rom_addr <= r_rom_addr + 13'd1;
                    r_pixel_cnt <= 6'd0;
                end else begin
                    r_pixel_cnt <= r_pixel_cnt + 6'd1;
                end
                o_lcd_data <= w_lcd_data[15:0];
            end else begin
                o_lcd_data <= w_back_color;
                if (~o_vsync) begin
                    r_rom_addr <= w_rom_init_addr;  // 画像先頭アドレスの初期化
                    r_pixel_cnt <= 6'd0;
                end
            end
        end
    end

    /**************************************************************
     *  出力レジスタ
     *************************************************************/
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            o_hsync     <= 1'b1;
            o_vsync     <= 1'b1;
            o_de        <= 1'b0;
            o_x_cnt     <= 10'd0;
            o_y_cnt     <= 9'd0;
        end else begin
            o_hsync     <= (r_hPeriodCnt[9:0] < DispHPulseWidth) ? 1'b0 : 1'b1;   // HSYNC信号生成
            o_vsync     <= (r_vPeriodCnt[8:0] < DispVPulseWidth) ? 1'b0 : 1'b1;   // VSYNC信号生成
            o_de        <= r_hInVisibleArea & r_vInVisibleArea;
            o_x_cnt     <= r_hPeriodCnt - DispHBackPorch;
            o_y_cnt     <= r_vPeriodCnt - DispVBackPorch;
        end
    end
    assign o_clk = i_clk;

endmodule
