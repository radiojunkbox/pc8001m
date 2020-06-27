//
// pcg8253.v
// Ver 0.1
//
// This Verilog HDL code is provided "AS IS", with NO WARRANTY.
//	NON-COMMERCIAL USE ONLY
//

//
// 8253 USART (Limited Function)
//
// Mode3 Only
//

module ltd8253 (
	input wire			clk,
	input	wire[1:0]	adr,
	input	wire[7:0]	din,
	input wire			wr,
	input wire			clkin,
	input wire[2:0]	gate,
	output wire[2:0]	out
	);

	reg _wr = 1'b0;
	reg [15:0]			cnt0, cnt1, cnt2;
	reg [15:0]			div0, div1, div2;
	reg					c0, c1, c2;
	reg					f0, f1, f2;
	
	//
	// Set Registor
	//
	always @ ( posedge clk) begin
		if ( wr & ~_wr) begin 
			case (adr)
			// Counter0
				2'b00: begin
					if ( f0) div0[15:8] <= din;
					else		div0[7:0] <= din;
					f0 <= ~f0;
				end
			// Counter1
				2'b01: begin
					if ( f1) div1[15:8] <= din;
					else		div1[7:0] <= din;
					f1 <= ~f1;
				end
			// Counter2
				2'b10: begin
					if ( f2) div2[15:8] <= din;
					else		div2[7:0] <= din;
					f2 <= ~f2;
				end
			// Control Word
				default: begin
					f0 <= 1'b0;
					f1 <= 1'b0;
					f2 <= 1'b0;
				end
			endcase
		end
		_wr <= wr;
	end		

	//
	// Counter
	//
	always @ ( posedge clkin) begin		
		// Counter0
		if ( cnt0 == { 1'b0, div0[15:1] }) c0 <= 1'b0;
		if ( cnt0 == 16'd0 ) begin
			cnt0 <= div0;
			c0 <= 1'b1;
		end
		else	cnt0 <= cnt0 - 16'd1;

		// Counter1
		if ( cnt1 == { 1'b0, div1[15:1] }) c1 <= 1'b0;
		if ( cnt1 == 16'd0 ) begin
			cnt1 <= div1;
			c1 <= 1'b1;
		end
		else	cnt1 <= cnt1 - 16'd1;

		// Counter2
		if ( cnt2 == { 1'b0, div2[15:1] }) c2 <= 1'b0;
		if ( cnt2 == 16'd0 ) begin
			cnt2 <= div2;
			c2 <= 1'b1;
		end
		else	cnt2 <= cnt2 - 16'd1;
	end

	assign out[0] = gate[0] ? c0 : 1'b0;
	assign out[1] = gate[1] ? c1 : 1'b0;
	assign out[2] = gate[2] ? c2 : 1'b0;		
	
endmodule
