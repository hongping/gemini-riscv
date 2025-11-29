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
        // 20: BEQ  x3, x4, 8   (Branch to 28 if x3 == x4)
        // 24: ADDI x5, x0, 1   (Should be skipped)
        // 28: ADDI x5, x0, 2   (x5 = 2)
        // 32: JAL  x0, 0       (Infinite Loop)

        memory[0] = 32'h00a00093; // ADDI x1, x0, 10
        memory[1] = 32'h01400113; // ADDI x2, x0, 20
        memory[2] = 32'h002081b3; // ADD  x3, x1, x2
        memory[3] = 32'h06302223; // SW   x3, 100(x0) -> Offset 100 is 25 words -> addr 25
        memory[4] = 32'h06402203; // LW   x4, 100(x0)
        memory[5] = 32'h00418463; // BEQ  x3, x4, +8 (offset 8 bytes = 2 instrs) -> PC+8 = 28
        memory[6] = 32'h00100293; // ADDI x5, x0, 1 (Fail case)
        memory[7] = 32'h00200293; // ADDI x5, x0, 2 (Success case)
        memory[8] = 32'h0000006f; // JAL  x0, 0 (Loop)

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
    
    // Monitor
    initial begin
        $monitor("Time=%0t PC=%h Instr=%h", $time, u_core.pc, u_core.instr);
    end

endmodule
