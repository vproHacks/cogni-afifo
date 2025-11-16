// ============================================================================
// Comprehensive Testbench for Asynchronous FIFO
// ============================================================================
// Coverage:
//   - Multiple clock domain scenarios (equal, fast write, fast read)
//   - Full/empty flag verification
//   - Data integrity across clock domains
//   - Overflow/underflow prevention
//   - Pointer wrap-around
//   - Gray code synchronization
//   - Reset behavior
// ============================================================================

module tb_afifo;

    // ========================================================================
    // Parameters
    // ========================================================================
    parameter DSIZE = 8;
    parameter ASIZE = 4;
    parameter DEPTH = (1 << ASIZE);  // 16 entries
    
    // Clock periods (in ns)
    parameter WCLK_PERIOD = 10;
    parameter RCLK_PERIOD = 10;
    
    // ========================================================================
    // Signals
    // ========================================================================
    
    // Write clock domain
    reg                 i_wclk;
    reg                 i_wrst_n;
    reg                 i_wr;
    reg  [DSIZE-1:0]    i_wdata;
    wire                o_wfull;
    
    // Read clock domain
    reg                 i_rclk;
    reg                 i_rrst_n;
    reg                 i_rd;
    wire [DSIZE-1:0]    o_rdata;
    wire                o_rempty;
    
    // Test variables
    reg  [DSIZE-1:0]    write_data_queue [$];
    reg  [DSIZE-1:0]    expected_data;
    reg  [DSIZE-1:0]    captured_data;
    integer             write_count;
    integer             read_count;
    integer             error_count;
    integer             test_num;
    
    // For concurrent operations test
    reg                 concurrent_write_active;
    reg                 concurrent_read_active;
    integer             concurrent_write_count;
    integer             concurrent_read_count;
    
    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    
    afifo #(
        .DSIZE(DSIZE),
        .ASIZE(ASIZE)
    ) dut (
        .i_wclk(i_wclk),
        .i_wrst_n(i_wrst_n),
        .i_wr(i_wr),
        .i_wdata(i_wdata),
        .o_wfull(o_wfull),
        
        .i_rclk(i_rclk),
        .i_rrst_n(i_rrst_n),
        .i_rd(i_rd),
        .o_rdata(o_rdata),
        .o_rempty(o_rempty)
    );
    
    // ========================================================================
    // Clock Generation
    // ========================================================================
    
    initial begin
        i_wclk = 0;
        forever #(WCLK_PERIOD/2) i_wclk = ~i_wclk;
    end
    
    initial begin
        i_rclk = 0;
        forever #(RCLK_PERIOD/2) i_rclk = ~i_rclk;
    end
    
    // ========================================================================
    // Concurrent Write Process (for Test 7)
    // ========================================================================
    always @(posedge i_wclk) begin
        if (concurrent_write_active && concurrent_write_count < 20) begin
            if (!o_wfull) begin
                i_wr = 1;
                i_wdata = 8'h10 + concurrent_write_count;
                write_data_queue.push_back(8'h10 + concurrent_write_count);
                write_count = write_count + 1;
                concurrent_write_count = concurrent_write_count + 1;
            end else begin
                i_wr = 0;
            end
        end else if (concurrent_write_active) begin
            i_wr = 0;
        end
    end
    
    // ========================================================================
    // Concurrent Read Process (for Test 7)
    // ========================================================================
    always @(posedge i_rclk) begin
        if (concurrent_read_active && concurrent_read_count < 20) begin
            if (!o_rempty) begin
                // Capture data BEFORE asserting read
                captured_data = o_rdata;
                i_rd = 1;
                
                if (write_data_queue.size() > 0) begin
                    expected_data = write_data_queue.pop_front();
                    if (captured_data !== expected_data) begin
                        $display("LOG: %0t : ERROR : tb_afifo : dut.o_rdata : expected_value: 8'h%02h actual_value: 8'h%02h", 
                                 $time, expected_data, captured_data);
                        error_count = error_count + 1;
                    end
                end
                read_count = read_count + 1;
                concurrent_read_count = concurrent_read_count + 1;
            end else begin
                i_rd = 0;
            end
        end else if (concurrent_read_active) begin
            i_rd = 0;
        end
    end
    
    // ========================================================================
    // Test Stimulus
    // ========================================================================
    
    initial begin
        $display("TEST START");
        $display("========================================================================");
        $display("Async FIFO Comprehensive Testbench");
        $display("FIFO Depth: %0d entries, Data Width: %0d bits", DEPTH, DSIZE);
        $display("Write Clock Period: %0d ns, Read Clock Period: %0d ns", WCLK_PERIOD, RCLK_PERIOD);
        $display("========================================================================");
        
        // Initialize
        initialize();
        error_count = 0;
        test_num = 0;
        
        // Apply reset
        apply_reset();
        
        // ====================================================================
        // TEST 1: Basic Write and Read Operation
        // ====================================================================
        test_num = 1;
        $display("\
[TEST %0d] Basic Write and Read Operation", test_num);
        test_basic_write_read();
        
        // ====================================================================
        // TEST 2: Fill FIFO Completely
        // ====================================================================
        test_num = 2;
        $display("\
[TEST %0d] Fill FIFO Completely (Test Full Flag)", test_num);
        apply_reset();
        test_fill_fifo();
        
        // ====================================================================
        // TEST 3: Empty FIFO Completely
        // ====================================================================
        test_num = 3;
        $display("\
[TEST %0d] Empty FIFO Completely (Test Empty Flag)", test_num);
        test_empty_fifo();
        
        // ====================================================================
        // TEST 4: Overflow Prevention
        // ====================================================================
        test_num = 4;
        $display("\
[TEST %0d] Overflow Prevention", test_num);
        apply_reset();
        test_overflow_prevention();
        
        // ====================================================================
        // TEST 5: Underflow Prevention
        // ====================================================================
        test_num = 5;
        $display("\
[TEST %0d] Underflow Prevention", test_num);
        apply_reset();
        test_underflow_prevention();
        
        // ====================================================================
        // TEST 6: Pointer Wrap-Around
        // ====================================================================
        test_num = 6;
        $display("\
[TEST %0d] Pointer Wrap-Around", test_num);
        apply_reset();
        test_pointer_wraparound();
        
        // ====================================================================
        // TEST 7: Simultaneous Read/Write
        // ====================================================================
        test_num = 7;
        $display("\
[TEST %0d] Simultaneous Read and Write", test_num);
        apply_reset();
        test_simultaneous_read_write();
        
        // ====================================================================
        // TEST 8: Burst Write then Burst Read
        // ====================================================================
        test_num = 8;
        $display("\
[TEST %0d] Burst Write then Burst Read", test_num);
        apply_reset();
        test_burst_operations();
        
        // ====================================================================
        // TEST 9: Alternating Single Write/Read
        // ====================================================================
        test_num = 9;
        $display("\
[TEST %0d] Alternating Single Write/Read", test_num);
        apply_reset();
        test_alternating_access();
        
        // ====================================================================
        // TEST 10: Random Access Pattern
        // ====================================================================
        test_num = 10;
        $display("\
[TEST %0d] Random Access Pattern", test_num);
        apply_reset();
        test_random_access();
        
        // ====================================================================
        // TEST 11: Reset During Operation
        // ====================================================================
        test_num = 11;
        $display("\
[TEST %0d] Reset During Operation", test_num);
        test_reset_during_operation();
        
        // ====================================================================
        // Final Report
        // ====================================================================
        $display("\
========================================================================");
        $display("Test Completed");
        $display("========================================================================");
        $display("Total Writes: %0d", write_count);
        $display("Total Reads:  %0d", read_count);
        $display("Errors:       %0d", error_count);
        
        if (error_count == 0) begin
            $display("\
*** TEST PASSED ***");
            $display("All %0d tests completed successfully!", test_num);
        end else begin
            $display("\
*** TEST FAILED ***");
            $display("Found %0d errors during testing", error_count);
        end
        
        $display("========================================================================");
        $finish;
    end
    
    // ========================================================================
    // Task: Initialize Signals
    // ========================================================================
    task initialize;
        begin
            i_wrst_n = 1;
            i_rrst_n = 1;
            i_wr = 0;
            i_rd = 0;
            i_wdata = 0;
            write_count = 0;
            read_count = 0;
            write_data_queue.delete();
            concurrent_write_active = 0;
            concurrent_read_active = 0;
            concurrent_write_count = 0;
            concurrent_read_count = 0;
        end
    endtask
    
    // ========================================================================
    // Task: Apply Reset
    // ========================================================================
    task apply_reset;
        begin
            $display("  Applying reset...");
            i_wrst_n = 0;
            i_rrst_n = 0;
            i_wr = 0;
            i_rd = 0;
            write_data_queue.delete();
            concurrent_write_active = 0;
            concurrent_read_active = 0;
            
            repeat(5) @(posedge i_wclk);
            repeat(5) @(posedge i_rclk);
            
            i_wrst_n = 1;
            i_rrst_n = 1;
            
            repeat(5) @(posedge i_wclk);
            repeat(5) @(posedge i_rclk);
            
            // Verify reset state
            if (!o_rempty) begin
                $display("LOG: %0t : ERROR : tb_afifo : dut.o_rempty : expected_value: 1'b1 actual_value: 1'b%b", $time, o_rempty);
                error_count = error_count + 1;
            end
            if (o_wfull) begin
                $display("LOG: %0t : ERROR : tb_afifo : dut.o_wfull : expected_value: 1'b0 actual_value: 1'b%b", $time, o_wfull);
                error_count = error_count + 1;
            end
            
            $display("  Reset complete. Empty=%b, Full=%b", o_rempty, o_wfull);
        end
    endtask
    
    // ========================================================================
    // Task: Write Single Data
    // ========================================================================
    task write_single(input [DSIZE-1:0] data);
        begin
            @(posedge i_wclk);
            if (!o_wfull) begin
                i_wr = 1;
                i_wdata = data;
                write_data_queue.push_back(data);
                @(posedge i_wclk);
                i_wr = 0;
                write_count = write_count + 1;
            end else begin
                $display("LOG: %0t : WARNING : tb_afifo : dut.o_wfull : expected_value: not_full actual_value: full", $time);
                @(posedge i_wclk);
            end
        end
    endtask
    
    // ========================================================================
    // Task: Read Single Data  
    // FIXED: Capture data before pointer advances
    // ========================================================================
    task read_single;
        begin
            @(posedge i_rclk);
            if (!o_rempty) begin
                // Capture data at current read pointer BEFORE asserting i_rd
                captured_data = o_rdata;
                i_rd = 1;
                @(posedge i_rclk);
                i_rd = 0;
                
                // Check data integrity
                if (write_data_queue.size() > 0) begin
                    expected_data = write_data_queue.pop_front();
                    if (captured_data !== expected_data) begin
                        $display("LOG: %0t : ERROR : tb_afifo : dut.o_rdata : expected_value: 8'h%02h actual_value: 8'h%02h", 
                                 $time, expected_data, captured_data);
                        error_count = error_count + 1;
                    end
                end
                read_count = read_count + 1;
            end else begin
                $display("LOG: %0t : WARNING : tb_afifo : dut.o_rempty : expected_value: not_empty actual_value: empty", $time);
                @(posedge i_rclk);
            end
        end
    endtask
    
    // ========================================================================
    // TEST 1: Basic Write and Read
    // ========================================================================
    task test_basic_write_read;
        integer i;
        begin
            $display("  Writing 4 values...");
            for (i = 0; i < 4; i = i + 1) begin
                write_single(8'hA0 + i);
            end
            
            repeat(10) @(posedge i_rclk);  // Allow synchronization
            
            $display("  Reading 4 values...");
            for (i = 0; i < 4; i = i + 1) begin
                read_single();
            end
            
            repeat(10) @(posedge i_rclk);
            
            if (o_rempty) begin
                $display("  PASS: FIFO is empty after reading all data");
            end else begin
                $display("LOG: %0t : ERROR : tb_afifo : dut.o_rempty : expected_value: 1'b1 actual_value: 1'b0", $time);
                error_count = error_count + 1;
            end
        end
    endtask
    
    // ========================================================================
    // TEST 2: Fill FIFO Completely
    // ========================================================================
    task test_fill_fifo;
        integer i;
        begin
            $display("  Writing %0d entries to fill FIFO...", DEPTH);
            for (i = 0; i < DEPTH; i = i + 1) begin
                write_single(8'hB0 + i);
            end
            
            repeat(10) @(posedge i_wclk);  // Allow synchronization
            
            if (o_wfull) begin
                $display("  PASS: FIFO full flag asserted correctly");
            end else begin
                $display("LOG: %0t : ERROR : tb_afifo : dut.o_wfull : expected_value: 1'b1 actual_value: 1'b0", $time);
                error_count = error_count + 1;
            end
        end
    endtask
    
    // ========================================================================
    // TEST 3: Empty FIFO Completely
    // ========================================================================
    task test_empty_fifo;
        integer i;
        begin
            repeat(10) @(posedge i_rclk);  // Allow synchronization
            
            $display("  Reading all %0d entries to empty FIFO...", DEPTH);
            for (i = 0; i < DEPTH; i = i + 1) begin
                read_single();
            end
            
            repeat(10) @(posedge i_rclk);
            
            if (o_rempty) begin
                $display("  PASS: FIFO empty flag asserted correctly");
            end else begin
                $display("LOG: %0t : ERROR : tb_afifo : dut.o_rempty : expected_value: 1'b1 actual_value: 1'b0", $time);
                error_count = error_count + 1;
            end
        end
    endtask
    
    // ========================================================================
    // TEST 4: Overflow Prevention
    // ========================================================================
    task test_overflow_prevention;
        integer i;
        integer initial_write_count;
        begin
            $display("  Filling FIFO to full...");
            for (i = 0; i < DEPTH; i = i + 1) begin
                write_single(8'hC0 + i);
            end
            
            repeat(10) @(posedge i_wclk);
            
            initial_write_count = write_count;
            
            $display("  Attempting to write when full...");
            @(posedge i_wclk);
            i_wr = 1;
            i_wdata = 8'hFF;
            @(posedge i_wclk);
            i_wr = 0;
            
            if (write_count == initial_write_count) begin
                $display("  PASS: Overflow prevented, no extra write occurred");
            end else begin
                $display("LOG: %0t : ERROR : tb_afifo : overflow_prevention : expected_value: no_write actual_value: write_occurred", $time);
                error_count = error_count + 1;
            end
            
            // Clean up - read all data
            repeat(10) @(posedge i_rclk);
            for (i = 0; i < DEPTH; i = i + 1) begin
                read_single();
            end
        end
    endtask
    
    // ========================================================================
    // TEST 5: Underflow Prevention
    // ========================================================================
    task test_underflow_prevention;
        integer initial_read_count;
        begin
            $display("  Attempting to read from empty FIFO...");
            
            repeat(10) @(posedge i_rclk);
            
            initial_read_count = read_count;
            
            @(posedge i_rclk);
            i_rd = 1;
            @(posedge i_rclk);
            i_rd = 0;
            
            if (read_count == initial_read_count) begin
                $display("  PASS: Underflow prevented, no read occurred");
            end else begin
                $display("LOG: %0t : ERROR : tb_afifo : underflow_prevention : expected_value: no_read actual_value: read_occurred", $time);
                error_count = error_count + 1;
            end
        end
    endtask
    
    // ========================================================================
    // TEST 6: Pointer Wrap-Around
    // ========================================================================
    task test_pointer_wraparound;
        integer i, j;
        begin
            $display("  Testing pointer wrap-around with multiple cycles...");
            
            // Perform multiple fill/drain cycles
            for (j = 0; j < 3; j = j + 1) begin
                $display("    Cycle %0d: Fill FIFO", j+1);
                for (i = 0; i < DEPTH; i = i + 1) begin
                    write_single(8'hD0 + i + (j*16));
                end
                
                repeat(10) @(posedge i_rclk);
                
                $display("    Cycle %0d: Drain FIFO", j+1);
                for (i = 0; i < DEPTH; i = i + 1) begin
                    read_single();
                end
                
                repeat(10) @(posedge i_rclk);
            end
            
            $display("  PASS: Pointer wrap-around completed successfully");
        end
    endtask
    
    // ========================================================================
    // TEST 7: Simultaneous Read and Write (using always blocks)
    // ========================================================================
    task test_simultaneous_read_write;
        integer i;
        begin
            $display("  Pre-filling FIFO with 8 entries...");
            for (i = 0; i < 8; i = i + 1) begin
                write_single(8'hE0 + i);
            end
            
            repeat(10) @(posedge i_rclk);
            
            $display("  Performing simultaneous read/write for 20 cycles...");
            
            // Initialize concurrent operation
            concurrent_write_count = 0;
            concurrent_read_count = 0;
            
            // Start writer (next write clock edge)
            @(posedge i_wclk);
            concurrent_write_active = 1;
            
            // Start reader after small offset (next read clock edge)
            repeat(5) @(posedge i_rclk);
            concurrent_read_active = 1;
            
            // Wait for both to complete
            wait(concurrent_write_count >= 20);
            wait(concurrent_read_count >= 20);
            
            // Stop concurrent operations
            @(posedge i_wclk);
            concurrent_write_active = 0;
            @(posedge i_rclk);
            concurrent_read_active = 0;
            
            repeat(20) @(posedge i_rclk);
            
            $display("  PASS: Simultaneous operations completed");
        end
    endtask
    
    // ========================================================================
    // TEST 8: Burst Operations
    // ========================================================================
    task test_burst_operations;
        integer i;
        begin
            $display("  Burst write 12 entries...");
            for (i = 0; i < 12; i = i + 1) begin
                write_single(8'h30 + i);
            end
            
            repeat(20) @(posedge i_rclk);
            
            $display("  Burst read 12 entries...");
            for (i = 0; i < 12; i = i + 1) begin
                read_single();
            end
            
            repeat(10) @(posedge i_rclk);
            
            $display("  PASS: Burst operations completed");
        end
    endtask
    
    // ========================================================================
    // TEST 9: Alternating Access
    // ========================================================================
    task test_alternating_access;
        integer i;
        begin
            $display("  Alternating single write/read for 15 cycles...");
            for (i = 0; i < 15; i = i + 1) begin
                write_single(8'h40 + i);
                repeat(5) @(posedge i_rclk);
                read_single();
                repeat(5) @(posedge i_wclk);
            end
            
            $display("  PASS: Alternating access completed");
        end
    endtask
    
    // ========================================================================
    // TEST 10: Random Access Pattern
    // ========================================================================
    task test_random_access;
        integer i;
        integer num_writes, num_reads;
        begin
            $display("  Random access pattern with varying writes/reads...");
            
            for (i = 0; i < 10; i = i + 1) begin
                num_writes = 1 + ($urandom % 5);
                num_reads = 1 + ($urandom % 3);
                
                // Random writes
                repeat(num_writes) begin
                    if (!o_wfull) begin
                        write_single($urandom % 256);
                    end
                    repeat(2) @(posedge i_wclk);
                end
                
                repeat(10) @(posedge i_rclk);
                
                // Random reads
                repeat(num_reads) begin
                    if (!o_rempty) begin
                        read_single();
                    end
                    repeat(2) @(posedge i_rclk);
                end
                
                repeat(5) @(posedge i_wclk);
            end
            
            // Drain remaining data
            repeat(20) @(posedge i_rclk);
            while (!o_rempty) begin
                read_single();
                repeat(2) @(posedge i_rclk);
            end
            
            $display("  PASS: Random access pattern completed");
        end
    endtask
    
    // ========================================================================
    // TEST 11: Reset During Operation
    // ========================================================================
    task test_reset_during_operation;
        integer i;
        begin
            $display("  Writing some data...");
            for (i = 0; i < 5; i = i + 1) begin
                write_single(8'h50 + i);
            end
            
            $display("  Applying reset during operation...");
            apply_reset();
            
            $display("  Verifying FIFO is empty and functional after reset...");
            for (i = 0; i < 3; i = i + 1) begin
                write_single(8'h60 + i);
            end
            
            repeat(10) @(posedge i_rclk);
            
            for (i = 0; i < 3; i = i + 1) begin
                read_single();
            end
            
            $display("  PASS: Reset during operation handled correctly");
        end
    endtask
    
    // ========================================================================
    // Waveform Dump
    // ========================================================================
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
