module riscv_core (
    input  logic        clk,
    input  logic        rst_n,

    // Instruction Memory Interface (AXI4-Lite Master)
    output logic [31:0] instr_awaddr,
    output logic        instr_awvalid,
    input  logic        instr_awready,
    output logic [31:0] instr_wdata,
    output logic [3:0]  instr_wstrb,
    output logic        instr_wvalid,
    input  logic        instr_wready,
    input  logic [1:0]  instr_bresp,
    input  logic        instr_bvalid,
    output logic        instr_bready,
    output logic [31:0] instr_araddr,
    output logic        instr_arvalid,
    input  logic        instr_arready,
    input  logic [31:0] instr_rdata,
    input  logic [1:0]  instr_rresp,
    input  logic        instr_rvalid,
    output logic        instr_rready,

    // Data Memory Interface (AXI4-Lite Master)
    output logic [31:0] data_awaddr,
    output logic        data_awvalid,
    input  logic        data_awready,
    output logic [31:0] data_wdata,
    output logic [3:0]  data_wstrb,
    output logic        data_wvalid,
    input  logic        data_wready,
    input  logic [1:0]  data_bresp,
    input  logic        data_bvalid,
    output logic        data_bready,
    output logic [31:0] data_araddr,
    output logic        data_arvalid,
    input  logic        data_arready,
    input  logic [31:0] data_rdata,
    input  logic [1:0]  data_rresp,
    input  logic        data_rvalid,
    output logic        data_rready
);

    // Internal Signals
    logic [31:0] instr;
    logic [31:0] pc;
    logic        instr_valid;
    logic        instr_ready;
    
    logic        reg_write;
    logic        mem_write;
    logic        mem_read;
    logic        alu_src;
    logic        mem_to_reg;
    logic [3:0]  alu_op;
    logic        branch;
    logic        jump;
    logic        jalr;
    logic        lui;
    logic        auipc;
    
    logic        zero;
    logic [31:0] branch_target;
    logic        branch_taken;
    
    logic [31:0] alu_result;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic        mem_req_valid;
    logic        mem_req_ready;
    logic        mem_resp_valid;

    // Instruction Decoder Signals (for Control Unit)
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    
    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    // Branch Logic
    assign branch_taken = (branch && zero) || jump || jalr; // Simplified branch condition (only BEQ for now? No, need to check ALU result)
    // Note: ALU zero flag is only for BEQ. For other branches, we need more flags or ALU op adjustment.
    // For this simple core, let's assume ALU does the comparison and sets Zero if condition met.
    // Control unit sets ALU op to SUB for BEQ/BNE.
    // Wait, standard RISC-V branches are: BEQ, BNE, BLT, BGE, BLTU, BGEU.
    // ALU needs to output specific flags or result needs to be checked.
    // For simplicity in this step, let's fix the branch logic in Datapath/Control or here.
    // Let's refine branch_taken:
    // Ideally, ALU should output 'comparison_result' bit.
    // For now, let's assume ALU zero means "Equal".
    // Real implementation needs full branch logic.
    // Let's update this logic to be correct for at least BEQ.
    // For BNE, we need !zero.
    // For BLT, we need result < 0 (signed).
    // This requires more complex logic.
    // Let's stick to simple BEQ for the "Simple Core" first pass, or add a comparator.
    
    // Correcting Branch Logic:
    logic branch_condition_met;
    always_comb begin
        case (funct3)
            3'b000: branch_condition_met = zero;          // BEQ
            3'b001: branch_condition_met = !zero;         // BNE
            3'b100: branch_condition_met = !zero;         // BLT (ALU_SLT: result=1 if a<b, so !zero)
            3'b101: branch_condition_met = zero;          // BGE (ALU_SLT: result=0 if a>=b, so zero)
            3'b110: branch_condition_met = !zero;         // BLTU (ALU_SLTU: result=1 if a<b)
            3'b111: branch_condition_met = zero;          // BGEU (ALU_SLTU: result=0 if a>=b)
            default: branch_condition_met = 0;
        endcase
    end
    
    assign branch_taken = instr_valid && ((branch && branch_condition_met) || jump || jalr);

    // Fetch Unit
    fetch_unit u_fetch_unit (
        .clk           (clk),
        .rst_n         (rst_n),
        .branch_taken  (branch_taken),
        .branch_target (branch_target),
        .pc            (pc),
        .instr         (instr),
        .instr_valid   (instr_valid),
        .instr_ready   (instr_ready),
        .axi_araddr    (instr_araddr),
        .axi_arvalid   (instr_arvalid),
        .axi_arready   (instr_arready),
        .axi_rdata     (instr_rdata),
        .axi_rresp     (instr_rresp),
        .axi_rvalid    (instr_rvalid),
        .axi_rready    (instr_rready)
    );
    
    // Unused Write Channel for Instruction Interface (Read Only)
    assign instr_awaddr  = 0;
    assign instr_awvalid = 0;
    assign instr_wdata   = 0;
    assign instr_wstrb   = 0;
    assign instr_wvalid  = 0;
    assign instr_bready  = 0;

    // Control Unit
    control_unit u_control_unit (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .reg_write  (reg_write),
        .mem_write  (mem_write),
        .mem_read   (mem_read),
        .alu_src    (alu_src),
        .mem_to_reg (mem_to_reg),
        .alu_op     (alu_op),
        .branch     (branch),
        .jump       (jump),
        .jalr       (jalr),
        .lui        (lui),
        .auipc      (auipc)
    );

    // Datapath
    datapath u_datapath (
        .clk           (clk),
        .rst_n         (rst_n),
        .instr         (instr),
        .pc            (pc),
        .reg_write     (reg_write && instr_valid), // Only write if instruction is valid
        .mem_to_reg    (mem_to_reg),
        .alu_src       (alu_src),
        .alu_op        (alu_op),
        .jalr          (jalr),
        .lui           (lui),
        .auipc         (auipc),
        .mem_rdata     (mem_rdata),
        .mem_wdata     (mem_wdata),
        .alu_result    (alu_result),
        .zero          (zero),
        .branch_target (branch_target)
    );

    // Data Memory Access Logic
    assign mem_req_valid = (mem_write || mem_read) && instr_valid;
    
    // Stall logic: If we need memory access, we must wait for it to complete.
    // If we don't need memory, we are ready for next instruction immediately.
    assign instr_ready = mem_req_valid ? mem_resp_valid : 1'b1;

    // Data AXI Adapter
    axi_adapter u_data_adapter (
        .clk         (clk),
        .rst_n       (rst_n),
        .req_valid   (mem_req_valid),
        .req_write   (mem_write),
        .req_addr    (alu_result),
        .req_wdata   (mem_wdata),
        .req_wstrb   (4'b1111), // Simplified: Always full word for now
        .resp_rdata  (mem_rdata),
        .resp_valid  (mem_resp_valid),
        .req_ready   (mem_req_ready),
        .axi_awaddr  (data_awaddr),
        .axi_awvalid (data_awvalid),
        .axi_awready (data_awready),
        .axi_wdata   (data_wdata),
        .axi_wstrb   (data_wstrb),
        .axi_wvalid  (data_wvalid),
        .axi_wready  (data_wready),
        .axi_bresp   (data_bresp),
        .axi_bvalid  (data_bvalid),
        .axi_bready  (data_bready),
        .axi_araddr  (data_araddr),
        .axi_arvalid (data_arvalid),
        .axi_arready (data_arready),
        .axi_rdata   (data_rdata),
        .axi_rresp   (data_rresp),
        .axi_rvalid  (data_rvalid),
        .axi_rready  (data_rready)
    );

endmodule
