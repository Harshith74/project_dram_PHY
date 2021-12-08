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

module myDDR3(
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
inout [1-1:0]  dqs,                    //data strobe signal
inout   [1-1:0]  dqs_n,                 //Checks if data is valid and assigned to complement of Cpu clock
output  [1-1:0]  tdqs_n,                //terminating Data strobe signal
output reg   odt                           //on-die terminating Signal
    );
//       `include "dd3_model_parameters.vh"

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
    parameter TRFC_MIN         =  260000; // tRFC       ps    Refresh to Refresh Command interval minimum value
	parameter TCCD             =       4;
	parameter T_RAS	 =15;	// From Row Addr to Precharge
	parameter T_RCD	 =6;	// Row to Column Delay
    parameter TRC              =   48750; // tRC        ps    Active to Active/Auto Refresh command time
    parameter TRCD             =   13750; // tRCD       ps    Active to Read/Write command time
    parameter TRP              =   13750; // tRP        ps    Precharge command period
	
	parameter T_CL	 =6;	// Column to Data Delay
	parameter T_RC	 =21;	// RP to Next RP Delay
	parameter T_BL	 =4;	// Burst Length in cycles
	parameter T_RP	 =6;	// Precharge Time
	parameter T_MRD	 =4;	// Precharge Time
    parameter TCWL	 =5;	// cwl
    parameter TMRD             =       4; // tMRD       tCK   Load Mode Register command cycle time
    parameter TMOD             =   15000; // tMOD       ps    LOAD MODE to non-LOAD MODE command cycle time
    parameter TXPR             =  270000; // tXPR       ps    Exit Reset from CKE assertion to a valid command
	parameter CLK_TP_NS = 2.5;
	parameter CLK_TP_PS = CLK_TP_NS * 1000;
    parameter TXP              = (3*(CLK_TP_PS) > 6000) ? 3 : 6000/CLK_TP_PS;
	parameter MAX_TIMER_COUNT_BITS =32;
    parameter TCK_MIN          =    1875; // tCK        ps    Minimum Clock Cycle Time
    integer TZQINIT            = 512;// max(512, ceil(640000/TCK_MIN)); // tZQinit    tCK   ZQ Cal (Long) time
    parameter TDQSH            =    0.45; // tDQSH      tCK   DQS input High Pulse Width
    
	localparam  ZQ_CAL = 0;// CAL_DONE, IDLE, ACT, READ, WRITE, WBURST, RBURST
    localparam  CAL_DONE = 1;
    localparam  IDLE = 2;
    localparam  ACT = 3;
     localparam  ACT2 = 13;
    localparam  READ = 4;
    localparam  WRITE = 5;
    localparam  WBURST = 6;
    localparam  RBURST = 7;
    localparam PRECHARGE = 8;
    localparam POWERUP = 9;
    localparam MRLOAD = 10;
    localparam AUTOPRE = 11;
    localparam DONE = 12;
    localparam REF = 14;
    localparam PRE = 15;

 
    reg [4:0] state,delay_state;
    
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
    
    reg[DQ_BITS-1:0] dq_reg;
    reg dqs_start,dqs_valid ;//= 1'bz;
    reg dqs_reg;
    assign dqs = dqs_reg;
    assign dqs_n = ~dqs;
    assign dq = dq_reg;
    always@(*) begin
     ck_n <= ~ck;
    end
    always@(*)
    begin
        if(dqs_valid) dqs_reg <= 1;
        if(dqs_start) dqs_reg <= ck;
    end
    
    always #(CLK_TP_PS / 2) ck = ~ck;
    timer timing_timer(.start(start_wire),.clk(ck),.timer_value(timer_value),.timer_done(timer_done));
    timer burst_timer(.start(burst_start_wire),.clk(ck),.timer_value(burst_timer_value),.timer_done(burst_timer_done));
    
    always@(posedge reset_n) begin
        ck = 0; 
    end
    
//    always@(posedge ck) begin
//        delay_state <= state;
//    end       
    always@(posedge ck) begin
