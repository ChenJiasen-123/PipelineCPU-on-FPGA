lw t0,0(gp)
#根据读到样例编号跳转
lw t1,4(gp)
lw t2,8(gp)
addi t6,t1,1
sw t6,12(gp)
ecall
addi t6,t1,1
sw t6,12(gp)