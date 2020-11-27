module RV32IM(input wire clock, input wire reset_n, output wire [31:0] pc_out, output wire [31:0] op_out, output wire [31:0] alu_out, output wire [8:0] uart_out);
// Copyright (c) 2020 asfdrwe (asfdrwe@gmail.com)
// SPDX-License-Identifier: MIT
  // REGISTER
  reg [31:0] pc;
  assign pc_out = pc; // for DEBUG
  reg [31:0] regs[0:31];

  // MEMORY 64KB 
  reg [7:0] mem[0:16'hffff]; // MEMORY 64KB
  initial $readmemh("test.hex", mem); // MEMORY INITIALIZE 

  // UART OUTPUT and CYCLE COUNTER
  reg [8:0] uart = 9'b0; // uart[8] for output sign, uart[7:0] for data
  assign uart_out = uart;
  localparam [31:0] UART_MMIO_ADDR = 32'h0000_fff0; // ADDRESS 0xfff0 for UART
  reg [31:0] counter = 32'b0;
  localparam [31:0] COUNTER_MMIO_ADDR = 32'h0000_fff4; // ADDRESS 0xfff4 for COUNTER

  // FETCH
  wire [31:0] opcode;
  assign opcode = {mem[pc + 3], mem[pc + 2], mem[pc + 1], mem[pc]}; // little endian
  assign op_out = opcode; // for DEBUG

  // DECODE
  wire [5:0] r_addr1, r_addr2, w_addr;
  wire [31:0] imm;
  wire [4:0] alucon;
  wire [2:0] funct3;
  wire op1sel, op2sel, mem_rw, rf_wen;
  wire [1:0] wb_sel, pc_sel;

  wire [6:0] op;
  assign op = opcode[6:0];

  localparam [6:0] RFORMAT       = 7'b0110011;
  localparam [6:0] IFORMAT_ALU   = 7'b0010011;
  localparam [6:0] IFORMAT_LOAD  = 7'b0000011;
  localparam [6:0] SFORMAT       = 7'b0100011;
  localparam [6:0] SBFORMAT      = 7'b1100011;
  localparam [6:0] UFORMAT_LUI   = 7'b0110111;
  localparam [6:0] UFORMAT_AUIPC = 7'b0010111;
  localparam [6:0] UJFORMAT      = 7'b1101111;
  localparam [6:0] IFORMAT_JALR  = 7'b1100111;
  localparam [6:0] ECALLEBREAK   = 7'b1110011;
  localparam [6:0] FENCE         = 7'b0001111;
  localparam [6:0] MULDIV        = 7'b0110011;

  assign r_addr1 = (op == UFORMAT_LUI) ? 5'b0 : opcode[19:15];
  assign r_addr2 = opcode[24:20];
  assign w_addr =  opcode[11:7];

  assign imm[31:20] = ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC)) ? opcode[31:20] : 
		      (opcode[31] == 1'b1) ? 12'hfff : 12'b0;
  assign imm[19:12] = ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC) || (op == UJFORMAT)) ? opcode[19:12] :
                      (opcode[31] == 1'b1) ? 8'hff : 8'b0;
  assign imm[11] = (op == SBFORMAT) ? opcode[7] :
                   ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC)) ? 1'b0 :
                   (op == UJFORMAT) ? opcode[20] : opcode[31];
  assign imm[10:5] = ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC)) ? 6'b0 : opcode[30:25];
  assign imm[4:1] = ((op == IFORMAT_ALU) || (op == IFORMAT_LOAD) || (op == IFORMAT_JALR) || (op == UJFORMAT)) ? opcode[24:21] :
		    ((op == SFORMAT) || (op == SBFORMAT)) ? opcode[11:8] : 4'b0;
  assign imm[0] = ((op == IFORMAT_ALU) || (op == IFORMAT_LOAD) || (op == IFORMAT_JALR)) ? opcode[20] :
		  (op == SFORMAT) ? opcode[7] : 1'b0;

  assign alucon = ((op == RFORMAT) || (op == MULDIV)) ? {opcode[30], opcode[25], opcode[14:12]} :
                  ((op == IFORMAT_ALU) && (opcode[14:12] == 3'b101)) ? {opcode[30], opcode[25], opcode[14:12]} : // SRLI or SRAI
                  (op == IFORMAT_ALU) ? {2'b00, opcode[14:12]} : 5'b0;
  assign funct3 = opcode[14:12];
  assign op1sel = ((op == SBFORMAT) || (op == UFORMAT_AUIPC) || (op == UJFORMAT)) ? 1'b1 : 1'b0;
  assign op2sel = ((op == RFORMAT) || (op == MULDIV)) ? 1'b0 : 1'b1;
  assign mem_rw = (op == SFORMAT) ? 1'b1 : 1'b0;
  assign wb_sel = (op == IFORMAT_LOAD) ? 2'b01 :
                  ((op == UJFORMAT) || (op == IFORMAT_JALR)) ? 2'b10 : 2'b00;
  assign rf_wen = (((op == RFORMAT) && ({opcode[31],opcode[29:25]} == 6'b000000)) ||
                   ((op == MULDIV) && ({opcode[31:25]} == 7'b000001)) ||
                   ((op == IFORMAT_ALU) && (({opcode[31:25], opcode[14:12]} == 10'b00000_00_001) || ({opcode[31], opcode[29:25], opcode[14:12]} == 9'b0_000_00_101) ||  // SLLI or SRLI or SRAI
                                            (opcode[14:12] == 3'b000) || (opcode[14:12] == 3'b010) || (opcode[14:12] == 3'b011) || (opcode[14:12] == 3'b100) || (opcode[14:12] == 3'b110) || (opcode[14:12] == 3'b111))) ||
                   (op == IFORMAT_LOAD) || (op == UFORMAT_LUI) || (op == UFORMAT_AUIPC) || (op == UJFORMAT) || (op == IFORMAT_JALR)) ? 1'b1 : 1'b0;
  assign pc_sel = (op == SBFORMAT) ? 2'b01 :
                  ((op == UJFORMAT) || (op == IFORMAT_JALR) || (op == ECALLEBREAK)) ? 2'b10 : 2'b00;

  // EXECUTION

  // REGISTER READ                  
  wire [31:0] r_data1, r_data2;
  assign r_data1 = (r_addr1 == 5'b00000) ? 32'b0 : regs[r_addr1]; 
  assign r_data2 = (r_addr2 == 5'b00000) ? 32'b0 : regs[r_addr2]; 

  // SELECTOR  
  wire [31:0] s_data1, s_data2;
  assign s_data1 = (op1sel == 1'b1) ? pc : r_data1;
  assign s_data2 = (op2sel == 1'b1) ? imm : r_data2;

  // ALU
  wire [31:0] alu_data;
  reg [63:0] tmpalu;

  function [31:0] ALU_EXEC( input [4:0] control, input [31:0] data1, input [31:0] data2);
    case(control)
    5'b00000: // ADD ADDI (ADD)
      ALU_EXEC = data1 + data2;
    5'b10000: // SUB (SUB)
      ALU_EXEC = data1 - data2;
    5'b00001: // SLL SLLI (SHIFT LEFT (LOGICAL))
      ALU_EXEC = data1 << data2[4:0];
    5'b00010: // SLT SLTI (SET_ON_LESS_THAN (SIGNED))
      ALU_EXEC = ($signed(data1) < $signed(data2)) ? 32'b1 :32'b0;
    5'b00011: // SLTU SLTUI (SET_ON_LESS_THAN (UNSIGNED))
      ALU_EXEC = (data1 < data2) ? 32'b1 :32'b0;
    5'b00100: // XOR XORI (XOR)
      ALU_EXEC = data1 ^ data2;
    5'b00101: // SRL SRLI (SHIFT RIGHT (LOGICAL))
      ALU_EXEC = data1 >> data2[4:0];
    5'b10101: // SRA SRAI (SHIFT RIGHT (ARITHMETIC))
      ALU_EXEC = $signed(data1[31:0]) >>> data2[4:0];
    5'b00110: // OR ORI (OR)
      ALU_EXEC = data1 | data2;
    5'b00111: // AND ANDI (AND)
      ALU_EXEC = data1 & data2;
    5'b01000: // MUL (MULTIPLE)
      ALU_EXEC = data1 * data2;
    5'b01001: begin // MULH (MULTIPLE)
      tmpalu = $signed(data1) * $signed(data2);
      ALU_EXEC = $signed(tmpalu) >>> 32;
    end
    5'b01010: begin // MULHSU (MULTIPLE)
      tmpalu = $signed(data1) * $signed({1'b0, data2});
      ALU_EXEC = tmpalu >> 32;
    end
    5'b01011: begin // MULHU (MULTIPLE)
      tmpalu = data1 * data2;
      ALU_EXEC = tmpalu >> 32;
    end
    5'b01100: // DIV (DIVIDE)
      ALU_EXEC = (data2 == 32'b0) ? 32'hffff_ffff : 
                 ((data1 == 32'h8000_0000) && (data2 == 32'hffff_ffff)) ? 32'h8000_0000 : $signed($signed(data1) / $signed(data2));
    5'b01101: // DIVU (DIVIDE)
      ALU_EXEC = (data2 == 32'b0) ? 32'hffff_ffff : (data1 / data2);
    5'b01110: // REM (DIVIDE REMINDER)
      ALU_EXEC = (data2 == 32'b0) ? data1 : 
                 ((data1 == 32'h8000_0000) && (data2 == 32'hffff_ffff)) ? 32'h0 : $signed($signed(data1) % $signed(data2));
    5'b01111: // REMU (DIVIDE REMINDER)
      ALU_EXEC = (data2 == 32'b0) ? data1 : (data1 % data2);
    default: // ILLEGAL
      ALU_EXEC = 32'b0;
    endcase
  endfunction

  assign alu_data = ALU_EXEC(alucon, s_data1, s_data2);
  assign alu_out = alu_data; // for DEBUG

  // BRANCH
  wire pc_sel2;

  function BRANCH_EXEC( input [2:0] branch_op, input [31:0] data1, input [31:0] data2, input [1:0] pc_sel);
    case(pc_sel)
    2'b00: // PC + 4
      BRANCH_EXEC = 1'b0;
    2'b01: begin // BRANCH
      case(branch_op)
      3'b000: // BEQ
        BRANCH_EXEC = (data1 == data2) ? 1'b1 : 1'b0;
      3'b001: // BNE
        BRANCH_EXEC = (data1 != data2) ? 1'b1 : 1'b0;
      3'b100: // BLT
        BRANCH_EXEC = ($signed(data1) < $signed(data2)) ? 1'b1 : 1'b0;
      3'b101: // BGE
        BRANCH_EXEC = ($signed(data1) >= $signed(data2)) ? 1'b1 : 1'b0;
      3'b110: // BLTU
        BRANCH_EXEC = (data1 < data2) ? 1'b1 : 1'b0;
      3'b111: // BGEU
        BRANCH_EXEC = (data1 >= data2) ? 1'b1 : 1'b0;
      default: // ILLEGAL
        BRANCH_EXEC = 1'b0;
      endcase
    end 
    2'b10: // JAL JALR
      BRANCH_EXEC = 1'b1;
    default: // ILLEGAL
      BRANCH_EXEC = 1'b0;
    endcase
  endfunction

  assign pc_sel2 = BRANCH_EXEC(funct3, r_data1, r_data2, pc_sel);

  // MEMORY 
  wire [2:0] mem_val;
  wire [31:0] mem_data;
  wire [31:0] mem_addr;
  assign mem_val = funct3;
  assign mem_addr = alu_data;
  
  // MEMORY READ
  assign mem_data = (mem_rw == 1'b1) ? 32'b0 : // when MEMORY WRITE, the output from MEMORY is 32'b0
		    ((mem_val == 3'b010) && (mem_addr == COUNTER_MMIO_ADDR)) ? counter : // MEMORY MAPPED IO for CLOCK CYCLE COUNTER
                     (mem_val == 3'b000) ?  (mem[mem_addr][7] == 1'b1 ? {24'hffffff, mem[mem_addr]} : {24'h000000, mem[mem_addr]}) : // LB
                     (mem_val == 3'b001) ?  (mem[mem_addr + 1][7] == 1'b1 ? {16'hffff, mem[mem_addr + 1], mem[mem_addr]} : {16'h0000, mem[mem_addr + 1], mem[mem_addr]}) : // LH
                     (mem_val == 3'b010) ? {mem[mem_addr + 3], mem[mem_addr + 2], mem[mem_addr + 1], mem[mem_addr]} : // LW
                     (mem_val == 3'b100) ? {24'h000000, mem[mem_addr]} : // LBU
                     (mem_val == 3'b101) ? {16'h0000, mem[mem_addr + 1], mem[mem_addr]} : // LHU
                                           32'b0;
  // MEMORY WRITE
  always @(posedge clock) begin
    if (mem_rw == 1'b1) begin
      case (mem_val)
        3'b000: // SB
          mem[mem_addr] <= #1 r_data2[7:0];
        3'b001: // SH
          {mem[mem_addr + 1], mem[mem_addr]} <= #1 r_data2[15:0];
        3'b010: // SW
          {mem[mem_addr + 3], mem[mem_addr + 2], mem[mem_addr + 1], mem[mem_addr]} <= #1 r_data2;
        default: begin end // ILLEGAL
      endcase
    end
    // MEMORY MAPPED IO to UART
    if ((mem_rw == 1'b1) && (mem_addr == UART_MMIO_ADDR)) begin
      uart <= #1 {1'b1, r_data2[7:0]};
    end else begin
      uart <= #1 9'b0;
    end
  end

  // REGISTER WRITE BACK
  wire [31:0] w_data;
  assign w_data = (wb_sel == 2'b00) ? alu_data : 
                  (wb_sel == 2'b01) ? mem_data :
                  (wb_sel == 2'b10) ? pc + 4 : 32'b0; // ILLEGAL
  always @(posedge clock) begin
    if ((rf_wen == 1'b1) && (w_addr != 5'b00000))
      regs[w_addr] <= #1 w_data;
  end

  // NEXT PC
  wire [31:0] next_pc;
  assign next_pc = (pc_sel2 == 1'b1) ? {alu_data[31:1], 1'b0} : pc + 4;

  // NEXT PC WRITE BACK and CYCLE COUNTER
  always @(posedge clock or negedge reset_n) begin
   if (!reset_n) begin
      pc <= 32'b0;
      counter <= 32'b0;
    end else begin
      pc <= #1 next_pc; 
      counter <= counter + 1;
    end
  end
endmodule
