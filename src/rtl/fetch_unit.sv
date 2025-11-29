module fetch_unit (
    input  logic        clk,
    input  logic        rst_n,
    
    // Core Interface
    input  logic        branch_taken,
    input  logic [31:0] branch_target,
    output logic [31:0] pc,
    output logic [31:0] instr,
    output logic        instr_valid,
    input  logic        instr_ready, // Core is ready to accept instruction

    // AXI4-Lite Instruction Master Interface
    output logic [31:0] axi_araddr,
    output logic        axi_arvalid,
    input  logic        axi_arready,
    input  logic [31:0] axi_rdata,
    input  logic [1:0]  axi_rresp,
    input  logic        axi_rvalid,
    output logic        axi_rready
);

    // PC Logic
    logic [31:0] current_pc;
    logic [31:0] next_pc;
    logic        pc_write;

    // Buffer Logic
    localparam BUFFER_DEPTH = 2;
    logic [31:0] buffer_data [BUFFER_DEPTH-1:0];
    logic [31:0] buffer_pc   [BUFFER_DEPTH-1:0]; // Store PC associated with instruction
    logic        buffer_valid [BUFFER_DEPTH-1:0];
    logic        buffer_full;
    logic        buffer_empty;
    logic        push;
    logic        pop;
    logic        wr_ptr;
    logic        rd_ptr;
    logic [1:0]  count;

    // AXI Fetch State Machine
    typedef enum logic [1:0] {IDLE, READ_ADDR, READ_DATA} state_t;
    state_t state, next_state;

    // PC Update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_pc <= 32'd0;
        end else if (branch_taken) begin
            current_pc <= branch_target;
        end else if (pc_write) begin
            current_pc <= next_pc;
        end
    end

    assign next_pc = current_pc + 4;

    // Buffer Control
    assign buffer_full  = (count == BUFFER_DEPTH);
    assign buffer_empty = (count == 0);
    
    // We fetch when buffer is not full and we are not branching
    assign pc_write = (state == READ_ADDR && axi_arready && !branch_taken && !buffer_full);

    // AXI Master Control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else if (branch_taken) begin
            state <= IDLE; // Reset fetch state on branch
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        axi_arvalid = 0;
        axi_rready = 0;
        axi_araddr = current_pc;
        push = 0;

        case (state)
            IDLE: begin
                if (!buffer_full) begin
                    next_state = READ_ADDR;
                end
            end
            READ_ADDR: begin
                axi_arvalid = 1;
                if (axi_arready) begin
                    next_state = READ_DATA;
                end
            end
            READ_DATA: begin
                axi_rready = 1;
                if (axi_rvalid) begin
                    push = 1;
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Outstanding PC Logic
    logic [31:0] outstanding_pc;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outstanding_pc <= 32'd0;
        end else if (pc_write) begin
            outstanding_pc <= current_pc;
        end
    end

    // Buffer Implementation (FIFO)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
            for (int i=0; i<BUFFER_DEPTH; i++) begin
                buffer_valid[i] <= 0;
            end
        end else if (branch_taken) begin
            // Flush buffer on branch
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
            for (int i=0; i<BUFFER_DEPTH; i++) begin
                buffer_valid[i] <= 0;
            end
        end else begin
            if (push && !buffer_full) begin
                buffer_data[wr_ptr] <= axi_rdata;
                buffer_pc[wr_ptr]   <= outstanding_pc; // Use the latched PC
                buffer_valid[wr_ptr] <= 1;
                wr_ptr <= wr_ptr + 1; // Wrap around handled by width if power of 2, else mod
                if (!pop) count <= count + 1;
            end
            
            if (pop && !buffer_empty) begin
                buffer_valid[rd_ptr] <= 0;
                rd_ptr <= rd_ptr + 1;
                if (!push) count <= count - 1;
            end
        end
    end

    // Output to Core
    assign instr_valid = !buffer_empty;
    assign instr       = buffer_data[rd_ptr];
    assign pc          = buffer_pc[rd_ptr]; // PC of the current instruction
    assign pop         = instr_valid && instr_ready;

endmodule
