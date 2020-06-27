//
// ps2key.v
// Ver 0.1
//
// This Verilog HDL code is provided "AS IS", with NO WARRANTY.
//	NON-COMMERCIAL USE ONLY
//

module ps2key (
	input wire			clk,
	input wire			reset,
	input wire			ps2_data,
	input wire			ps2_clk,
	input wire [3:0]	kbd_adr,
	output reg [7:0]	keydata
	);

	parameter idle    = 2'b01;
	parameter receive = 2'b10;
	parameter ready   = 2'b11;

	reg [1:0]  state = idle;
	reg [15:0] rxtimeout= 16'b0000000000000000;
	reg [10:0] rxregister = 11'b11111111111;
	reg [1:0]  datasr = 2'b11;
	reg [1:0]  clksr = 2'b11;
	reg [7:0]  rxdata;

	reg dataready;

	reg [7:0]	ps2data;
	wire [7:0]	ps2code;
	wire [7:0]	adrcode;
	reg [3:0]	adr;
	reg [3:0]	dat;
	reg 			keyoff = 0;
	reg			fkey = 0; 
	reg [1:0] 	mode = 0;
	reg [3:0]	rstcnt;
	reg [7:0] 	keymtx[0:15];

	always @ ( posedge clk )
	begin
		if( mode == 3 ) begin
			if ( keyoff )
				keymtx[adr] <= keymtx[adr] & ~keysw(dat);
			else
				keymtx[adr] <= keymtx[adr] | keysw(dat);
		end
		else	keydata <= keymtx[kbd_adr];
	end

	always @ ( posedge clk ) 
	begin 
		if( dataready == 1 ) begin
			ps2data <= rxdata;
			mode <= 1;
		end
		else if( mode == 1 ) begin
			if ( ps2data[7]) begin 
				if ( ps2data[7:4] == 4'b1111 )  begin
					keyoff <=  1;
					mode <= 0;
				end
				else if ( ps2data[7:4] == 4'b1110 )  begin
					fkey <=  1;
					mode <= 0;
				end
				else	mode <= 0;
			end
			else begin
				mode <= 2;
			end
		end
		else if( mode == 2 ) begin
			adr <= adrcode[7:4];
			dat <= adrcode[3:0];
			mode <= 3;
		end
		else if( mode == 3 ) begin
			keyoff <= 0;
			fkey <= 0;
			mode <= 0;
		end
	end

	assign	ps2code = { fkey, ps2data[6:0]};

	ps2keymap ps2keymap (
		.clk		( clk		),
		.code		( ps2code	),
		.data		( adrcode	)
	);

	function [7:0] keysw;
		input [4:0] data;
			case (data)
				4'h0: keysw = 8'b0000_0001;
				4'h1: keysw = 8'b0000_0010;
				4'h2: keysw = 8'b0000_0100;
				4'h3: keysw = 8'b0000_1000;
				4'h4: keysw = 8'b0001_0000;
				4'h5: keysw = 8'b0010_0000;
				4'h6: keysw = 8'b0100_0000;
				4'h7: keysw = 8'b1000_0000;
				default: keysw = 8'b0000_0000;
			endcase
	endfunction

	always @ ( posedge clk ) 
	begin 
		rxtimeout <= rxtimeout + 16'd1;
		datasr <= { datasr[0], ps2_data };
		clksr  <= { clksr[0], ps2_clk };
		if( clksr == 2'b10 )
			rxregister<= { datasr[1], rxregister[10:1] };

	case ( state ) 
  
		idle: 
		begin
			rxregister <= 11'b11111111111;
			dataready  <= 0;
			rxtimeout  <= 16'b0000000000000000;
			if( datasr[1] == 0 && clksr[1] == 1 ) begin
				state <= receive;
			end   
		end
    
		receive:
		begin
			if( rxtimeout == 50000) state<=idle;
			else if(rxregister[0] == 0) begin
				dataready <= 1;
				rxdata <= rxregister[8:1];
				state <= ready;
			end
		end
    
		ready: 
		begin
			if(dataready == 1) begin
				state <= idle;
				dataready <= 0;
			end  
		end  
	endcase
end

endmodule

//
// PS/2 to PC-8001 Key conv. map
//
module ps2keymap(
	input wire			clk,
	input wire [7:0]	code,
	output reg [7:0]	data
	);

	always @(posedge clk) begin
		case (code)
			8'h03: data = 8'h95;   // F5
			8'h04: data = 8'h93;   // F3
			8'h05: data = 8'h91;   // F1
			8'h06: data = 8'h92;   // F2
			8'h0C: data = 8'h94;   // F4
			8'h11: data = 8'h84;   // Alt L -> GRAPH
			8'h12: data = 8'h86;   // Shift L
			8'h13: data = 8'h85;   // KANA
			8'h14: data = 8'h87;   // Ctrl L
			8'h15: data = 8'h41;   // Q
			8'h16: data = 8'h61;   // 1
			8'h1A: data = 8'h52;   // Z
			8'h1B: data = 8'h43;   // S
			8'h1C: data = 8'h21;   // A
			8'h1D: data = 8'h47;   // W
			8'h1E: data = 8'h62;   // 2
			8'h21: data = 8'h23;   // C
			8'h22: data = 8'h50;   // X
			8'h23: data = 8'h24;   // D
			8'h24: data = 8'h25;   // E
			8'h25: data = 8'h64;   // 4
			8'h26: data = 8'h63;   // 3
			8'h29: data = 8'h96;   // Space
			8'h2A: data = 8'h46;   // V
			8'h2B: data = 8'h26;   // F
			8'h2C: data = 8'h44;   // T
			8'h2D: data = 8'h42;   // R
			8'h2E: data = 8'h65;   // 5
			8'h31: data = 8'h36;   // N
			8'h32: data = 8'h22;   // B
			8'h33: data = 8'h30;   // H
			8'h34: data = 8'h27;   // G
			8'h35: data = 8'h51;   // Y
			8'h36: data = 8'h66;   // 6
			8'h3A: data = 8'h35;   // M
			8'h3B: data = 8'h32;   // J
			8'h3C: data = 8'h45;   // U
			8'h3D: data = 8'h67;   // 7
			8'h3E: data = 8'h70;   // 8
			8'h41: data = 8'h74;   // ,
			8'h42: data = 8'h33;   // K
			8'h43: data = 8'h31;   // I
			8'h44: data = 8'h37;   // O
			8'h45: data = 8'h60;   // 0
			8'h46: data = 8'h71;   // 9
			8'h49: data = 8'h75;   // .
			8'h4A: data = 8'h76;   // /
			8'h4B: data = 8'h34;   // L
			8'h4C: data = 8'h73;   // ;
			8'h4D: data = 8'h40;   // P
			8'h4E: data = 8'h57;   // -
			8'h51: data = 8'h77;   // _
			8'h52: data = 8'h72;   // :
			8'h54: data = 8'h20;   // @
			8'h55: data = 8'h56;   // ^
			8'h59: data = 8'h86;   // Shift R
			8'h5A: data = 8'h17;   // Enter
			8'h5B: data = 8'h53;   // [
			8'h5D: data = 8'h55;   // ]
			8'h66: data = 8'h83;   // BS -> DEL
			8'h69: data = 8'h01;   // 1 TK
			8'h6A: data = 8'h54;   // ¥
			8'h6B: data = 8'h04;   // 4 TK
			8'h6C: data = 8'h07;   // 7 TK
			8'h70: data = 8'h00;   // 0 TK
			8'h71: data = 8'h16;   // . TK
			8'h72: data = 8'h02;   // 2 TK
			8'h73: data = 8'h05;   // 5 TK
			8'h74: data = 8'h06;   // 6 TK
			8'h75: data = 8'h10;   // 8 TK
			8'h76: data = 8'h97;   // Esc
			8'h79: data = 8'h13;   // + TK
			8'h7A: data = 8'h03;   // 3 TK
			8'h7B: data = 8'h14;   // - TK
			8'h7C: data = 8'h12;   // * TK
			8'h7D: data = 8'h11;   // 9 TK
			// E0 Prefix (+80h)
			8'hCA: data = 8'h76;   // / TK
			8'hDA: data = 8'h17;   // Enter
			8'hE9: data = 8'h90;   // END -> STOP
			8'hEB: data = 8'h82;   // LEFT -> R,L
			8'hEC: data = 8'h80;   // HOME -> HOME
			8'hF1: data = 8'h83;   // DEL -> DEL
			8'hF2: data = 8'h81;   // DN -> U,D
			8'hF4: data = 8'h82;   // RIGHT -> R,L
			8'hF5: data = 8'h81;   // UP -> U,D
			default: data = 8'hFF;
		endcase
	end
endmodule