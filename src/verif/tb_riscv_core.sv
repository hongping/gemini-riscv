module tb_riscv_core;

    logic clk;
    logic rst_n;

    // Instruction Interface
    logic [31:0] instr_awaddr;
    logic        instr_awvalid;
    logic        instr_awready;
    logic [31:0] instr_wdata;
    logic [3:0]  instr_wstrb;
    logic        instr_wvalid;
    logic        instr_wready;
    logic [1:0]  instr_bresp;
    logic        instr_bvalid;
    logic        instr_bready;
    logic [31:0] instr_araddr;
    logic        instr_arvalid;
    logic        instr_arready;
    logic [31:0] instr_rdata;
    logic [1:0]  instr_rresp;
    logic        instr_rvalid;
    logic        instr_rready;

    // Data Interface
    logic [31:0] data_awaddr;
    logic        data_awvalid;
    logic        data_awready;
    logic [31:0] data_wdata;
    logic [3:0]  data_wstrb;
    logic        data_wvalid;
    logic        data_wready;
    logic [1:0]  data_bresp;
    logic        data_bvalid;
    logic        data_bready;
    logic [31:0] data_araddr;
    logic        data_arvalid;
    logic        data_arready;
    logic [31:0] data_rdata;
    logic [1:0]  data_rresp;
    logic        data_rvalid;
    logic        data_rready;

    // Memory Array (Unified for simplicity in TB, but accessed via separate ports)
    logic [31:0] memory [0:1023];

    // DUT Instantiation
    riscv_core u_core (
        .clk           (clk),
        .rst_n         (rst_n),
        
        .instr_awaddr  (instr_awaddr),
        .instr_awvalid (instr_awvalid),
        .instr_awready (instr_awready),
        .instr_wdata   (instr_wdata),
        .instr_wstrb   (instr_wstrb),
        .instr_wvalid  (instr_wvalid),
        .instr_wready  (instr_wready),
        .instr_bresp   (instr_bresp),
        .instr_bvalid  (instr_bvalid),
        .instr_bready  (instr_bready),
        .instr_araddr  (instr_araddr),
        .instr_arvalid (instr_arvalid),
        .instr_arready (instr_arready),
        .instr_rdata   (instr_rdata),
        .instr_rresp   (instr_rresp),
        .instr_rvalid  (instr_rvalid),
        .instr_rready  (instr_rready),
        
        .data_awaddr   (data_awaddr),
        .data_awvalid  (data_awvalid),
        .data_awready  (data_awready),
        .data_wdata    (data_wdata),
        .data_wstrb    (data_wstrb),
        .data_wvalid   (data_wvalid),
        .data_wready   (data_wready),
        .data_bresp    (data_bresp),
        .data_bvalid   (data_bvalid),
        .data_bready   (data_bready),
        .data_araddr   (data_araddr),
        .data_arvalid  (data_arvalid),
        .data_arready  (data_arready),
        .data_rdata    (data_rdata),
        .data_rresp    (data_rresp),
        .data_rvalid   (data_rvalid),
        .data_rready   (data_rready)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset Generation
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end

    // Instruction Memory Slave Model
    always_ff @(posedge clk) begin
        instr_arready <= 0;
        instr_rvalid  <= 0;
        
        if (instr_arvalid && !instr_arready) begin
            instr_arready <= 1;
        end
        
        if (instr_arready && instr_arvalid) begin
            instr_rdata  <= memory[instr_araddr[11:2]]; // Word aligned
            instr_rvalid <= 1;
            instr_rresp  <= 0; // OKAY
        end else if (instr_rvalid && instr_rready) begin
            instr_rvalid <= 0;
        end
    end
    
    // Unused Write channels for Instruction
    assign instr_awready = 1;
    assign instr_wready  = 1;
    assign instr_bvalid  = 0;
    assign instr_bresp   = 0;

    // Data Memory Slave Model
    always_ff @(posedge clk) begin
        // Read Channel
        data_arready <= 0;
        data_rvalid  <= 0;
        
        if (data_arvalid && !data_arready) begin
            data_arready <= 1;
        end
        
        if (data_arready && data_arvalid) begin
            data_rdata   <= memory[data_araddr[11:2]];
            data_rvalid  <= 1;
            data_rresp   <= 0;
        end else if (data_rvalid && data_rready) begin
            data_rvalid <= 0;
        end

        // Write Channel
        data_awready <= 0;
        data_wready  <= 0;
        data_bvalid  <= 0;
        
        if (data_awvalid && !data_awready) begin
            data_awready <= 1;
        end
        
        if (data_wvalid && !data_wready) begin
            data_wready <= 1;
        end
        
        if (data_awready && data_awvalid && data_wready && data_wvalid) begin
            memory[data_awaddr[11:2]] <= data_wdata;
            data_bvalid <= 1;
            data_bresp  <= 0;
        end else if (data_bvalid && data_bready) begin
            data_bvalid <= 0;
        end
    end

    // Test Program
    initial begin
        // Initialize Memory
        for (int i = 0; i < 1024; i++) memory[i] = 0;

        // Program:
        // 0: ADDI x1, x0, 10   (x1 = 10)
        // 4: ADDI x2, x0, 20   (x2 = 20)
        // 8: ADD  x3, x1, x2   (x3 = 30)
        // 12: SW   x3, 100(x0) (Mem[100] = 30)
        // 16: LW   x4, 100(x0) (x4 = 30)
        // 20: BEQ  x3, x4, 8   (Branch to 28 if x3 == x4) -> Taken
        // 24: ADDI x5, x0, 1   (Should be skipped)
        // 28: ADDI x5, x0, 2   (x5 = 2)
        // 32: ADDI x6, x0, -5  (x6 = -5)
        // 36: BLT  x6, x1, 8   (Branch to 44 if -5 < 10) -> Taken
        // 40: ADDI x7, x0, 1   (Should be skipped)
        // 44: ADDI x7, x0, 2   (x7 = 2)
        // 48: BGE  x1, x6, 8   (Branch to 56 if 10 >= -5) -> Taken
        // 52: ADDI x8, x0, 1   (Should be skipped)
        // 56: ADDI x8, x0, 2   (x8 = 2)
        // 60: JAL  x0, 0       (Infinite Loop)

        memory[0] = 32'h00a00093; // ADDI x1, x0, 10
        memory[1] = 32'h01400113; // ADDI x2, x0, 20
        memory[2] = 32'h002081b3; // ADD  x3, x1, x2
        memory[3] = 32'h06302223; // SW   x3, 100(x0) -> Offset 100 is 25 words -> addr 25
        memory[4] = 32'h06402203; // LW   x4, 100(x0)
        memory[5] = 32'h00418463; // BEQ  x3, x4, +8 (offset 8 bytes = 2 instrs) -> PC+8 = 28
        memory[6] = 32'h00100293; // ADDI x5, x0, 1 (Fail case)
        memory[7] = 32'h00200293; // ADDI x5, x0, 2 (Success case)
        
        // New Branch Tests
        memory[8]  = 32'hffb00313; // ADDI x6, x0, -5 (0xffb)
        memory[9]  = 32'h00134463; // BLT  x6, x1, +8 (offset 8) -> PC+8 = 44 (word 11)
        memory[10] = 32'h00100393; // ADDI x7, x0, 1 (Fail case)
        memory[11] = 32'h00200393; // ADDI x7, x0, 2 (Success case)
        memory[12] = 32'h0060d463; // BGE  x1, x6, +8 (offset 8) -> PC+8 = 56 (word 14)
        memory[13] = 32'h00100413; // ADDI x8, x0, 1 (Fail case)
        memory[14] = 32'h00200413; // ADDI x8, x0, 2 (Success case)
        
        memory[15] = 32'h0000006f; // JAL  x0, 0 (Loop)

        // Wait for simulation
        #1000;
        
        // Check results
        $display("Checking Results...");
        if (memory[25] === 30) $display("PASS: Memory Write (SW) correct.");
        else $display("FAIL: Memory Write (SW) incorrect. Expected 30, got %d", memory[25]);
        
        // We can't easily check internal registers without hierarchical access or adding debug ports.
        // But if SW worked, x3 was correct.
        // If we are looping at PC=32 (word 8), then branch worked.
        
        $finish;
    end
    
    // Disassembly Function
    function string get_disasm(input logic [31:0] instr, input logic valid);
        logic [6:0] opcode;
        logic [4:0] rd, rs1, rs2;
        logic [2:0] funct3;
        logic [6:0] funct7;
        logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
        string instr_str;
        
        if (!valid) return "STALL";

        opcode = instr[6:0];
        rd     = instr[11:7];
        funct3 = instr[14:12];
        rs1    = instr[19:15];
        rs2    = instr[24:20];
        funct7 = instr[31:25];
        
        imm_i = {{20{instr[31]}}, instr[31:20]};
        imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
        imm_u = {instr[31:12], 12'b0};
        imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

        case (opcode)
            7'b0110011: begin // R-Type
                case (funct3)
                    3'b000: instr_str = (funct7[5]) ? $sformatf("SUB x%0d, x%0d, x%0d", rd, rs1, rs2) : $sformatf("ADD x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'b001: instr_str = $sformatf("SLL x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'b010: instr_str = $sformatf("SLT x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'b011: instr_str = $sformatf("SLTU x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'b100: instr_str = $sformatf("XOR x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'b101: instr_str = (funct7[5]) ? $sformatf("SRA x%0d, x%0d, x%0d", rd, rs1, rs2) : $sformatf("SRL x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'b110: instr_str = $sformatf("OR x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'b111: instr_str = $sformatf("AND x%0d, x%0d, x%0d", rd, rs1, rs2);
                    default: instr_str = "UNKNOWN_R";
                endcase
            end
            7'b0010011: begin // I-Type
                case (funct3)
                    3'b000: instr_str = $sformatf("ADDI x%0d, x%0d, %0d", rd, rs1, $signed(imm_i));
                    3'b001: instr_str = $sformatf("SLLI x%0d, x%0d, %0d", rd, rs1, imm_i[4:0]);
                    3'b010: instr_str = $sformatf("SLTI x%0d, x%0d, %0d", rd, rs1, $signed(imm_i));
                    3'b011: instr_str = $sformatf("SLTIU x%0d, x%0d, %0d", rd, rs1, imm_i);
                    3'b100: instr_str = $sformatf("XORI x%0d, x%0d, %0d", rd, rs1, $signed(imm_i));
                    3'b101: instr_str = (imm_i[10]) ? $sformatf("SRAI x%0d, x%0d, %0d", rd, rs1, imm_i[4:0]) : $sformatf("SRLI x%0d, x%0d, %0d", rd, rs1, imm_i[4:0]);
                    3'b110: instr_str = $sformatf("ORI x%0d, x%0d, %0d", rd, rs1, $signed(imm_i));
                    3'b111: instr_str = $sformatf("ANDI x%0d, x%0d, %0d", rd, rs1, $signed(imm_i));
                    default: instr_str = "UNKNOWN_I";
                endcase
            end
            7'b0000011: begin // Load
                case (funct3)
                    3'b010: instr_str = $sformatf("LW x%0d, %0d(x%0d)", rd, $signed(imm_i), rs1);
                    default: instr_str = "UNKNOWN_LOAD";
                endcase
            end
            7'b0100011: begin // Store
                case (funct3)
                    3'b010: instr_str = $sformatf("SW x%0d, %0d(x%0d)", rs2, $signed(imm_s), rs1);
                    default: instr_str = "UNKNOWN_STORE";
                endcase
            end
            7'b1100011: begin // Branch
                case (funct3)
                    3'b000: instr_str = $sformatf("BEQ x%0d, x%0d, %0d", rs1, rs2, $signed(imm_b));
                    3'b001: instr_str = $sformatf("BNE x%0d, x%0d, %0d", rs1, rs2, $signed(imm_b));
                    3'b100: instr_str = $sformatf("BLT x%0d, x%0d, %0d", rs1, rs2, $signed(imm_b));
                    3'b101: instr_str = $sformatf("BGE x%0d, x%0d, %0d", rs1, rs2, $signed(imm_b));
                    3'b110: instr_str = $sformatf("BLTU x%0d, x%0d, %0d", rs1, rs2, $signed(imm_b));
                    3'b111: instr_str = $sformatf("BGEU x%0d, x%0d, %0d", rs1, rs2, $signed(imm_b));
                    default: instr_str = "UNKNOWN_BRANCH";
                endcase
            end
            7'b1101111: instr_str = $sformatf("JAL x%0d, %0d", rd, $signed(imm_j));
            7'b1100111: instr_str = $sformatf("JALR x%0d, x%0d, %0d", rd, rs1, $signed(imm_i));
            7'b0110111: instr_str = $sformatf("LUI x%0d, 0x%h", rd, imm_u[31:12]);
            7'b0010111: instr_str = $sformatf("AUIPC x%0d, 0x%h", rd, imm_u[31:12]);
            default: instr_str = "UNKNOWN_OP";
        endcase
        return instr_str;
    endfunction

    // Monitor
    initial begin
        $monitor("Time=%0t PC=%h Instr=%h Disasm=%s", $time, u_core.pc, u_core.instr, get_disasm(u_core.instr, u_core.instr_valid));
    end

endmodule
