.text
#��ת���ж�������ʼ����Ϊ��ͳһ��t1,t2������������������t6��������
li s0,1
li s1,2
li s2,3
li s3,4
li s4,5
li s5,6
li s6,7
li s7,8
li s8,9
li s9,10
li gp,0x4000

#����ѭ����ȡ��������
main:
    lw t0,0(gp)
#���ݶ������������ת
    lw t1,4(gp)
    lw t2,8(gp)
    beq t0,zero,case0
    beq t0,s0,case1
    beq t0,s1,case2
    beq t0,s2,case3
    beq t0,s3,case4
    beq t0,s4,case5
    beq t0,s5,case6
    beq t0,s6,case7
    beq t0,s7,case8
    beq t0,s8,case9
    beq t0,s9,case10
continue:
    sw t6,12(gp)
    j main

#��ͬ��ŵĲ��Ծ���ʵ��

#and���㣬ʵ�ְ�λ������
case0:
    and t6,t1,t2
    j continue
 
#sll���㣬ʵ���������㣬�ڶ����������ĵ�5bit���ƶ���λ����
case1:
    sll t6,t1,t2
    j continue 
 
#sra���㣬ʵ�������������㣬�ڶ����������ĵ�5bit���ƶ���λ��
case2:
    sra t6,t1,t2
    j continue
#lui+add��ʵ�ּ��ظ�20λ��������ӷ�����
case3:
    lui t3,0x12345
    add t6,t1,t3 
    j continue
# jal+auipc,ʵ��auipcϵ�в���
case4:
    jal a0,target
  target:
    auipc a1,0x12345
    sub t6,a1,a0
    add t6,t6,t1
    j continue
     
 #jal+jalr,ʵ�ֺ������úͷ��ز�������ִ�е��ú����һ���ӷ�����
case5:
    jal func
    add t6,t1,t2
    j continue
  func: 
    jr ra

case6:
    addi a0,t1,0
    jal fib
    addi t6,a0,0
    j continue
 #斐波那契实现
  fib:
    li t3,1
    li t4,2
    beq a0, t3, fi 
    beq a0, t4, se
    
    addi sp, sp, -12     
    sw ra, 8(sp)          
    sw a0, 4(sp)
            
    addi a0, a0, -1
    jal fib
    sw a0, 0(sp) 
             
    lw a0, 4(sp)         
    addi a0, a0, -2
    jal fib  
                
    lw t1, 0(sp)        
    add a0, t1, a0 
          
    lw ra, 8(sp)         
    addi sp, sp, 12      
    jr ra

  fi:              
    li a0, 1
    jr ra

  se:           
    li a0, 1
    jr ra
     
#���8bit��1�ĸ���  
case7:
    li t6,0
    li t3,8
    li t4,0
  loop:
    andi t4,t1,1
    add t6,t6,t4
    srli t1,t1,1
    addi t3,t3,-1
    bnez t3,loop
    j continue

 #16bitIEEE754���븡�����������ж�  
case8:
     #16bit
     #��ȡexponent
    srli t3,t1,10
    andi t3,t3,0x1f
     #��ȡfraction
    andi t4,t1,0x03ff
     #exp=0
    beqz t3,exp_zero
     #exp=31
    li t5,31
    beq t3,t5,full
     
     #normal
    li t6,3
    j case8_end
     
  exp_zero:
    #exp fraction=0,0
    beqz t4,zero1
    #exp=0 fraction!=0
    li t6,4
    j case8_end
 
  full:
     #����
    beqz t4,inf
     #Nan
    li t6,2
    j case8_end
      
  zero1:
    li t6,0
    j case8_end

  inf:
    li t6,1

  case8_end:     
    j continue
     
     
case9:
    srli t2, t1, 10      # 右移10位，去掉尾数
    andi t2, t2, 0x1F    # 取低5位，t2 = 指数
    andi t3, t1, 0x3FF   # 取低10位，t3 = 尾数
    addi t3, t3, 0x400   # 补上规格化数的隐藏整数部分1
    srli t5, t1, 15      # 提取符号位到 t5

    # 4. 计算位移量 (21 - E) 并获取定点数绝对值
    # 根据推导，Q3.4 的位模式等于 (1024+M) >> (21 - E)
    li   t4, 21
    sub  t4, t4, t2          # t4 = 21 - 指数
    srl  t3, t3, t4          # t3 = (1024+M) >> t4

    beqz t5, skip_neg    # 如果符号位为0，浮点数为正，跳过补码处理
    neg  t3, t3          # 如果符号位为1，取补码
    
  skip_neg:
    andi t6, t3, 0xFF
    j continue

case10:
  # 1) Assembly popcount of t1 (preserve t1), time it -> result in a2, time in a1
    addi a0, t1, 0        # copy t1 to a0 to preserve original t1
    rdcycle a1            # start cycle count into a1
    li a2, 0              # popcount result
    li a3, 32             # loop counter
  pop_loop_case10:
    andi a4, a0, 1
    add a2, a2, a4
    srli a0, a0, 1
    addi a3, a3, -1
    bnez a3, pop_loop_case10
    rdcycle a5
    addi t2, a2, 0       # move popcount result into t2
    sub a1, a5, a1       # a1 = elapsed cycles for assembly popcount
    addi t4, a1, 0       # move popcount time into t4

    # 2) Time your custom instruction (the line below may be replaced by your custom instr)
    rdcycle a6            # start cycle count for custom instr into a6
    addi t6, t6, 0x123   # 0x20035e13  0010000_00000_00110_101_11100(t3)_0010011
    rdcycle a5
    sub a6, a5, a6       # a6 = elapsed cycles for custom instruction
    addi t5, a6, 0       # move custom-instr time into t5 (final)

    # 3) Compare timings: if assembly time > custom time then set t6=1 else t6=0
    blt t5, t4, case10_set1
    li t6, 0
    j continue

  case10_set1:
    li t6, 1
    # addi t6, t6, 0x123
    # addi t6, t3, 0
    j continue
