`timescale 1ns / 1ps

`define SIZE_OF_ROW 64 //Number of bits in a row
`define N_ROW 64  // Number of rows
`define N_BANK 4  // Number of banks
`define DATA_W 8  // 8 bits data bus size

module top_DDR_controller(clk, reset, WR_command, DRAM_Address, Write_data, Read_data, valid_data, dram_ras, dram_cas, dram_dqs, dq, w_en, busy, cmd_exec_ack, d_addr, refresh_request);    
    
    // timing parameters
    localparam CLK_FREQ = 100; // MHz 10ns 
    localparam REF_RATE = 125; // refresh rate - ms  
    localparam integer cycles_bw_refresh = REF_RATE * CLK_FREQ; // it has to be periodically give the command to memory to make it self refreshed every 64ms
    
    // latencies of DDR DRAM   
    localparam T_RC = 39; // Activate  to Activate
    localparam T_RAS = 28; // taking 28 cycles (activate to precharge) how much the has to be kept activate
    localparam T_CAS = 11; // time taken to receive the signal the data present in the column to be transmitted by the bus
    localparam T_BURST = 5; // it would four cycles to burst all the data that would be there on the column
    localparam T_RCD = T_RAS - T_CAS - T_BURST; // time taken to shift the stage to read/write // 13
    localparam T_PRE = 11; // time taken to precharge
    localparam T_REF = 1000; // time taken to refresh the memory
    
    // Address Bus sizes of which would be sending to DRAM
    localparam integer ROW_W = $clog2(`N_ROW);
    localparam integer BANK_W = $clog2(`N_BANK);
    localparam integer CLMN_W = $clog2(`SIZE_OF_ROW/`DATA_W);
    localparam integer D_ADDR_W = ROW_W > CLMN_W ? ROW_W : CLMN_W; 
    
    // Address bus and Data bus size on user side
    localparam integer U_ADDRESS_SIZE = BANK_W + ROW_W + CLMN_W; 
    localparam integer U_DATA_W = 16; // user side data_width 
    localparam integer U_WORDS = 4; // user side data to be written into the memory
    
    // clk 
    input clk; // main clock
    
    // User - controller side inputs and outputs
    input WR_command; // Write - 1 | Read - 0
    input [10:0]DRAM_Address; // Address of the location given from processor to access it from the memory <bank_id, row_addr, col_addr>
    input reset; // this would reset the state of the controller
    input [U_DATA_W-1:0]Write_data; // Write data which has to be written into the memory
    output reg [U_DATA_W-1:0]Read_data; // Read data which would be read out from the memory
    output reg valid_data; // the read data is valid or not
    output busy; // when it is not in the IDLE state then it would be high, no command would be executed until it comes to idle
    output reg cmd_exec_ack; // command execution confirmation | it has recived the command to execute
    
    // controller - DRAM side inputs and outputs
    output reg w_en;
    output reg dram_ras; // signal which would be telling when to access the row
    output reg dram_cas; // signal which would be telling when to access the column
    output dram_dqs; // this would be the clock which would be given to the DRAM after certain amount of time
//    input dram_ref_done; // ack signal which would be telling when the refresh is done
    inout [`DATA_W-1:0]dq; // data bus
    output reg [D_ADDR_W-1:0]d_addr; // address bus which would be going to the DRAM 
    output reg refresh_request; // sending the request to refresh the memory contents in DRAM
    
    reg [`DATA_W-1:0]dram_wr_data;
    reg [`DATA_W-1:0]dram_rd_data;
    
    // internal states and signals of the controller
    typedef enum logic [3:0] {IDLE = 4'b0000, ACTIVATE = 4'b0001, ACTIVATE_WAIT = 4'b0010, READ = 4'b0011, READ_WAIT = 4'b0100, WRITE = 4'b0101, WRITE_WAIT = 4'b0110, PRECHARGE = 4'b0111, PRECHARGE_WAIT = 4'b1000, REFRESH = 4'b1001, REFRESH_WAIT = 4'b1010, BURST_WAIT = 4'b1011} state;
    state controller_state;
    state next_controller_state;
    
