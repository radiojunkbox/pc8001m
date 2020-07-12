//
// psg891x.v
//
// Author 		: RJB
//
// 2020/7/12	Ver0.1  first Edition	
//
// This Verilog HDL code is provided "AS IS", with NO WARRANTY.
//	NON-COMMERCIAL USE ONLY
//

//
// AY-3-891x PSG (Limited Function)
//

module ltd891x (
	input wire			clk,
	input wire			reset,
	input	wire 			adr,
	input	wire [7:0]	din,
	input wire			wr,
	input wire			sclk,
	output wire [7:0]	dout,
	output wire	[9:0]	out
	);

	reg 			_wr;
	reg [7:0]	creg [0:15];		// control register
	reg [3:0]	rnum;					// register number
	reg			trig;
	
	//
	// Set Registor
	//
	always @ ( posedge clk) begin
		if ( reset ) begin
			creg[rnum] <= rnum == 4'h7 ? 8'hFF : 8'h00;
			rnum <= rnum + 4'h1;
		end
		else if ( wr & ~_wr) begin 
			if( adr == 1'b0)	rnum <= din[3:0];
			else if ( adr == 1'b1)	 begin
				creg[rnum] <= din;
				if ( rnum == 4'hd) trig <= ~trig;
			end
		end
		_wr <= wr;
	end
	assign	dout = creg[rnum];

	wire [11:0]		periodA = { creg[1][3:0], creg[0] };
	wire [11:0]		periodB = { creg[3][3:0], creg[2] };
	wire [11:0]		periodC = { creg[5][3:0], creg[4] };
	wire [4:0]		periodN = creg[6][4:0]; 
	wire [5:0]	   enable = creg[7][5:0];
	wire [4:0]		ampA = creg[8][4:0];
	wire [4:0]		ampB = creg[9][4:0];
	wire [4:0]		ampC = creg[10][4:0];
	wire [15:0]		periodE = { creg[12], creg[11] };
	wire [3:0]		envShape = creg[13][3:0];
	
	//
	// Clock Div.
	//
	reg [3:0]	cnt;
	wire 			tclk = cnt[3];			// sclk / 16
	always @ ( posedge sclk) begin
		cnt <= cnt + 4'b01;
	end
	
	//
	// Tone Gen.
	//
	reg [11:0]			cntA, cntB, cntC;
	reg					toneA, toneB, toneC;
	
	always @ ( posedge tclk) begin		
		// Channel A
		if ( cntA == { 1'b0, periodA[11:1] }) toneA <= 1'b0;
		if ( cntA == 12'd0 ) begin
			cntA <= periodA;
			toneA <= 1'b1;
		end
		else	cntA <= cntA - 12'd1;

		// Channel B
		if ( cntB == { 1'b0, periodB[11:1] }) toneB <= 1'b0;
		if ( cntB == 12'd0 ) begin
			cntB <= periodB;
			toneB <= 1'b1;
		end
		else	cntB <= cntB - 12'd1;

		// Channel C
		if ( cntC == { 1'b0, periodC[11:1] }) toneC <= 1'b0;
		if ( cntC == 12'd0 ) begin
			cntC <= periodC;
			toneC <= 1'b1;
		end
		else	cntC <= cntC - 12'd1;
	end

	//
	// Noise Gen.
	//
	reg [4:0] 		cntN;
	reg [16:0]		lfsr = 17'd1;
	wire				noise = lfsr[0];
	
	always @ ( posedge tclk) begin
		if ( cntN == 5'd0 ) begin
			cntN <= periodN;
			lfsr <= { lfsr[0] ^ lfsr[3], lfsr[16:1] };
		end
		else	cntN <= cntN - 5'd1;
	end	
	
	//
	// Envelope Gen.
	//
	reg [15:0] 		cntE;
	reg [4:0]		ep;
	reg				_trig;
	wire [3:0]		env_out = env( envShape, ep);
	
	always @ ( posedge sclk) begin
		if ( trig != _trig) ep <= 5'h00;
		if ( cntE == 16'd0 ) begin
			cntE <= periodE;
			if ( ep < 5'h10 | ( envShape[3] & ~envShape[0]))	ep <= ep + 4'd1;
		end
		else	cntE <= cntE - 16'd1;
		_trig <= trig;			
	end
	
	function [3:0] env;
		input [3:0] shape;
		input	[4:0]	ep;
		casex ( shape)
				4'b00xx:	env = ep[4] ? 4'h0 : ~ep[3:0];
				4'b01xx:	env = ep[4] ? 4'h0 : ep[3:0];
				4'b1000:	env = ~ep[3:0];
				4'b1001:	env = ep[4] ? 4'h0 : ~ep[3:0];
				4'b1010:	env = ep[4] ? ep[3:0] : ~ep[3:0];
				4'b1011:	env = ep[4] ? 4'hF : ~ep[3:0];
				4'b1100:	env = ep[3:0];
				4'b1101:	env = ep[4] ? 4'hF : ep[3:0];
				4'b1110:	env = ep[4] ? ~ep[3:0] : ep[3:0];
				4'b1111:	env = ep[4] ? 4'h0 : ep[3:0];
				default:	env = 4'h0;
		endcase
	endfunction

	//
	// Mixer
	//
	wire [3:0]	mixA = ( toneA | enable[0] ) & ( noise | enable[3] ) ?
										4'h0 : ( ampA[4] ? env_out : ampA[3:0] );
	wire [3:0]	mixB = ( toneB | enable[1] ) & ( noise | enable[4] ) ?
										4'h0 : ( ampB[4] ? env_out : ampB[3:0] );
	wire [3:0]	mixC = ( toneC | enable[2] ) & ( noise | enable[5] ) ?
										4'h0 : ( ampC[4] ? env_out : ampC[3:0] );
	
	//
	// D/A Level Quantizer / Output
	//
	wire [7:0]	dacA = dacout( mixA );
	wire [7:0]	dacB = dacout( mixB );
	wire [7:0]	dacC = dacout( mixC );
	assign out = { 2'b00, dacA } + { 2'b00, dacB } + { 2'b00, dacC };
	
	function [7:0] dacout;
		input [3:0] dacin;
		case ( dacin)
				4'h0:		dacout = 8'h00;
				4'h1:		dacout = 8'h01;
				4'h2:		dacout = 8'h02;
				4'h3:		dacout = 8'h03;
				4'h4:		dacout = 8'h05;
				4'h5:		dacout = 8'h07;
				4'h6:		dacout = 8'h0B;
				4'h7:		dacout = 8'h0F;
				4'h8:		dacout = 8'h16;
				4'h9:		dacout = 8'h1F;
				4'hA:		dacout = 8'h2D;
				4'hB:		dacout = 8'h3F;
				4'hC:		dacout = 8'h5A;
				4'hD:		dacout = 8'h7F;
				4'hE:		dacout = 8'hB4;
				4'hF:		dacout = 8'hFF;
				default:	dacout = 8'h00;
		endcase
	endfunction
	
endmodule
