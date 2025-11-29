module axi_adapter (
    input  logic        clk,
    input  logic        rst_n,

    // Core Interface
    input  logic        req_valid,
    input  logic        req_write, // 1: Write, 0: Read
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic [3:0]  req_wstrb,
    output logic [31:0] resp_rdata,
    output logic        resp_valid,
    output logic        req_ready,

    // AXI4-Lite Master Interface
    output logic [31:0] axi_awaddr,
    output logic        axi_awvalid,
    input  logic        axi_awready,
    output logic [31:0] axi_wdata,
    output logic [3:0]  axi_wstrb,
    output logic        axi_wvalid,
    input  logic        axi_wready,
    input  logic [1:0]  axi_bresp,
    input  logic        axi_bvalid,
    output logic        axi_bready,
    output logic [31:0] axi_araddr,
    output logic        axi_arvalid,
    input  logic        axi_arready,
    input  logic [31:0] axi_rdata,
    input  logic [1:0]  axi_rresp,
    input  logic        axi_rvalid,
    output logic        axi_rready
);

    typedef enum logic [2:0] {IDLE, WRITE_ADDR_DATA, WRITE_RESP, READ_ADDR, READ_DATA} state_t;
    state_t state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        
        // Default Outputs
        req_ready   = 0;
        resp_valid  = 0;
        
        axi_awvalid = 0;
        axi_wvalid  = 0;
        axi_bready  = 0;
        axi_arvalid = 0;
        axi_rready  = 0;

        axi_awaddr  = req_addr;
        axi_wdata   = req_wdata;
        axi_wstrb   = req_wstrb;
        axi_araddr  = req_addr;

        case (state)
            IDLE: begin
                req_ready = 1;
                if (req_valid) begin
                    if (req_write) begin
                        next_state = WRITE_ADDR_DATA;
                    end else begin
                        next_state = READ_ADDR;
                    end
                end
            end

            WRITE_ADDR_DATA: begin
                axi_awvalid = 1;
                axi_wvalid  = 1;
                if (axi_awready && axi_wready) begin
                    next_state = WRITE_RESP;
                end
                // Note: Simple handling, assumes both ready same cycle or wait for both. 
                // A more robust one would handle them independently.
            end

            WRITE_RESP: begin
                axi_bready = 1;
                if (axi_bvalid) begin
                    resp_valid = 1; // Write complete
                    next_state = IDLE;
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
                    resp_valid = 1;
                    next_state = IDLE;
                end
            end
        endcase
    end
    
    assign resp_rdata = axi_rdata;

endmodule