//    state next_target_state;
//    state target_state;
    
    reg [`N_BANK - 1:0]open_row; // storing the information of whether certain bank have open_row or not
    reg [ROW_W - 1:0]active_row[(`N_BANK - 1):0]; // tracking which row is active in different banks 
    reg dram_clk_en; // helping to generate the dqs signal 
    reg [D_ADDR_W-1:0] column_addr; // coulmn address
    reg [D_ADDR_W-1:0] row_addr; // row address
    reg [D_ADDR_W-1:0] bank_id; // bank id
    
    // controller temporary_registers
    reg [U_DATA_W-1:0]temp_write_data[U_WORDS-1:0];
    reg [6:0]data_counter;
    reg temp_cmd; // temp_cmd -> (1) write | (0) read
    
    assign dq = (WR_command)?dram_wr_data:8'bz; // giving the ouptut from the controller which would be sending the write data that has to be written into the memory
    assign dram_dqs = (dram_clk_en)?clk:1'bz; // this is the clk which would be sending to the DRAM after TCAS latency
    assign busy = (controller_state!=IDLE)?1:0; // busy signal which would be telling to not give any operation until it is executed 
    
    // assigning the addresses    
    always@(posedge clk) begin
    if(reset) begin
        data_counter <= 0;
    end
    else begin
      if(((controller_state == ACTIVATE)||(controller_state == ACTIVATE_WAIT)) && data_counter < T_RCD+2) begin
        if(temp_cmd && (data_counter<4)) temp_write_data[data_counter] <= Write_data; // latching the input write data into the controller registers
        data_counter <= data_counter + 1;  
      end
    end
    end
    
    always@(posedge clk) begin
      if(reset) begin
        column_addr <= 0;
        row_addr <= 0;
        bank_id <= 0;
        cmd_exec_ack <= 0;
      end
      else if((controller_state == IDLE) && !cmd_exec_ack) begin
        column_addr <= {3'b0,DRAM_Address[2:0]}; 
        row_addr[D_ADDR_W-1:0] <= DRAM_Address[8:3];
        bank_id <=  {4'b0, DRAM_Address[10:9]};
        cmd_exec_ack <= 1'b1; // command execution 
        temp_cmd <= WR_command;
      end
      else cmd_exec_ack <= 0;
     end
     
    always@(posedge clk) begin
    
        if(reset) begin
            controller_state <= IDLE;
        end
        else begin
            controller_state <= next_controller_state;
        end
        
    end
    
	reg [8:0]RCD_counter;
	reg [8:0]CAS_counter;
	reg [8:0]PRE_counter;
	reg [8:0]BURST_counter;
	reg [8:0]REF_counter;
	reg read_flag;
	
    always@(posedge clk) begin
	    if(reset) begin
	       RCD_counter = T_RCD;
	       CAS_counter = T_CAS;
	       PRE_counter = T_PRE;
	       BURST_counter = T_BURST-1;
	       REF_counter = T_REF;
	    end
	    else begin
            case(controller_state)
                ACTIVATE_WAIT:RCD_counter = (RCD_counter==0)?T_RCD:RCD_counter-1;
                PRECHARGE_WAIT:PRE_counter = (PRE_counter==0)?T_PRE:PRE_counter-1;
                WRITE_WAIT:CAS_counter = (CAS_counter==0)?T_CAS:CAS_counter-1;
                READ_WAIT:CAS_counter = (CAS_counter==0)?T_CAS:CAS_counter-1;
                BURST_WAIT:BURST_counter = (BURST_counter==0)?T_BURST-1:BURST_counter-1;
                REFRESH_WAIT:REF_counter = (RCD_counter==0)?T_REF:REF_counter-1;
            endcase 
        end
    end

	//FSM

	
	always@(*) begin
	    
        case(controller_state)
            
            IDLE: begin
                read_flag = 0;
                if(refresh_request) begin 
                    if(open_row == 0) begin  
                       next_controller_state = REFRESH; // no open row, execute refresh
                    end
                    
                    else begin
                       next_controller_state = PRECHARGE; // when there are any open rows execute precharge 
                    end
                end
                
                else begin // confirms that command is recieved by the DRAM
                    if(open_row[bank_id] && (row_addr == active_row[bank_id]) && cmd_exec_ack) begin //ROW HIT
                        if(WR_command)	begin
                          next_controller_state = WRITE; // WRITE to the open row
                        end
                        else begin 
                          next_controller_state = READ; // READ from the open row 
                        end
                    end
                    
                    else if(open_row[bank_id] && (row_addr != active_row[bank_id]) && cmd_exec_ack) begin // ROW MISS
                        next_controller_state = PRECHARGE; // dram address should be active_row address
                    end
                    
                    else if(cmd_exec_ack) begin // when row buffer is empty
                        $display("%d","%d",bank_id, open_row[bank_id]);
                        next_controller_state = ACTIVATE;
                    end
                    
                    else next_controller_state = IDLE;
                end
                
            end
            
            PRECHARGE: begin
            read_flag = 0;
            next_controller_state = PRECHARGE_WAIT;
            end
            
            PRECHARGE_WAIT: begin
            read_flag = 0;
             if(PRE_counter == 0) begin
                 if(refresh_request) begin
                     next_controller_state = REFRESH;
                 end
                 else begin
                     next_controller_state = ACTIVATE; //closing a row to open another //dram address should address of the active row buffer
                 end
             end
            end
            
            ACTIVATE: begin 
            read_flag = 0;
            next_controller_state = ACTIVATE_WAIT;
            end
            
            ACTIVATE_WAIT: begin
            read_flag = 0;
             if(RCD_counter == 0) begin // after RCD delay 
                 if(temp_cmd) next_controller_state = WRITE; 
                 else next_controller_state = READ;
             end
             else next_controller_state = ACTIVATE_WAIT;
            end
            
            WRITE: begin
            read_flag = 0;
            next_controller_state = WRITE_WAIT; 
            end
            
            WRITE_WAIT: begin
            read_flag = 0;
             if(CAS_counter == 0) begin
                 next_controller_state = BURST_WAIT;
             end
             else next_controller_state = WRITE_WAIT; // end of write operation
            end
            
            READ: begin
            next_controller_state = READ_WAIT; 
            read_flag = 0;
            end
            
            READ_WAIT: begin
             if(CAS_counter == 0) begin
                 next_controller_state = BURST_WAIT; // end of read operation
                 read_flag = 1; // at the end of this stage read would be valid to do
             end 
             else next_controller_state = READ_WAIT;
            end
            
            BURST_WAIT: begin
            read_flag = 1; // reading can be started 
             if(BURST_counter == 0) begin
                 next_controller_state = IDLE;
             end 
             else next_controller_state = BURST_WAIT;
            end
            
//			REFRESH: 
//			     if(dram_ref_done) begin 
//			         next_controller_state = IDLE;
//			     end 

            REFRESH: begin 
            read_flag =0; 
            next_controller_state = REFRESH_WAIT;
            end
            
            REFRESH_WAIT: begin
            read_flag = 0;
             if(REF_counter == 0) begin
                 next_controller_state = IDLE; 
             end
            end
                  
        endcase
    end
    
 
    reg [$clog2(cycles_bw_refresh)-1:0]refresh_counter;
    
    // referesh counter logic
    always@ (posedge clk) begin
      if(reset) begin
        refresh_counter <=  cycles_bw_refresh; // initially loading the refresh counter when it is reset 
        refresh_request <= 0;
      end
      else begin
        if(!refresh_counter) begin
		  // ensuring the refresh operation in dram is done
          if(!REF_counter) begin
            refresh_counter <=  cycles_bw_refresh;
            refresh_request <= 0; //  making the refresh request as 0 
          end
          else refresh_request <= 1'b1; // keeping the refresh request as 1 until it gets the acknowledgement signal from the 
        end
        else begin
          refresh_counter <= refresh_counter - 1'b1;
          refresh_request <= 0;
        end
      end
    end
    
    // appropriate commands
    always@(*) begin
		dram_ras = 1'b0;
		dram_cas = 1'b0;
		w_en	= 1'b0;
		dram_clk_en = 1'b0;
		case(controller_state)
			IDLE: begin
				//do nothing
			end
			
			PRECHARGE_WAIT: begin
				dram_ras = 1'b1;
				w_en = 1'b1;
			end
			
			ACTIVATE: dram_ras = 1'b1;
			
			ACTIVATE_WAIT: dram_ras = 1'b1;  
			
			WRITE_WAIT: dram_cas = 1'b1;
			
			BURST_WAIT: dram_clk_en = 1'b1; 
			
			READ: begin
			dram_cas = 1'b1;
			end
			
			READ_WAIT: begin 
			dram_cas = 1'b1;
			end
			
			REFRESH_WAIT: begin
				dram_ras = 1'b1;
				dram_cas = 1'b1;
				w_en = 1'b1;
			end 
		endcase
	  
    end
    
    // sending the addresses to the address bus based on the present state  
	always@(*) begin
		d_addr = column_addr;
		case(controller_state)
			PRECHARGE_WAIT: d_addr = active_row[bank_id]; // sending the address of the open row present in the row buffer to the bank.
			
			ACTIVATE_WAIT: d_addr = row_addr;  // load the row_addr that has to be activate
			
			WRITE_WAIT: d_addr = column_addr;  // load the col_address to do the write operation
			
			READ_WAIT: d_addr = column_addr;   // load the col_address to do the read operation
		endcase
	end
    
    // Track active rows
	always@ (*) begin
		if(reset) begin
		  open_row <= 0;   // closing all the open_rows of all the banks
			for (int i=0; i<`N_BANK; i = i+1) begin
				active_row[i] <= 0; // intiating all the row buffers of banks to row address 0 
			end
		end
		else begin
			case(controller_state) 
				ACTIVATE_WAIT: begin
					active_row[bank_id] <= row_addr;
					open_row[bank_id] <= 1'b1; // showing the row is open for this certain bank
				end
			    PRECHARGE: begin
					open_row[bank_id] <= 1'b0; // closing the open row of that bank_id 				
				end
				REFRESH: begin
				    open_row <= 0; // closing all the open rows  
				end
			endcase
		end
	end
	
	reg [5:0]write_burst_count = 0;
//	reg [5:0]read_burst_count;

	always@(posedge clk) begin
        if(controller_state == BURST_WAIT && !reset) begin
            if(temp_cmd) begin
                write_burst_count <= write_burst_count+1;
            end
        end
        else begin
                write_burst_count <= 0;
            end
        end

	
//	reg [7:0]temp_rd_data[7:0];
    
    
    always @(dram_dqs or reset or write_burst_count or controller_state) begin
    if(reset) begin
        valid_data <= 0; 
        dram_wr_data <= 0;
//        write_burst_count <= 0;
    end
    else begin
        if(temp_cmd && (controller_state == BURST_WAIT)) begin
            valid_data <= 0;
            if(dram_dqs && write_burst_count<4) begin
            dram_wr_data <= temp_write_data[write_burst_count][7:0]; // we would be writing into the memory in burst mode and in double data
            $display("dram_wr_data - %b, dqs - %d",dram_wr_data, dram_dqs);
            $display("temp_cmd-%d,dq-%b",temp_cmd,dq);
            end
            else if(!dram_dqs && write_burst_count<4) begin
            dram_wr_data <= temp_write_data[write_burst_count][15:8]; 
//            write_burst_count <= write_burst_count+1;
            $display("dram_wr_data - %b, dqs - %d",dram_wr_data, dram_dqs);
            $display("temp_cmd-%d,dq-%b",temp_cmd,dq);
            end
            
        end
        
        else if(read_flag && (controller_state == BURST_WAIT)) begin
//            Read_data <= dq; // reading the data which will be recieved to the controller and we would be transmitting it to the user side
            valid_data <= 1; 
            if(dram_dqs) begin
            Read_data[7:0] <= dq; // we would be writing into the memory in burst mode and in double data rate
            $display("Read_data - %b, dq - %b",Read_data, dq);
            end
            else if(!dram_dqs) begin
            Read_data[15:8] <= dq;  
            $display("Read_data - %b, dq - %b",Read_data, dq);
            end
        end
        
        else 
            valid_data <= 0;
    end 
	end  
	
endmodule
