//
// PC-8001 on DE0-CV
// pc8001m.v  "PC-8001 MODOKI"
//
// Orignal Auther	: kwhr0 san
// Modified 		: RJB
//
// 2020/6/13  Ver 1.10 first published
// 2020/6/27  Ver 1.11 added PCG8200 and Full Dot Color mode
// 2020/7/12  Ver 1.12 added PSG and Chiqlappe-san modified PCG/FDC *1
//
// This Verilog HDL code is provided "AS IS", with NO WARRANTY.
//	NON-COMMERCIAL USE ONLY
//

module pc8001m (
	input wire			clk50,
	input	wire			reset_n,
	input wire			ps2_clk,
	input wire			ps2_data,
	input	wire			rxd,
	input wire			cmt_in,
	output wire			txd,
	output wire			beep_out,
	output wire			motor_out,
	output wire [1:0]	bw_out,
	output wire			vga_hs,
	output wire			vga_vs,
	output wire [3:0]	vga_r,
	output wire [3:0]	vga_g,
	output wire [3:0]	vga_b,
	output wire [6:0]	HEX0,
	output wire [6:0]	HEX1,
	output wire [6:0]	HEX2,
	output wire [6:0]	HEX3,
	output wire [6:0]	HEX4,
	output wire [6:0]	HEX5,
	output wire [9:0]	LEDR,
	input wire[ 9:0]	SW,
	input wire			sd_dat,
	output wire			sd_clk,
	output wire			sd_cmd,
	output wire			sd_res,
	output wire [3:0]	audio_out,
	output wire			dac_out
	);
		
	wire			clk2;		// pll clock 28.63636MHz
	wire			clk;		// clock 14.31818MHz
	wire			clk3;		// clock  3.57954MHz
	
	wire			clk48;	// pll clock 48MHz
	reg			clk4;		// clock 4MHz

	wire			cdin;
	reg			cinh;

	reg[7:0] 	portB_out;	// SD Card 8255 PortB out
	
	wire [15:0]	cpu_adr;
	wire [16:0]	dma_adr;
	wire [7:0]	cpu_data_in, cpu_data_out, keydata;
	wire 			mreq, iorq, rd, wr, busreq, busack;
	
	wire [15:0]	ram_adr;
	wire [7:0]	ram_data;
	wire 			ram_we;
	wire [7:0]	mem_data;

	wire [7:0]	uart_data;
	wire [7:0]	psg_reg0, psg_reg1;

	//
	// Assign SW
	//
	wire			SW_OC  = SW[9];	// reduce CPU Wait 
	wire			SW_ROM = SW[7];	// enable Ext. ROM 6000-7FFFh
	wire			SW_PCG = SW[5];	// PCG ON
	wire			SW_MDL = SW[4];	// PCG Model 8100 or 8200/8800
	wire			SW_FDC = SW[3];	// PCG Full Dot Color Mode
	wire			SW_CMT = SW[2];	// enable CMT OUT to Sound
	wire			SW_GRN = SW[0];	// Green Display
	
	//
	// RESET
	//
	reg			reset = 1'b1;
	reg [17:0]	rcnt = 18'h0;
	always @ ( posedge clk, negedge reset_n)
	begin
		if ( reset_n == 0) begin
			rcnt <= 18'h0;
			reset <= 1'b1;
		end
		else begin
			if ( rcnt == 240000) begin
				reset <= 1'b0;
			end 
			else begin
				rcnt <= rcnt + 1;
			end
		end
	end

	//
	// CPU WAIT
	//
	reg [4:0] waitcount = 0;
	wire start, waitreq;
	assign waitreq = SW_OC ? start | waitcount < 12 : start | waitcount < 25; // Ver1.12 21 -> 25 

	always @(posedge clk) begin
		if (start) waitcount <= 0;
		else waitcount <= waitcount + 1;
	end
	
	//
	// I/O PORT
	//
	wire 			cdata;
/* *1
	reg [5:0]	vrtc = 0;
	reg			iorq0 = 0, rd0 = 0, port40h0 = 0;
*/
	wire			vsync;	// *1

	wire port00h = cpu_adr[7:4] == 4'h0;		// keyboard
	wire port20h = cpu_adr[7:4] == 4'h2;		// uart
	wire port30h = cpu_adr[7:4] == 4'h3;
	wire port40h = cpu_adr[7:4] == 4'h4;
	wire port90h = cpu_adr[7:4] == 4'h9;		// Full Dot Color
	wire porta0h = cpu_adr[7:4] == 4'ha;		// PSG
	wire porte0h = cpu_adr[7:4] == 4'he;
	wire portf0h = cpu_adr[7:4] == 4'hf;
	wire [7:0] port00data, port20data, port40data, porta0data, portf0data;

	assign port00data = ~keydata;
	assign port20data = uart_data;
