module control_unit (
    input  logic [6:0]  opcode,
    input  logic [2:0]  funct3,
    input  logic [6:0]  funct7,
    output logic        reg_write,
    output logic        mem_write,
    output logic        mem_read,
    output logic        alu_src,    // 0: rs2, 1: imm
    output logic        mem_to_reg, // 0: alu_result, 1: mem_data
    output logic [3:0]  alu_op,
    output logic        branch,
    output logic        jump,
    output logic        jalr,
    output logic        lui,
    output logic        auipc
);

    // Opcode Definitions
    localparam OP_R_TYPE  = 7'b0110011;
    localparam OP_I_TYPE  = 7'b0010011;
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_JALR    = 7'b1100111;
    localparam OP_LUI     = 7'b0110111;
    localparam OP_AUIPC   = 7'b0010111;

    // ALU Operations
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b1000;
    localparam ALU_SLL  = 4'b0001;
    localparam ALU_SLT  = 4'b0010;
    localparam ALU_SLTU = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SRA  = 4'b1101;
    localparam ALU_OR   = 4'b0110;
    localparam ALU_AND  = 4'b0111;

    always_comb begin
        // Default values
        reg_write  = 0;
        mem_write  = 0;
        mem_read   = 0;
        alu_src    = 0;
        mem_to_reg = 0;
        alu_op     = ALU_ADD;
        branch     = 0;
        jump       = 0;
        jalr       = 0;
        lui        = 0;
        auipc      = 0;

        case (opcode)
            OP_R_TYPE: begin
                reg_write = 1;
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                endcase
            end
            OP_I_TYPE: begin
                reg_write = 1;
                alu_src   = 1;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                endcase
            end
            OP_LOAD: begin
                reg_write  = 1;
                mem_read   = 1;
                alu_src    = 1;
                mem_to_reg = 1;
                alu_op     = ALU_ADD;
            end
            OP_STORE: begin
                mem_write = 1;
                alu_src   = 1;
                alu_op    = ALU_ADD;
            end
            OP_BRANCH: begin
                branch = 1;
                case (funct3)
                    3'b000: alu_op = ALU_SUB;  // BEQ
                    3'b001: alu_op = ALU_SUB;  // BNE
                    3'b100: alu_op = ALU_SLT;  // BLT
                    3'b101: alu_op = ALU_SLT;  // BGE
                    3'b110: alu_op = ALU_SLTU; // BLTU
                    3'b111: alu_op = ALU_SLTU; // BGEU
                    default: alu_op = ALU_SUB;
                endcase
            end
            OP_JAL: begin
                jump      = 1;
                reg_write = 1;
            end
            OP_JALR: begin
                jalr      = 1;
                reg_write = 1;
                alu_src   = 1;
                alu_op    = ALU_ADD;
            end
            OP_LUI: begin
                lui       = 1;
                reg_write = 1;
            end
            OP_AUIPC: begin
                auipc     = 1;
                reg_write = 1;
            end
        endcase
    end

endmodule