//        $display("I am inside always block for state");
		if(!reset_n)	begin										
			state <= POWERUP; $display("\nI am here intial state = %d\n",state);	end									// state to POWERUP on reset
		else
			 case(state)
				POWERUP : begin
				    if(timer_done) 
				        state <= MRLOAD;				
				end
                
                MRLOAD : begin
                    if(timer_done)
                        state <= ZQ_CAL;
                end
                
				ZQ_CAL : begin
					if(timer_done)
						state <= PRE;							
				end


				IDLE : begin
					if(i_valid)
						state <= PRE;								// State to ACT if valid command
				end
                
                PRE: begin
                     if(timer_done)begin
					   state <= REF;	
					end
                end
                
                REF: begin
                     if(timer_done)begin
					   state <= ACT;	
					end
                end
                
                ACT: begin
                    if(timer_done)begin
					   state <= WRITE;	
					end
                end
				ACT2 : begin
					if(timer_done)begin
					   if(write_en) 	begin
					   			       state <= WRITE;
                       end
					   else                                state <= READ;
					end
				end

				WRITE : begin
				    $display("\ndq_reg = %d\n",dq_reg);
					if(timer_done) begin
						state <= WBURST;							//  State to WBURST on timer interrupt
//						dq_reg <= 0;
                        burst_start <= 1; end
				end

				READ : begin
					if(timer_done)
						state <= RBURST;							// State to READ BURST on timer interrupt
				end

				WBURST : begin
					if(burst_timer_done)
						state <= READ;							// State to PRECHARGE on timer interrupt
				end

				RBURST : begin
					if(burst_timer_done)
						state <= RBURST;							// State to PRECHARGE on timer interrupt
				end
                
//                AUTOPRE : begin
                    
//                end
               
                REF : begin
                   
                end
//				DONE : begin
//					state <= IDLE;
//				end

//				default : state <= POWERUP;							// State to POWERUP by default
			endcase			
	end
	
	always@(*)begin
	         if(!reset_n)	begin										
                state <= POWERUP; $display("\nI am here intial state = %d\n",state);	end									// state to POWERUP on reset
            else	
            begin		
			 case(state)
				POWERUP : begin
//					en <= 1'b1;
                    start <= 1;
                    timer_value <= (700000000/CLK_TP_PS) + (TXPR)/(CLK_TP_PS);       //based on clk it will change. eg 17500 for 250MHz
                    if(timing_timer.count == (200000/CLK_TP_NS))begin  //200us
                       rst_n <= 1; 
                    end
                    else if(timing_timer.count == ((700000/CLK_TP_NS))-1)begin //another 500 us
                       cke <= #120 1;	
                       cs <= #120 0;
                       ras <= #120 1;
                       cas <= #120 1;
                       we <= #120 1;                       
                       ba <= #120 3'b000;
                       addr <= #120 13'b00000000000000;
                    end 
                    else if((timing_timer.count < (200000/CLK_TP_NS)) && (timing_timer.count != 0))  begin
//                        $display("\ntimer_value = %d at time = %d\n timer_done = %d",timer_value,$time, timer_done);
                        rst_n <= 0;                      
                        cke <= 0;
                        cs <= 1;
                        odt <= 0;
                    end
				end
                
                
                MRLOAD : begin
                    timer_value <= 3*TMRD + (TMOD/CLK_TP_PS)+10;
                    if(timing_timer.count == 0 && ~timer_done)begin  //mode 3
                        ba <= #120 3'b010;
                        addr <= #120 13'b00000001000000;
                        cs <= #120 0;
                        ras <= #120 0;
                        we <= #120 0;
                        cas <= #120 0;
                    end                    
                    else if(timing_timer.count == TMRD)begin  //mode 3
                        ba <= #120 3'b011;
                        addr <= #120 0;
                        cs <= #120 0;
                        ras <= #120 0;
                        we <= #120 0;
                        cas <= #120 0;
                    end
                    else if(timing_timer.count == 2*TMRD)begin  //mode 1
                        ba <= #120 3'b001;
                        addr <= #120 4;
                        cs <= #120 0;
                        ras <= #120 0;
                        we <= #120 0;
                        cas <= #120 0;
                    end
                    else if(timing_timer.count == 3*TMRD)begin  //mode 0
                        ba <= #120 3'b000;
                        addr[8] <= #120 1;
                        {addr[6:4],addr[2]} <= #120 4'b0010;
                        addr[1:0] <= #120 2'b00;
                        cs <= #120 0;
                        ras <= #120 0;
                        we <= #120 0;
                        cas <= #120 0;
                    end
                    else begin
                        cs <= #120 0;
                        cas <= #120 1;
                        ras <= #120 1;
                        we <= #120 1;
                        ba <= #120 0;
                        addr <= #120 0;  
                     end                      
                end
				
				ZQ_CAL : begin
				    if(timing_timer.count == 0 && ~timer_done) begin
                        cs <= #120 0;
                        ras <= #120 1;
                        cas <= #120 1;
                        we <= #120 0;	
                        addr <= #120 14'b00010000000000;
                        odt <= #120 0;	
                        dq_reg <= #120 14'bz;
                        timer_value <= TZQINIT;			
                    end
                    else begin
                        cs <= #120 0;
                        cas <= #120 1;
                        ras <= #120 1;
                        we <= #120 1;
                        ba <= #120 0;
                        addr <= #120 0;  
                    end
				end

				IDLE : begin	
