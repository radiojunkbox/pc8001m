//
// cmt.v 
// Ver. 0.1
//
// This Verilog HDL code is provided "AS IS", with NO WARRANTY.
//	NON-COMMERCIAL USE ONLY
//

//
// 8251 USART (Limited Function)
//
// Fixed Mode ASYNC
// Tx CEh - 8bit, Stop 2bit, None, x16
// Rx 4Eh - 8bit, Stop 1bit, None, x16

module ltd8251 (
	input wire 			clk,
	input wire 			reset,
	input wire 			adr,
	input	wire			cs,
	input wire			we,
	input wire [7:0]	din,
	output wire [7:0]	dout,
	// Tx
	input wire 			txc,
	output reg 			txd,
	// Rx
	input wire 			rxc,
	input wire 			rxd,
	// Status reg
	output reg [7:0]	status
);

	reg [7:0]	cmd;
	reg [7:0]	txdata;
	reg			txbusy, _txbusy;
 	reg [7:0]	rxdata;
	reg			rxdone, _rxdone;
	reg [1:0]	rxerr, _rxerr;

	reg			_we;
			
	assign		dout = adr ? status : rxdata;
	
	// Contorol
	always @( posedge clk) begin
		if( reset) begin
			status <= 8'h01;
			cmd <= 8'h00;
		end
		else if( cmd[4]) begin
			status[5:4] <= 2'b00;					// OE FE reset
			cmd[4] <= 1'b0;
		end
		else if ( cs) begin
			if ( we & ~_we)	 begin
				if ( adr)	cmd <= din;
				else begin
								txdata <= din;
								status[0] <= 1'b0;	// TxRDY 0								
				end
			end
			else begin
				if ( ~adr)	status[1] <= 1'b0;	// RxRDY 0
			end
		end
		else begin
			if ( txbusy & ~_txbusy) status[0] <= 1'b1;		// TxRDY 1
 			if ( rxdone & ~_rxdone) status[1] <= 1'b1;		// RxRDY 1
			if ( rxerr[0] & ~_rxerr[0]) status[4] <= 1'b1; 	// OE 1
			if ( rxerr[1] & ~_rxerr[1]) status[5] <= 1'b1; 	// FE 1
		end
		_we <= we;
		_txbusy <= txbusy;
		_rxdone <= rxdone;
		_rxerr <= rxerr;
	end
		
	// TX
	reg			_txc;
	reg [1:0]	txsts;
	reg [7:0]	txcnt;
	reg [10:0]	txbuf;

	always @( posedge clk) begin
		if( reset) begin
			txd <= 1'b1;
			txbusy <= 1'b0;
			txsts <= 2'b00;
		end
		else if( (txsts == 2'b00) & ~status[0]) begin
			txbuf <= { 2'b11, txdata, 1'b0 };
			txcnt	<= 8'h00;
			txbusy <= 1'b1;
			txsts <= 2'b01;
		end	
		else if( txsts == 2'b01 ) begin
			txsts <= 2'b10;
		end
		else if( (txsts == 2'b10) & txc & ~_txc) begin
			if ( txcnt[3:0] == 4'h0)  begin
				txd <= txbuf[0];
				txbuf <= { 1'b1, txbuf[10:1]};
			end
			else if ( txcnt == 8'hAF)	begin
				txbusy <= 1'b0;
				txsts <= 2'b11;
			end
			txcnt <= txcnt + 8'h01;
		end
		else if( txsts == 2'b11 ) begin
				txsts <= 2'b00; // to Idle
		end
		_txc <= txc;	
	end

	// RX
	reg			_rxc;
	reg [1:0]	rxsts;
	reg [3:0]	s;
	reg [7:0]	rxcnt;
	reg [9:0]	rxbuf;
	wire			detfd = s == 4'b1100;
		
	always @( posedge clk) begin
		if( reset) begin
			rxdata <= 8'h00;
			rxdone <= 1'b0;
			rxerr <= 2'b00;
			rxsts <= 2'b00;
		end
		else if ( rxc & ~_rxc) begin
			
			if ( rxsts == 2'b00) begin
				if ( detfd) begin
					rxcnt <= 8'h02;
					rxerr <= 2'b00;
					rxsts <= 2'b01;
				end
			end
			else if ( rxsts == 2'b01) begin
				if ( rxcnt[3:0] == 4'h8) begin
					rxbuf <= { rxd, rxbuf[9:1]};
					if ( rxcnt[7:4] == 4'h9) rxsts <= 2'b10;
				end
				rxcnt <= rxcnt + 8'h01;
			end
			else if ( rxsts == 2'b10) begin
				if ( rxbuf[9] == 1'b0)	rxerr[1] <= 1'b1;	// FE
				else	begin
					if( status[1]) rxerr[0] <= 1'b1;			// OE
					rxdone <= 1'b1;								// RX Done
				end
				rxdata <= rxbuf[8:1];
				rxsts <= 2'b11;
			end
			else if ( rxsts == 2'b11) begin
				rxdone <= 1'b0;
				rxsts <= 2'b00;
			end
			else rxcnt <= rxcnt + 8'h01;
			s <= { s[2:0], rxd};
		end
		_rxc <= rxc;
	end
	
endmodule

//
// CMT Modulator
//
module cmt_mod (
	input wire 			clk,
	input wire 			clk2400,
	input wire 			din,
	output reg			cmt_out
	);

	reg	_clk2400;
	
	always @( posedge clk) begin

		if( clk2400 & ~_clk2400)			cmt_out <= ~cmt_out;
		if( ~clk2400 & _clk2400 & din)	cmt_out <= ~cmt_out;

		_clk2400 <= clk2400;
	end

endmodule

//
// CMT Demodulator
//
module cmt_dem (
	input wire 			clk,
	input wire 			clk76800,
	input wire 			cmt_in,
	output wire [1:0]	clk_dem,
	output reg			dout,
	output wire	[3:0]	tp
	);

	reg [6:0]	cnt;
	reg 			_cnt;
	reg			_clk76800;
	reg			dcmt,_dcmt;
	reg			_cmt_in;
	reg			qff;
	wire			ck1, ck2, rst;

	reg [3:0]	scnt;
	reg [3:0]	ssum;
	
	assign	ck1 = ~clk76800 & _clk76800;	// IC77 pin1 in
	assign	rst = dcmt == ~_dcmt;			// IC76 pin3 out
	assign	ck2 = &cnt[4:3] & ~_cnt;		// IC83 pin3 in
	assign	clk_dem = cnt[3:2];
	
	assign	tp[3] = qff;
	assign	tp[2] = ck1;
	assign	tp[1] = rst;
	assign	tp[0] = dcmt;
	
	always @( posedge clk) begin

		if( scnt == 4'hF) begin
			scnt <= 4'h0;
			ssum <= 4'h0;
			if ( ssum >= 4'b1110)	dcmt <=  1'b1;
			else if ( ssum <= 4'b0001)	dcmt <=  1'b0;
		end
		else begin
			ssum <= ssum + { 3'h0, cmt_in};
			scnt <= scnt + 4'h1;
		end	
	
		// IC77 4024
		if( rst)			cnt <= 7'd0;
		else if( ck1)	cnt <= cnt + 7'd1;

		// IC83 4013 1/2
		if( rst)			qff <= 1'b0;
		else if( ck2) 	qff <= 1'b1;

		// IC83 4013 2/2
		if ( rst)		dout <= ~qff;	
		
		_dcmt <= dcmt;
		_clk76800 <= clk76800;
		_cnt <= &cnt[4:3];
	end
	
endmodule

//
// Baud Rate Generator
//
module baud_rate_gen (
	input	wire			clk,			// 48MHz		
	output wire [7:0]	clk_baud		// 2400, 4800, 9600, 19200, 38400, 76800, 153600, 307200Hz
);

	reg [7:0]	precnt;
	reg [7:0]	clkcnt;

	assign 		clk_baud = clkcnt;

	always @( posedge clk) begin
		if( precnt == 8'd77) begin
			precnt <= 8'd0;
			clkcnt <= &clkcnt ? 8'd0 : clkcnt + 8'd1;
		end
		else	precnt <= precnt + 8'd1;
	end
		
endmodule
