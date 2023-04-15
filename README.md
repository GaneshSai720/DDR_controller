# DDR_controller
https://github.com/GaneshSai720/DDR_controller/blob/main/image.png
We have designed a simple DDR controller which would be giving the control signals. And there would be also sending, and recieving data from the memory at double data rate.

Given the controller module with some arbitary delay values for how much time should each stage take, we can reconfingure the delay in terms of cycles of each stage(stage of the controller) in the code. 

We have attached Timing report, Area report, Power report generated with the Genus, .vcd files(both pre synthesis and post synsthesis) generated after simulating in NCSim, in the Reports_DDR_controller folder 

We will be sending series of signals from the controller based on the command we receive and state of the controller(FSM), to the DRAM. 

Basics of SDRAM and schematic of simple DDR controller, FSM of the controller are present in the IC Design Lab.pdf attached.There would be some dummy stages which were not represented in the FSM diagram, to give the latencies and send the signals based on the state of the controller in order.  
