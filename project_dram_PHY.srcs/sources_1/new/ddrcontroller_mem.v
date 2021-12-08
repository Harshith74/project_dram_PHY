`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.09.2021 14:49:54
// Design Name: 
// Module Name: ddrcontroller_mem
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ddrcontroller_mem;
parameter ADDR_BITS        =      14; // MAX Address Bits
parameter BA_BITS          =       3; // MAX Address Bits
parameter DQ_BITS          =       8; // Set this parameter to control how many Data bits are used       **Same as part bit width**

reg [4:0] cmd;
reg[15:0] in_addr;
reg i_valid;
reg clk;
reg write_en;
//`include "ddr3_model_parameters.vh"

//DRAM signals
wire rst_n;
reg reset_n;                         //Reset Signal
wire  ck;                            // complement of CPU Clock
wire  ck_n;                          //CPU Clock
wire  cke;                           //Clock_enable from MemController to Memory
wire  cs_n;                          //Chip Select Signal
wire  ras_n;                         //RAS Signal row to column signal
wire  cas_n;                         //CAS Signal column to data delay signal
wire  we_n  ;                         //Write or read enable signal
wire   [1-1:0]   dm_tdqs;
wire  [BA_BITS-1:0]   ba;            // bank Bits 
wire  [ADDR_BITS-1:0] addr;          //MAX Address Bits for the address bus
wire [DQ_BITS-1:0]   dq;              //data bits from/to memory controller form memory or CPU
wire   [1-1:0]  dqs;                    //data strobe signal
wire   [1-1:0]  dqs_n   ;              //Checks if data is valid and assigned to complement of Cpu clock
wire  [1-1:0]  tdqs_n;              //terminating Data strobe signal
wire   odt           ;                //on-die terminating Signal
wire rst_n_wire;
wire ck_wire; 

//always #50 clk = ~clk;
//always@(*)begin
//    ck = clk;
//end
//assign    rst_n_wire = rst_n;
//assign    ck_wire = ck;
    myDDR3 mem_controller(
    //from processor side:
     cmd,
     in_addr,
     i_valid,clk,
     write_en,reset_n,
    //DRAM signals
      rst_n,                         //Reset Signal
       ck,                            // complement of CPU Clock
       ck_n,                          //CPU Clock
       cke,                           //Clock_enable from MemController to Memory
       cs_n,                          //Chip Select Signal
       ras_n,                         //RAS Signal row to column signal
       cas_n,                         //CAS Signal column to data delay signal
       we_n,                         //Write or read enable signal
       dm_tdqs,
       ba,            // bank Bits 
       addr,          //MAX Address Bits for the address bus
       dq,              //data bits from/to memory controller form memory or CPU
       dqs,                    //data strobe signal
       dqs_n,                 //Checks if data is valid and assigned to complement of Cpu clock
    //logic  [1-1:0] 
       tdqs_n,                //terminating Data strobe signal
    //logic   
       odt                           //on-die terminating Signal
        );


    ddr3_model1 dd3_instance(
    rst_n,
    ck,
    ck_n,
    cke,
    cs_n,
    ras_n,
    cas_n,
    we_n,
    dm_tdqs,
    ba,
    addr,
    dq,
    dqs,
    dqs_n,
//    tdqs_n,
//    odt
);



initial begin
    reset_n = 0;
    i_valid = 0;
    write_en = 1;
    #200000;
    reset_n = 1;
    #10000;
    i_valid = 1;
    in_addr = 15;
    #10000;
//    write_en = 0;  
//    cmd = 
    #4000000;
//    $finish;    
end
endmodule
