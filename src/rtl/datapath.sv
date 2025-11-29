module datapath (
    input  logic        clk,
    input  logic        rst_n,
    
    // Instruction and PC from Fetch Unit
    input  logic [31:0] instr,
    input  logic [31:0] pc,
    
    // Control Signals
    input  logic        reg_write,
    input  logic        mem_to_reg,
    input  logic        alu_src,
    input  logic [3:0]  alu_op,
    input  logic        jalr,
    input  logic        lui,
    input  logic        auipc,
    
    // Data Memory Interface
    input  logic [31:0] mem_rdata,
    output logic [31:0] mem_wdata,
    output logic [31:0] alu_result, // Used as address for memory
    
    // Branch/Jump Outputs
    output logic        zero,
    output logic [31:0] branch_target
);

    // Internal Signals
    logic [6:0]  opcode;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [31:0] imm_i;
    logic [31:0] imm_s;
    logic [31:0] imm_b;
    logic [31:0] imm_u;
    logic [31:0] imm_j;
    
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] src_a;
    logic [31:0] src_b;
    logic [31:0] alu_out;
    logic [31:0] rd_data;
    logic [31:0] imm_val;

    // Decoder
    decoder u_decoder (
        .instr  (instr),
        .opcode (opcode),
        .rd     (rd),
        .rs1    (rs1),
        .rs2    (rs2),
        .funct3 (funct3),
        .funct7 (funct7),
        .imm_i  (imm_i),
        .imm_s  (imm_s),
        .imm_b  (imm_b),
        .imm_u  (imm_u),
        .imm_j  (imm_j)
    );

    // Register File
    reg_file u_reg_file (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1),
        .rs2_addr (rs2),
        .rd_addr  (rd),
        .rd_data  (rd_data),
        .we       (reg_write),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // Immediate Selection Logic (Simplified)
    always_comb begin
        case (opcode)
            7'b0010011: imm_val = imm_i; // I-Type
            7'b0000011: imm_val = imm_i; // Load
            7'b0100011: imm_val = imm_s; // Store
            7'b1100011: imm_val = imm_b; // Branch
            7'b1101111: imm_val = imm_j; // JAL
            7'b1100111: imm_val = imm_i; // JALR
            7'b0110111: imm_val = imm_u; // LUI
            7'b0010111: imm_val = imm_u; // AUIPC
            default:    imm_val = 32'd0;
        endcase
    end

    // ALU Inputs
    assign src_a = (auipc) ? pc : rs1_data; // AUIPC uses PC
    assign src_b = (alu_src) ? imm_val : rs2_data;

    // ALU
    alu_int u_alu (
        .a      (src_a),
        .b      (src_b),
        .alu_op (alu_op),
        .result (alu_out),
        .zero   (zero)
    );

    assign alu_result = alu_out;
    assign mem_wdata  = rs2_data;

    // Write Back Logic
    always_comb begin
        if (mem_to_reg) begin
            rd_data = mem_rdata;
        end else if (lui) begin
            rd_data = imm_u;
        end else if (opcode == 7'b1101111 || opcode == 7'b1100111) begin // JAL or JALR
            rd_data = pc + 4;
        end else begin
            rd_data = alu_out;
        end
    end

    // Branch/Jump Target Calculation
    assign branch_target = (jalr) ? (rs1_data + imm_val) : (pc + imm_val);

endmodule