//	assign port40data = { 2'b00, vrtc[5], cdata, 1'b1, cdin, 2'b10 };		// *1
	assign port40data = { 2'b00, vsync, cdata, 1'b1, cdin, 2'b10 };		// *1
	assign portf0data = cpu_adr[3:0] == 4'hd ? portB_out : { 3'b111, sd_dat, 4'b1111 };
	reg [7:0] input_data;

	always @(posedge clk) begin
		case (cpu_adr[7:4])
			4'h0:	input_data <= port00data;
			4'h2:	input_data <= port20data;
			4'h4:	input_data <= port40data;
			4'ha:	input_data <= porta0data;
			4'hf:	input_data <= portf0data;
			default:	input_data <= 8'hff;
		endcase
	end
	
/*	*1
	always @(posedge clk) begin
		if (~iorq & iorq0 & rd0 & port40h0) vrtc <= vrtc + 1;
		iorq0 <= iorq;
		rd0 <= rd;
		port40h0 <= port40h;
	end
*/

	//
	// CPU Bus
	//
	assign cpu_data_in = iorq ? input_data : mem_data;

	//
	// PS/2 KEYBOARD
	//
	wire [3:0] kbd_adr;
	assign kbd_adr = port00h ? cpu_adr[3:0] : 4'b1111;
	ps2key ps2key (
		.clk			( clk			),
		.reset		( reset		),
		.ps2_clk  	( ps2_clk	),
		.ps2_data	( ps2_data	),
		.kbd_adr		( kbd_adr	),
		.keydata		( keydata	)
	);

	//
	// RTC
	//
	reg [3:0] cin;
	reg cstb, cclk;
	always @(posedge clk) begin
		if (iorq & wr) begin
			if (cpu_adr[7:4] == 4'h1) cin <= cpu_data_out[3:0];
			if (cpu_adr[7:4] == 4'h4) begin
				cstb <= cpu_data_out[1];
				cclk <= cpu_data_out[2];
			end
		end
	end
	rtc rtc(
		.clk		( clk		),
		.cstb		( cstb	),
		.cclk		( cclk	),
		.cin		( cin		),
		.cdata	( cdata	),
		.ind		(			)
	);
	
	//
	// PCG & Full Dot Color
	//
	reg [7:0]		pcg_adr8;	// 00h
	reg [7:0]		pcg_data;	// 01h
	reg [7:0]		pcg_cont;	// 02h
	reg [7:0]		pcg_slct;	// 03h
	wire [10:0]		pcg_adr;
	wire				pcg_we;
	wire				pcg_on;
	wire [7:0]		pcg_mode;

	reg [2:0]		clr_plt[0:7];	// Color Palette
	reg [1:0]		fdc_cs;
	wire [2:0]		fdc_plt;
	wire [2:0]		plt_sel;
	
	assign	pcg_adr = { pcg_cont[2:0], pcg_adr8 };
	assign	pcg_we = pcg_cont[4];
	assign	pcg_on = SW_PCG;
	assign	pcg_mode = { SW_FDC, 1'b0, SW_MDL, pcg_slct[4:0]};
	assign	fdc_plt = clr_plt[plt_sel];
	
	always @(posedge clk) begin
		if ( reset) begin
			pcg_slct <= 8'h08;				// PCG8100 mode
		end
		else if ( iorq & wr ) begin		// PCG
			if( port00h) begin
				if ( cpu_adr[3:0] == 4'h0 )	pcg_data <= cpu_data_out;
				if ( cpu_adr[3:0] == 4'h1 )	pcg_adr8 <= cpu_data_out;
				if ( cpu_adr[3:0] == 4'h2 )	pcg_cont <= cpu_data_out;
				if ( cpu_adr[3:0] == 4'h3 )	pcg_slct <= cpu_data_out;
			end
			else if( port90h) begin			// Full Dot Color
				if ( cpu_adr[3] )	begin
					fdc_cs <= cpu_data_out[1:0];
				end
				else begin
					clr_plt[cpu_adr[2:0]] <= cpu_data_out[2:0];
				end
			end
		end
	end

	
	// 8253 Sound Gen.	
	wire			pcg8253_wr;
	wire[2:0]	pcg8253_gate;
	wire[2:0]	pcg8253_out;
	assign		pcg8253_wr = iorq & wr & ( cpu_adr[7:2] == 6'b0000_11 );
	assign		pcg8253_gate = { pcg_cont[7], pcg_cont[6], pcg_cont[3] };
		
	ltd8253 pcg8253 (
		.clk		( clk				),
		.adr		( cpu_adr[1:0]	),
		.din		( cpu_data_out	),
		.clkin	( clk4			),
		.wr		( pcg8253_wr	),
		.gate		( pcg8253_gate	),
		.out		( pcg8253_out	)
	);

	//
	// AY-3-891x PSG Sound Gen.
	//
	wire			psg_wr0 = iorq & wr & ( cpu_adr[7:1] == 7'b1010_000 );
	wire			psg_wr1 = iorq & wr & ( cpu_adr[7:1] == 7'b1010_001 );
	wire [9:0]	psg_out0;
	wire [9:0]	psg_out1;

	// unit 0  A0h,A1h
	ltd891x psg891x_0 (
		.clk		( clk				),
		.reset	( reset			),
		.adr		( cpu_adr[0]	),
		.din		( cpu_data_out	),
		.wr		( psg_wr0		),
		.sclk		( clk3			),		// clock Source 3.58MHz
//		.sclk		( clk4			),		// clock Source 4MHz
		.dout		( psg_reg0		),
		.out		( psg_out0		)
	);
	
	// unit 1  A2h,A3h
	ltd891x psg891x_1 (
		.clk		( clk				),
		.reset	( reset			),
		.adr		( cpu_adr[0]	),
		.din		( cpu_data_out	),
		.wr		( psg_wr1		),
		.sclk		( clk3			),		// clock Source 3.58MHz
//		.sclk		( clk4			),		// clock Source 4MHz
		.dout		( psg_reg1		),
		.out		( psg_out1		)
	);

	
	//
	// SD Card
	//
	assign sd_clk = portB_out[0];
	assign sd_cmd = portB_out[1];
	assign sd_res = portB_out[2];

	always @(posedge clk) begin
		if (iorq & wr & ( cpu_adr[7:0] == 8'hfd ) ) begin
				portB_out <= cpu_data_out;
		end
	end


	//
	// CMT Interface UART
	//
	wire [7:0]	clk_baud;
	wire			rxd_in;
	wire			txc,rxc;
	wire			cmt_out;
	wire [1:0]	dem_rxc;
	wire			dem_out;
	reg [1:0] 	bs;
	
	// Buad Rate gen.
	baud_rate_gen baud_rate_gen (
		.clk			( clk48		),	// 48MHz		
		.clk_baud	( clk_baud	)	// Buad Rate x16
	);

	// UART 8251 (limited function)
	ltd8251 ltd8251 (
		.clk			( clk				),
		.reset		( reset			),
		.adr			( cpu_adr[0]	),
		.cs			( iorq & port20h	),
		.we			( wr				),
		.din			( cpu_data_out	),
		.dout			( uart_data 	),
		.txd			( txd				),
		.txc			( txc				),
		.rxd			( rxd_in			),
		.rxc			( rxc				),
		.status		( 					)
	);
	
	// CMT Modulator
	cmt_mod cmt_mod (
		.clk			( clk				),
		.clk2400		( clk_baud[7]	),
		.din			( txd & ~cinh	),
		.cmt_out		( cmt_out		)
	);
	
	// CMT Demodulator
	wire [3:0]	dem_tp;
	cmt_dem cmt_dem (
		.clk			( clk				),
		.clk76800	( clk_baud[2]	),
		.cmt_in		( cmt_in			),
		.clk_dem		( dem_rxc		),
		.dout			( dem_out		),
		.tp			( dem_tp			)	
	);

	assign	cdin = bs[1] ? 1'b1 : dem_out;
	assign	rxd_in = bs[1] ? rxd : dem_out;
	assign	txc = bs[1] ? clk_baud[2] : bs[0] ? clk_baud[6] : clk_baud[5];
	assign	rxc = bs[1] ? clk_baud[2] : bs[0] ? dem_rxc[1] : dem_rxc[0];
		
	//
	// OUT30h  BS, CINH, MOTOR
	// OUT40h  BEEP
	//
	reg 	motor;
	reg	beep_gate;

	always @(posedge clk) begin
		if ( iorq & wr) begin
			if ( port30h) begin
				bs <= cpu_data_out[5:4];
				motor <= cpu_data_out[3];
				cinh	<= cpu_data_out[2];

			end
			if ( port40h) 
				beep_gate <= cpu_data_out[5];
		end
	end	

	assign		audio_out[2:0] = pcg8253_out;
	assign		audio_out[3] = ( SW_CMT & motor) ? cmt_out : beep_out;
	assign		beep_out = beep_gate & clk_baud[7];
	assign		motor_out = motor;

	//
	// 1bit Audio DAC
	//
	wire [10:0] dac_in;
	wire [11:0] dac_sum;
	reg [10:0]	dac_fbk;
	reg			dac_bit;
   	
	assign dac_in = { 1'b0, psg_out0 } + { 1'b0, psg_out1 } +
						 { 3'b000, pcg8253_out[0], 7'b0000000 } +
						 { 3'b000, pcg8253_out[1], 7'b0000000 } +
						 { 3'b000, pcg8253_out[2], 7'b0000000 } +
						 { 3'b000, audio_out[3], 7'b0000000 };
   
	// delta-sigma Mod.
	assign dac_sum = { 1'b0, dac_in } + { 1'b0, dac_fbk };
	assign dac_out = dac_bit;

	always @( posedge clk) begin
		dac_fbk <= dac_sum[10:0];
		dac_bit <= dac_sum[11];
	end
	
	//
	// CPU fz80 Core
	//
	fz80 fz80(
		.clk			( clk				),
		.adr			( cpu_adr		),
		.reset_in	( reset			),
		.data_in		( cpu_data_in  ),
		.data_out	( cpu_data_out ),
		.mreq			( mreq			),
		.iorq			( iorq			),
		.rd			( rd				),
		.wr			( wr				),
		.intreq		( 1'b0			),
		.nmireq		( 1'b0			),
		.busreq		( busreq			), 
		.busack_out	( busack			),
		.waitreq		( waitreq		),
		.start		( start			),
		.intack_out	(					),
		.mr			(					)
	);
	

	//
	// CRTC & DMAC & VIDEO
	//
	crtc crtc(
		.clk			( clk				),
		.y_out		( 					),
		.c_out		( 					),
		.port30h_we	( iorq & wr & start & cpu_adr[7:4] == 4'h3	), 
		.crtc_we		( iorq & wr & start & cpu_adr[7:4] == 4'h5	), 
		.adr			( cpu_adr[0]	),
		.data			( cpu_data_out	),
		.busreq		( busreq			),
		.busack		( busack			),
		.ram_adr		( dma_adr		),
		.ram_data	( ram_data		),
		.clk2			( clk2			),
		.mode			( SW_GRN			),
		.bw_out		( bw_out			),
		.vga_hs		( vga_hs			),
		.vga_vs		( vga_vs			),	
		.vga_r		( vga_r			),	
		.vga_g		( vga_g			),	
		.vga_b		( vga_b			),
		.pcg_adr		( pcg_adr		),
		.pcg_data	( pcg_data		),
		.pcg_we		( pcg_we			),
		.pcg_mode	( pcg_mode		),
		.pcg_on		( pcg_on			),
		.fdc_cs		( fdc_cs			),
		.fdc_plt		( fdc_plt		),
		.plt_sel		( plt_sel		),		// *1
		.vsync		( vsync			)		// *1
	);

	//
	// Memory Selector
	//	
	wire [7:0]	biosrom_data;
	wire [7:0]	extrom_data;
	reg			en_ext_ram;
	reg			we_ext_ram;
	reg [3:0]	en_sel_ram;

	assign	mem_data = selmem( cpu_adr[15:13], ram_data, biosrom_data, extrom_data, en_ext_ram, en_sel_ram);
	
	function [7:0] selmem;
		input [2:0] adr;
		input [7:0] ram;
		input [7:0] rom1;
		input [7:0] rom2;
		input			en;
		input	[3:0]	sel;
			case ( adr)
				3'b000: selmem = en & sel[0] ? ram : rom1; // BIOS ROM 0000-1FFFh
				3'b001: selmem = en & sel[1] ? ram : rom1; // BIOS ROM 2000-3FFFh
				3'b010: selmem = en & sel[2] ? ram : rom1; // BIOS ROM 4000-5FFFf
				3'b011: selmem = en & sel[3] ? ram :
											SW_ROM ? rom2 : 8'hFF; // EXT ROM 6000-7FFFh
				default: selmem = ram;
			endcase
	endfunction
	
	always @(posedge clk) begin
		if ( reset)	begin
			en_ext_ram <= 1'b0;
			we_ext_ram <= 1'b1;
			en_sel_ram <= 4'hF;
		end
		else if ( iorq & wr & porte0h) begin
				if ( cpu_adr[3:0] == 4'h0 ) 	en_ext_ram <= 1'b0;
				if ( cpu_adr[3:0] == 4'h2 ) begin
														en_ext_ram <= cpu_data_out[0];
														we_ext_ram <= cpu_data_out[4];
				end
				if ( cpu_adr[3:0] == 4'h7 ) 	en_sel_ram <= cpu_data_out[7:4];
		end
	end

	//
	// SRAM
	//
	assign ram_adr = busack ? dma_adr[15:0] : cpu_adr;
	assign ram_we = busack ? 1'b0 : ( mreq & wr & ~start & ( cpu_adr[15] | we_ext_ram));
	
	sram sram (
		.address	( ram_adr			),
		.clock	( clk 				),
		.data		( cpu_data_out		),
		.wren		( ram_we				),
		.q			( ram_data			)
	);

	//
	// BASIC BIOS ROM
	//
	biosrom biosrom (
		.address	( cpu_adr[14:0]	),
		.clock	( clk					),
		.q			( biosrom_data	)
	);

	//
	// Extention ROM
	//
	extrom extrom (
		.address	( cpu_adr[12:0]	),
		.clock	( clk					),
		.q			( extrom_data	)
	);
	
	//
	// LED Display
	//
	reg[22:0]	dispcount = 0;
	reg[7:0]		disp_cpu_db;
	reg[15:0]	disp_cpu_ab;
	reg			disp_sd;
	assign 		LEDR = { en_ext_ram, disp_sd, disp_cpu_db};
	assign 		HEX0 = LED7SegDec( disp_cpu_ab[3:0]);
	assign 		HEX1 = LED7SegDec( disp_cpu_ab[7:4]);
	assign 		HEX2 = LED7SegDec( disp_cpu_ab[11:8]);
	assign 		HEX3 = LED7SegDec( disp_cpu_ab[15:12]);
	assign		HEX4 = 7'h7F;
	assign		HEX5 = 7'h7F;

	always @( posedge clk50) begin
		if ( dispcount > 23'd2_499_998 ) begin
				dispcount <= 0;
				disp_cpu_ab <= cpu_adr;
				disp_cpu_db <= cpu_data_in;
				disp_sd <= ~sd_dat;
		end
		else if( SW_OC)	dispcount <= dispcount + 23'd2;
		else 					dispcount <= dispcount + 23'd1;
	end
	
	function [6:0] LED7SegDec;
		input [3:0] num;
		begin
			case (num)
				4'h0:        LED7SegDec = 7'b1000000;  // 0
				4'h1:        LED7SegDec = 7'b1111001;  // 1
				4'h2:        LED7SegDec = 7'b0100100;  // 2
				4'h3:        LED7SegDec = 7'b0110000;  // 3
				4'h4:        LED7SegDec = 7'b0011001;  // 4
				4'h5:        LED7SegDec = 7'b0010010;  // 5
				4'h6:        LED7SegDec = 7'b0000010;  // 6
				4'h7:        LED7SegDec = 7'b1111000;  // 7
				4'h8:        LED7SegDec = 7'b0000000;  // 8
				4'h9:        LED7SegDec = 7'b0011000;  // 9
				4'ha:        LED7SegDec = 7'b0001000;  // A
				4'hb:        LED7SegDec = 7'b0000011;  // B
				4'hc:        LED7SegDec = 7'b0100111;  // C
				4'hd:        LED7SegDec = 7'b0100001;  // D
				4'he:        LED7SegDec = 7'b0000110;  // E
				4'hf:        LED7SegDec = 7'b0001110;  // F
				default:     LED7SegDec = 7'b1111111;  // LED OFF
			endcase
		end 
	endfunction	
	
	//
	// PLL 1
	//
	pll1 pll1 (
		.refclk		( clk50	),		// Clock in		50MHz
		.rst			( 1'b0	),
		.outclk_0	( clk2 	)		// clock out	28.63636MHz
	);
	
	reg [2:0]	cnt;
	assign 		clk = cnt[0];			// 14.31818MHz
	assign 		clk3 = cnt[2];			//  3.57954MHz
	always @ ( posedge clk2) begin
		cnt <= cnt + 3'b01;
	end
	
	//
	// PLL 2
	//
	pll2 pll2 (
		.refclk		( clk50	),		// Clock in		50MHz
		.rst			( 1'b0	),
		.outclk_0	( clk48 	)		// clock out	48MHz
	);
	
	//
	// CLOCK 4MHz
	//
	reg[1:0]		clkcnt;
	reg[2:0]		clkcnt2;
	always @ (posedge clk48) begin
		clkcnt <= clkcnt == 3 ? 0 : clkcnt + 1;
		if( clkcnt2 == 5) begin
			clkcnt2 <= 0;
			clk4 <= ~clk4;
		end
		else	clkcnt2 <= clkcnt2 + 1;
	end
	
endmodule
