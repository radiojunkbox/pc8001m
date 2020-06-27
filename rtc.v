// RTC
// version 1.0

module rtc(clk, cstb, cclk, cin, cdata, ind);
	input clk;
	input [3:0] cin;
	input cstb, cclk;
	output cdata; // port10h
	output ind;
	reg [39:0] sr;
	reg [23:0] cnt = 0;
	reg cstb1 = 0, cclk1 = 0;
	wire cy0, cy1, cy2, cy3, cy4, cy5, cy6, cy7, load;
	wire [3:0] second0, minute0, hour0, day0, month;
	wire [2:0] second1, minute1;
	wire [1:0] hour1, day1;
	assign cy5 = cy3 & hour1[1] & hour0[1] & hour0[0];
	assign cy7 = cy5 & (month == 2 & day1[1] & day0[3] |
		(month == 4 | month == 6 | month == 9 | month == 11) & day1[1] & day1[0] |
		day1[1] & day1[0] & day0[0]);
	assign cnt_cy = cnt == 14318181;
	count10 c_second0(.clk(clk), .ci(cnt_cy), .co(cy0), .load(load), 
		.d(sr[6:3]), .q(second0));
	count6 c_second1(.clk(clk), .ci(cy0), .co(cy1), .load(load), 
		.d({ sr[1:0], sr[7] }), .q(second1));
	count10 c_minute0(.clk(clk), .ci(cy1), .co(cy2), .load(load), 
		.d(sr[14:11]), .q(minute0));
	count6 c_minute1(.clk(clk), .ci(cy2), .co(cy3), .load(load), 
		.d({ sr[9:8], sr[15] }), .q(minute1));
	count10c c_hour0(.clk(clk), .ci(cy3), .co(cy4), 
		.clr(cy5), 
		.load(load), .d(sr[22:19]), .q(hour0));
	count3c c_hour1(.clk(clk), .ci(cy4), 
		.clr(cy5), .load(load), 
		.d({ sr[16], sr[23] }), .q(hour1));
	count101 c_day0(.clk(clk), .ci(cy5), .co(cy6), 
		.set1(cy7), 
		.load(load), .d(sr[30:27]), .q(day0));
	count4c c_day1(.clk(clk), .ci(cy6), 
		.clr(cy7), 
		.load(load), .d({ sr[24], sr[31] }), .q(day1));
	count121 c_month(.clk(clk), .ci(cy7), .load(load), 
		.d({ sr[34:32], sr[39] }), .q(month));
	assign load = cstb & ~cstb1 & cin == 2;
	always @(posedge clk) begin
		cnt <= cnt_cy ? 0 : cnt + 1;
		cstb1 <= cstb;
		if (cstb & ~cstb1 & cin == 1) begin
			sr[3:0] <= second0;
			sr[6:4] <= second1;
			sr[7] <= 1'b0;
			sr[11:8] <= minute0;
			sr[14:12] <= minute1;
			sr[15] <= 1'b0;
			sr[19:16] <= hour0;
			sr[21:20] <= hour1;
			sr[23:22] <= 2'b00;
			sr[27:24] <= day0;
			sr[29:28] <= day1;
			sr[35:30] <= 6'b000000;
			sr[39:36] <= month;
		end
		cclk1 <= cclk;
		if (cclk & ~cclk1) begin
			sr[38:0] <= sr[39:1];
			sr[39] <= cin[0];
		end
	end
	assign cdata = sr[0];
	assign ind = cnt[23];
endmodule

module count10c(clk, clr, ci, co, load, d, q);
	input clk, ci, clr, load;
	output co;
	input [3:0] d;
	output [3:0] q;
	reg [3:0] q = 0;
	always @(posedge clk) begin
		if (load) q <= d;
		else if (clr) q <= 0;
		else if (ci) 
			if (co) q <= 0;
			else q <= q + 1;
	end
	assign co = ci & q[3] & q[0];
endmodule

module count101(clk, set1, ci, co, load, d, q);
	input clk, ci, load, set1;
	output co;
	input [3:0] d;
	output [3:0] q;
	reg [3:0] q = 0;
	always @(posedge clk) begin
		if (load) q <= d;
		else if (set1) q <= 1;
		else if (ci) 
			if (co) q <= 0;
			else q <= q + 1;
	end
	assign co = ci & q[3] & q[0];
endmodule

module count10(clk, ci, co, load, d, q);
	input clk, ci, load;
	output co;
	input [3:0] d;
	output [3:0] q;
	reg [3:0] q = 0;
	always @(posedge clk) begin
		if (load) q <= d;
		else if (ci) 
			if (co) q <= 0;
			else q <= q + 1;
	end
	assign co = ci & q[3] & q[0];
endmodule

module count3c(clk, ci, clr, load, d, q);
	input clk, ci, clr, load;
	input [1:0] d;
	output [1:0] q;
	reg [1:0] q = 0;
	always @(posedge clk) begin
		if (load) q <= d;
		else if (clr) q <= 0;
		else if (ci) q <= q + 1;
	end
endmodule

module count4c(clk, clr, ci, load, d, q);
	input clk, ci, load, clr;
	input [1:0] d;
	output [1:0] q;
	reg [1:0] q = 0;
	always @(posedge clk) begin
		if (load) q <= d;
		else if (clr) q <= 0;
		else if (ci) q <= q + 1;
	end
endmodule

module count6(clk, ci, co, load, d, q);
	input clk, ci, load;
	output co;
	input [2:0] d;
	output [2:0] q;
	reg [2:0] q = 0;
	always @(posedge clk) begin
		if (load) q <= d;
		else if (ci) 
			if (co) q <= 0;
			else q <= q + 1;
	end
	assign co = ci & q[2] & q[0];
endmodule

module count121(clk, ci, load, d, q);
	input clk, ci, load;
	input [3:0] d;
	output [3:0] q;
	reg [3:0] q = 0;
	always @(posedge clk) begin
		if (load) q <= d;
		else if (ci) 
			if (q[3] & q[2]) q <= 1;
			else q <= q + 1;
	end
endmodule

