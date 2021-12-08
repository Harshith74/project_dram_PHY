//`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.09.2021 05:47:41
// Design Name: 
// Module Name: myDDR3
// Project Name: memory controller
// Target Devices: 
// Tool Versions: 
// Description: testing different cmd and interfacing them with micron models
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ps / 1ps

module myDDR3_v2(
//from processor side:
input[4:0] cmd,
input[15:0] in_addr,
input i_valid,clk,
input write_en,reset_n,
//DRAM signals
output reg rst_n,                         //Reset Signal
output reg  ck,                            // complement of CPU Clock
output reg  ck_n,                          //CPU Clock
output reg  cke,                           //Clock_enable from MemController to Memory
output reg  cs,                          //Chip Select Signal
output reg  ras,                         //RAS Signal row to column signal
output reg  cas,                         //CAS Signal column to data delay signal
output reg  we,                         //Write or read enable signal
inout   [1-1:0]   dm_tdqs,
output reg  [BA_BITS-1:0]   ba,            // bank Bits 
output reg  [ADDR_BITS-1:0] addr,          //MAX Address Bits for the address bus
inout [DQ_BITS-1:0]   dq,              //data bits from/to memory controller form memory or CPU
inout   [1-1:0]  dqs,                    //data strobe signal
inout   [1-1:0]  dqs_n                 //Checks if data is valid and assigned to complement of Cpu clock
//logic  [1-1:0]  tdqs_n,                //terminating Data strobe signal
//logic   odt                           //on-die terminating Signal
    );
    parameter CWL_MAX          =      10; // CWL        tCK   Maximum CAS Write Latency     
    parameter DM_BITS          =       1; // Set this parameter to control how many Data Mask bits are used
	parameter ADDR_BITS        =      14; // MAX Address Bits
	parameter BA_BITS          =       3; // MAX Address Bits
	parameter ROW_BITS         =      14; // Set this parameter to control how many Address bits are used
	parameter COL_BITS         =      10; // Set this parameter to control how many Column bits are used
	parameter DQ_BITS          =       8; // Set this parameter to control how many Data bits are used       **Same as part bit width**
	parameter DQS_BITS         =       1; // Set this parameter to control how many Dqs bits are used
	parameter BURST_L	   	   =	   8; // Burst Length
	parameter ADDR_MCTRL	   =	  32; // Address to the Controller
	
	parameter T_RAS	 =15;	// From Row Addr to Precharge
	parameter T_RCD	 =6;	// Row to Column Delay
	parameter T_CL	 =6;	// Column to Data Delay
	parameter T_RC	 =21;	// RP to Next RP Delay
	parameter T_BL	 =4;	// Burst Length in cycles
	parameter T_RP	 =6;	// Precharge Time
	parameter T_MRD	 =4;	// Precharge Time
	parameter MAX_TIMER_COUNT_BITS =32;
	localparam  ZQ_CAL = 0;// CAL_DONE, IDLE, ACT, READ, WRITE, WBURST, RBURST
    localparam  CAL_DONE = 1;
    localparam  IDLE = 2;
    localparam  ACT = 3;
    localparam  READ = 4;
    localparam  WRITE = 5;
    localparam  WBURST = 6; 
    localparam  RBURST = 7;
    localparam PRECHARGE = 8;
    localparam POWERUP = 9;
    localparam MRLOAD = 10;
    localparam AUTOPRE = 11;
    localparam DONE = 12;
   
    always@(*) begin
        cs <= cmd[0];
        ras <= cmd[1];
        cas <= cmd[2];
        we <= cmd[3];        
    end
    reg [4:0] state = IDLE;
    
    reg start;
    wire start_wire;
    assign start_wire = start; 
    reg[MAX_TIMER_COUNT_BITS-1:0] timer_value = 0;
    wire timer_done;
    
    reg burst_start;
    wire burst_start_wire;
    assign burst_start_wire = burst_start;
    reg[MAX_TIMER_COUNT_BITS-1:0] burst_timer_value = 0;
    wire burst_timer_done;
    
    always@(*) begin
     ck_n <= ~ck;
    end
    always #500 ck = ~ck;
    timer t1ming_timer(.start(start_wire),.clk(ck),.timer_value(timer_value),.timer_done(timer_done));
    timer burst_timer(.start(burst_start_wire),.clk(ck),.timer_value(burst_timer_value),.timer_done(burst_timer_done));
    
    always@(posedge reset_n) begin
        ck = 0; 
    end
    
    
    always@(posedge ck) begin
        $display("I am inside always block for state");
		if(!reset_n)	begin										
			state <= IDLE; $display("I am here");	end									// state to POWERUP on reset
		else
			 case(state)
