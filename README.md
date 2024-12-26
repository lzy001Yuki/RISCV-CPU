# RISCV-CPU

This project aims to accomplish CPU design supporting RISCV-32.

Here is the offical introduction: [CPU2024](https://github.com/ACMClassCourse-2023/CPU2024/)

For simulator, click here: [RISCV-Simulator](https://github.com/lzy001Yuki/RISCV-Simulator)

## About Overall Design
<img src="figures/myTomasulo(3).png" width="500" align=center />

## Something deserved to be written down

Thanks for **stargazer**'s help in fpga environment configuration!!! :smile:

（unluckily I almost experienced all possible problems....bad news）

Here are some problems I have met:

- firstly compile /fpga, installing docker may be simpler, but need to **configure 'docker windows proxy' in docker desktop and allow connection from lan in the proxy software** to solve **fail to solve archlinux:lateset** error

- using docker to install serial(~~gpt can help you write dockerfile~~)

- if the ubuntu version is 22.04, when **make run_fpga** ，error message like **<package x.x.x> not found(required by fpga/fpga)** may appear. Solution is to install another 24.04 ubuntu on the PC, and run the project on this ubuntu

- when testing on fpga, results that are correct in sim tests are wrong here, and it appears like garbled text(especially in testpoints whose outputs are very dense like bulgarian/uartboom), the problem is probably caused by **io_buffer_full**. Also remind that **0x30004** relates to io_buffer.

## References:

[五级流水线CPU设计](https://notes.widcard.win/undergraduate/cs/report/)


[RISCV指令集](https://blog.csdn.net/qq_57502075/article/details/132015845)

[RV32C指令](https://blog.csdn.net/qq_38798111/article/details/129745919)

[Vivado教程](https://vlab.ustc.edu.cn/guide/doc_vivado.html)

### Tomasulo Outline
<img src="figures/Tomasulo.jpg" width="500" align=center />
