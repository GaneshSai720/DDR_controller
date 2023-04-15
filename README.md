# DDR_controller
![alt text](https://www.google.com/imgres?imgurl=https%3A%2F%2Fimages.pexels.com%2Fphotos%2F674010%2Fpexels-photo-674010.jpeg%3Fauto%3Dcompress%26cs%3Dtinysrgb%26dpr%3D1%26w%3D500&tbnid=fY9reP86COngJM&vet=12ahUKEwjIg4r466z-AhWT4nMBHZAfCjQQMygCegUIARDkAQ..i&imgrefurl=https%3A%2F%2Fwww.pexels.com%2Fsearch%2Fbeautiful%2F&docid=B51x0PBR9KNzvM&w=500&h=667&itg=1&q=images&ved=2ahUKEwjIg4r466z-AhWT4nMBHZAfCjQQMygCegUIARDkAQ)


We have designed a simple DDR controller which would be giving the control signals. And there would be also sending, and recieving data from the memory at double data rate.

Given the controller module with some arbitary delay values for how much time should each stage take, we can reconfingure the delay in terms of cycles of each stage(stage of the controller) in the code. 

Attached Timing report, Area report, Power report generated with the Genus, .vcd files(both pre synthesis and post synsthesis) generated after simulating in NCSim, in the Reports_DDR_controller folder 

We will be sending series of signals from the controller based on the command we receive and state of the controller(FSM), to the DRAM. 

Basics of SDRAM and schematic of simple DDR controller, FSM of the controller are present in the IC Design Lab.pdf attached.There would be some dummy stages which were not represented in the FSM diagram, to give the latencies and send the signals based on the state of the controller in order.  