//				    cke <= 0;						
				end
                PRE : begin
                     if(timing_timer.count == 0 && ~timer_done) begin
                        cs <= #120 0;
                        ras <= #120 0;
                        cas <= #120 1;
                        we <= #120 0;
                        ba <= #120 1;
                        addr <= #120 14'b00_0000_0000_0001;
                        timer_value <= (TRP/CLK_TP_PS);
                      end
                      else begin
                        cs <= #120 0;
                        cas <= #120 1;
                        ras <= #120 1;
                        we <= #120 1;
                        ba <= #120 1;
                        addr <= #120 1;  
                      end
                end
                REF : begin
                    if(timing_timer.count == 0 && ~timer_done) begin
                        cs <= #120 0;
                        ras <= #120 0;
                        cas <= #120 0;
                        we <= #120 1;
                        timer_value <= (TRFC_MIN/CLK_TP_PS)*10;
                    end
                    else begin
                        cs <= #120 0;
                        cas <= #120 1;
                        ras <= #120 1;
                        we <= #120 1;
                        ba <= #120 0;
                        addr <= #120 0;  
                      end
                end
				ACT : begin
				     if(timing_timer.count == 0 && ~timer_done) begin
                        rst_n <= #120 1;
                        cs <= #120 0;
                        ras <= #120 0;
                        cas <= #120 1;
                        we <= #120 1;
                        ba <= #120 1;
                        addr <= #120 1;     //row address in ACT4
                        start <= 1;
                        timer_value <= (TRC/CLK_TP_PS);	
                     end
                     else begin
                        cs <= #120 0;
                        cas <= #120 1;
                        ras <= #120 1;
                        we <= #120 1;
                        ba <= #120 0;
                        addr <= #120 0;  
                      end
				end
                
                ACT2 : begin
				    rst_n <= #120 1;
					cs <= #120 0;
					ras <= #120 0;
					cas <= #120 1;
					we <= #120 1;
					ba <= #120 1;
					addr <= #120 1;     //row address in ACT4
					start <= 1;
					timer_value <= (TRC/CLK_TP_PS)+10;	
				end
                //initial cas latency   
				WRITE : begin
				    if(timing_timer.count == 0 && ~timer_done) begin
                        rst_n <= #120 1;
                        cs <= #120 0;
                        cke <= #120 1;
                        ras <= #120 1;
                        cas <= #120 0;
                        we <= #120 0;
                        ba <= #120 1;
                        addr[10] <= #120 0;     // set for auto precharge
                        addr[12] <= #120 1;
                        {addr[11],addr[9:0]} <= #120 1;     //row address in ACT	
//                        dq_reg <= #120 123;
                        start <= 1;
                        timer_value <= TCWL-1;	
                    end
                    else begin
                        cs <= #120 0;
                        cas <= #120 1;
                        ras <= #120 1;
                        we <= #120 1;
                        ba <= #120 0;
                        addr <= #120 0;  
                    end
                    				
				end

                //initial RAS latency
				READ : begin
				    if(timing_timer.count == 0 && ~timer_done) begin
                        rst_n <= #120 1;
                        cs <= #120 0;
                        cke <= #120 1;
                        ras <= #120 1;
                        cas <= #120 0;
                        we <= #120 1;
                        ba <= #120 1;
                        addr[10] <= #120 0;
                        addr[12] <= #120 1;
                        {addr[11],addr[9:0]} <= #120 1;     //row address in ACT	
                        start <= 1;
                        timer_value <= TCCD;	
                     end
                     else begin
                        cs <= #120 0;
                        cas <= #120 1;
                        ras <= #120 1;
                        we <= #120 1;
                        ba <= #120 0;
                        addr <= #120 0;  
                     end								
				end
                
                //count 4 cycles
				WBURST : begin
				    if(burst_timer.count == 0 && (~burst_timer_done)) begin
                            dqs_valid <= 1;
                           dqs_start <= 1;
                           burst_timer_value <= 5;			
				    end
//				    else dqs_valid <= 0;
				    if(burst_timer.count == 1 && (~burst_timer_done)) begin
                       dqs_valid <= 0;
                       dq_reg <= 1234;
	       		    end				    					
				end

				RBURST : begin	
				    burst_start <= 1;
					burst_timer_value <= 5;			
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
