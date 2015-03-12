These files are here for reference. They are state machines Robin and David build using Fizzim.
The eventual plan is to re-do the state machines in the Master FPGA firmware (without Fizzim) so 
that the code will be easier to understand.

In the meantime, it is sometimes useful to look at the .fzm files, and we want to make sure that 
the latest versions of each state machine are available to everyone in case modifications are 
necessary. Old versions are also here for reference.

triggerManager: 
    - receives triggers from TTC and passes them on the channels
    - waits for done signals from channels

commandManager:
    - sends commands from IPbus on to channels, and also controls the data readout sequence

dataTransferManager:
    - no longer used (was combined with commandManager)
