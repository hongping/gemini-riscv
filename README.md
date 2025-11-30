# Simple RISC-V Core

## Description
A simplified implementation of a RISC-V processor core in SystemVerilog. This project demonstrates a basic 32-bit RISC-V integer (RV32I) core with a decoupled fetch unit and AXI4-Lite interfaces.

## Features
- **ISA**: RV32I Base Integer Instruction Set (Subset)
- **Interfaces**: AXI4-Lite Interface for Instruction and Data Memory
- **Architecture**:
    - Decoupled Fetch Unit with pre-fetch buffer
    - Simple Control Unit and Datapath

## Supported Instructions
The core supports a subset of the RV32I instruction set:

### R-Type
- ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND

### I-Type
- ADDI, SLLI, SLTI, SLTIU, XORI, SRLI, SRAI, ORI, ANDI

### Load/Store
- LW (Load Word)
- SW (Store Word)

### Branch
- BEQ, BNE

### Jump
- JAL, JALR

### Upper Immediate
- LUI, AUIPC

## Testbench Usage
The testbench (`src/verif/tb_riscv_core.sv`) currently uses a hardcoded program loaded directly into the memory array.

To run a different program, you need to modify the `initial` block in `src/verif/tb_riscv_core.sv`:

```systemverilog
// src/verif/tb_riscv_core.sv

initial begin
    // Initialize Memory
    for (int i = 0; i < 1024; i++) memory[i] = 0;

    // Load your program here (Machine Code)
    memory[0] = 32'h...; // Instruction 0
    memory[1] = 32'h...; // Instruction 1
    // ...
end
```

You can compile your assembly code to machine code (hex) using a RISC-V assembler and then update the `memory` array assignments.

## Directory Structure
- `src/rtl`: RTL source code (SystemVerilog)
- `src/verif`: Verification files (Testbench)

## Simulation
To run the simulation, you can use the provided filelists.

### Filelists
- RTL: `src/rtl/filelist.f`
- Verification: `src/verif/filelist.f`

### Example Command
```bash
# Example using a generic simulator
<simulator_command> -f src/rtl/filelist.f -f src/verif/filelist.f
```

### DSim
This repository includes build configuration files for **DSim** (by Ansys). You can use the provided `gemini-riscv.dpf` to set up your simulation environment.
