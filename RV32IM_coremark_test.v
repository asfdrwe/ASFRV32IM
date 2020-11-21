module UART(input wire f, input wire [7:0] data);
  always @(*) begin
    if (f == 1'b1) begin
      $write("%c", data);
    end
  end
endmodule 

module RV32IM_test;
  reg clock = 1'b0;
  reg reset_n = 1'b0;
  wire [31:0] pc_out, op_out, alu_out;
  wire [8:0] uart_out;
  
  UART u1(uart_out[8], uart_out[7:0]);
  RV32IM rv1(clock, reset_n, pc_out, op_out, alu_out, uart_out);

  initial begin
    clock = 1'b0;
    forever begin
      #1 clock = ~clock;
    end
  end

  initial begin
    reset_n = 1'b0;

    #1 reset_n = 1'b1;
    #10000000 $finish;
  end

endmodule
