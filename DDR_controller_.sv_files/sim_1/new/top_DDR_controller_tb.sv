`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.04.2023 20:20:15
// Design Name: 
// Module Name: top_ddr_controller_tb
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

`define SIZE_OF_ROW 64 //Number of bits in a row
`define N_ROW 64  // Number of rows
`define N_BANK 4  // Number of banks
`define DATA_W 8  // 8 bits data bus size

module top_DDR_controller_tb;

    
    // timing parameters
    localparam CLK_FREQ = 100; // MHz 10ns 
    localparam REF_RATE = 125; // refresh rate - ms  
    localparam integer cycles_bw_refresh = REF_RATE * CLK_FREQ; // it has to be periodically give the command to memory to make it self refreshed every 64ms
    
    
    // Address Bus sizes of which would be sending to DRAM
    localparam integer ROW_W = $clog2(`N_ROW);
    localparam integer BANK_W = $clog2(`N_BANK);
    localparam integer CLMN_W = $clog2(`SIZE_OF_ROW/`DATA_W);
    localparam integer D_ADDR_W = ROW_W > CLMN_W ? ROW_W : CLMN_W; 
    
    // Address bus and Data bus size on user side
    localparam integer U_ADDRESS_SIZE = BANK_W + ROW_W + CLMN_W; 
    localparam integer U_DATA_W = 16; // user side data_width 
    
    logic clk; // main clock
    
    // User - controller side inputs and outputs
    logic WR_command; // Write - 1 | Read - 0
    logic [10:0]DRAM_Address; // Address of the location given from processor to access it from the memory <bank_id, row_addr, col_addr>
    logic reset; // this would reset the state of the controller
    logic [U_DATA_W-1:0]Write_data; // Write data which has to be written into the memory
    logic [U_DATA_W-1:0]Read_data; // Read data which would be read out from the memory
    logic valid_data; // the read data is valid or not
    logic busy; // when it is not in the IDLE state then it would be high, no command would be executed until it comes to idle
    logic cmd_exec_ack; // command execution confirmation | it has recived the command to execute
    
    // controller - DRAM side inputs and outputs
    logic w_en;
    logic dram_ras; // signal which would be telling when to access the row
    logic dram_cas; // signal which would be telling when to access the column
    logic dram_dqs; // this would be the clock which would be given to the DRAM after certain amount of time
//    logic dram_ref_done; // ack signal which would be telling when the refresh is done
    wire [`DATA_W-1:0]dq;
    reg [`DATA_W-1:0]dq_in; // data bus
    logic[D_ADDR_W-1:0]d_addr; // address bus which would be going to the DRAM 
    logic refresh_request; // sending the request to refresh the memory contents in DRAM
    
    top_DDR_controller dut(.clk(clk), .reset(reset), .WR_command(WR_command), .DRAM_Address(DRAM_Address), .Write_data(Write_data), .Read_data(Read_data), .valid_data(valid_data), .dram_ras(dram_ras), .dram_cas(dram_cas), .dram_dqs(dram_dqs), .dq(dq), .w_en(w_en), .busy(busy), .cmd_exec_ack(cmd_exec_ack), .d_addr(d_addr), .refresh_request(refresh_request)); 
    
    initial begin
        clk = 0;
    end
    
    always #5 clk = ~clk;
    assign dq = (!WR_command)?dq_in:8'bzz;

    
    initial begin
        reset = 1;
        #30;
        reset = 0;
        WR_command = 1;
        DRAM_Address = 11'b01101011010;
        Write_data = 16'b1010101010101010;
        #10;
        Write_data = 16'b1111111100000000;
        #10;
        Write_data = 16'b1100110011001100;
        #10;
        Write_data = 16'b1110111011101110;
        #10;
        Write_data = 16'b0001000100010001;
        #145;
        #25;
        #10;
        #10;
        #10;
        #10;
        #75;
        WR_command = 0;
        DRAM_Address = 11'b01101101111; 
        #138;
        #300;
        dq_in = 8'b11111110;
        #5;
        dq_in = 8'b00010101;
        #5;
        dq_in = 8'b10011000;
        #5;
        dq_in = 8'b10010111;
        #5;
        dq_in = 8'b11010101;
        #5;
        dq_in = 8'b00010111;
        #5;
        dq_in = 8'b11110111;
    end
    
    
    initial begin
    #150000 ;
    $finish;
    end
endmodule 