//				POWERUP : begin
//				end

				ZQ_CAL : begin
					if(timer_done)
						state <= IDLE;    							
				end


				IDLE : begin
					if(i_valid && cmd == ACT)
						state <= ACT;								// State to ACT if valid command
				end

				ACT : begin
					if(timer_done)begin
					   if(cmd == WRITE) 				       state <= WRITE;
					   else if(cmd == READ)                    state <= READ;
					   else state <= ACT;
					end
				end

				WRITE : begin
					if(timer_done)
						state <= WBURST;							//  State to WBURST on timer interrupt
				end

				READ : begin
					if(timer_done)
						state <= RBURST;							// State to READ BURST on timer interrupt
				end

				WBURST : begin
					if(burst_timer_done)
						state <= AUTOPRE;							// State to PRECHARGE on timer interrupt
				end

				RBURST : begin
					if(burst_timer_done)
						state <= AUTOPRE;							// State to PRECHARGE on timer interrupt
				end
                
//                AUTOPRE : begin
                    
//                end
//                PRECHARGE: begin
                
//                end
                
//				DONE : begin
//					state <= IDLE;
//				end

//				default : state <= POWERUP;							// State to POWERUP by default
			endcase			
	end
	
	always@(*)begin
			
			
			 case(state)
				POWERUP : begin
					
				end

				ZQ_CAL : begin					

				end

				IDLE : begin	
				    cke <= 0;						
				end

				ACT : begin
				    rst_n <= 1;
					cs <= 0;
					ras <= 0;
					cas <= 1;
					we <= 1;
					ba <= in_addr[2:0];
					addr <= in_addr[15:3];     //row address in ACT4
					start <= 1;
					timer_value <= T_RCD;	
				end

                //initial cas latency   
				WRITE : begin
				    rst_n <= 1;
					cs <= 0;
					cke <= 1;
					ras <= 1;
					cas <= 0;
					we <= 0;
					ba <= in_addr[2:0];
					addr[10] <= 0;     // set for auto precharge
					addr[12] <= 1;
					{addr[11],addr[9:0]} <= in_addr[15:3];     //row address in ACT		
					start <= 1;
					timer_value <= T_RAS;					
				end

                //initial RAS latency
				READ : begin
				    rst_n <= 1;
					cs <= 0;
					cke <= 1;
					ras <= 1;
					cas <= 0;
					we <= 1;
					ba <= in_addr[2:0];
					addr[10] <= 0;
					addr[12] <= 1;
					{addr[11],addr[9:0]} <= in_addr[15:3];     //row address in ACT	
					start <= 1;
					timer_value <= T_RAS;									
				end
                
                //count 4 cycles
				WBURST : begin
				    burst_start <= 1;
					burst_timer_value <= 8;						
				end

				RBURST : begin	
				    burst_start <= 1;
					burst_timer_value <= 8;			
				end
                
//                AUTOPRE: begin
                
//                end
//                PRECHARGE: begin
                
//                end
//				DONE : begin
//					state <= IDLE;
//				end

//				default : state <= IDLE;							
			endcase			
	end
endmodule


module timer #(parameter MAX_TIMER_COUNT_BITS =32)(
inout start,
input clk,
input[MAX_TIMER_COUNT_BITS-1:0] timer_value,
output reg timer_done
);
reg [MAX_TIMER_COUNT_BITS-1:0] count = 0; 
    always@(posedge clk) begin
        if(start & (~timer_done)) begin
            if(count != timer_value) begin
                count <= count + 1;
            end
            else begin
                timer_done <= 1;
                count <= 0;
            end
        end
        else timer_done <= 0;
    end
endmodule
