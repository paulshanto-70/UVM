// Code your testbench here
// or browse Examples
`include "uvm_macros.svh"
import uvm_pkg::*;
interface intf(input clk,input rst);
   logic rw_n;
   logic [7:0]din;
   logic[3:0]addr;
   logic[7:0]dout;
endinterface


class transaction extends uvm_sequence_item;
  function new(string obj="trans");
    super.new(obj);
  endfunction
  int a[16]; // Static array to store written addresses
  int a_index = 0; // Index to track stored addresses
  rand bit[7:0] din;
  rand bit rw_n;
  randc bit[3:0] addr;
  bit[7:0] dout;
  `uvm_object_utils_begin(transaction)
  `uvm_field_int(din,UVM_DEFAULT);
  `uvm_field_int(rw_n,UVM_DEFAULT);
  `uvm_field_int(addr,UVM_DEFAULT);
  `uvm_field_int(dout,UVM_DEFAULT);
  `uvm_object_utils_end  
  constraint read_c {
    if (rw_n == 1) {
      addr inside {a}; // Ensure addr is within stored addresses
    }
  }

  // Read/Write Distribution Constraint
  constraint readwrite_c {
    rw_n dist {0 := 50, 1 := 50}; // 60% Write, 40% Read
  }
  
  function void post_randomize();
    if (rw_n == 0) begin
      a[a_index] = addr; // Store written address
      a_index++;
    end
  endfunction
endclass

class sequence1 extends uvm_sequence#(transaction);
  transaction t;
  `uvm_object_utils(sequence1);
  function new(string comp="seq");
    super.new(comp);
  endfunction
  
  virtual task body();
    t=transaction::type_id::create("t");
    repeat(16) begin       
       start_item(t);
       assert(t.randomize);
      `uvm_info("seq",$sformatf("din=%0d r_w_enable=%0d  addr=%0d  ",t.din,t.rw_n,t.addr),UVM_NONE);
       finish_item(t);
     end
  endtask
  endclass

class driver extends uvm_driver#(transaction);
  `uvm_component_utils(driver)
  function new(string comp="driv",uvm_component parent=null);
    super.new(comp,parent);
  endfunction
  
  virtual intf vif;
  transaction tc;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tc=transaction::type_id::create("tc",this);
    assert(uvm_config_db#(virtual intf)::get(this,"","vif",vif));
  endfunction
    
  virtual task run_phase(uvm_phase phase);
    forever begin
      @(negedge vif.clk);
    seq_item_port.get_next_item(tc);
    vif.din=tc.din;
    vif.rw_n=tc.rw_n;
    vif.addr=tc.addr;
      `uvm_info("driv",$sformatf("din=%0d r_w_enable=%0d  addr=%0d  ",tc.din,tc.rw_n,tc.addr),UVM_NONE);
    seq_item_port.item_done();
      
      
    end
  endtask
endclass

class monitor extends uvm_monitor;
  `uvm_component_utils(monitor)
  uvm_analysis_port#(transaction) send;
  function new(string comp="mon",uvm_component parent=null);
    super.new(comp,parent);
    send=new("send",this);
  endfunction
  virtual intf vif;
  transaction t;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
     t=transaction::type_id::create("t");
     assert(uvm_config_db#(virtual intf)::get(this,"","vif",vif));
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      #1;
      t.din=vif.din;
      t.rw_n=vif.rw_n;
      t.addr=vif.addr;
      t.dout=vif.dout;
      `uvm_info("mon",$sformatf("din=%0d r_w_enable=%0d  addr=%0d dout=%0d ",t.din,t.rw_n,t.addr,t.dout),UVM_NONE);
      send.write(t);
    end
  endtask
endclass

class scoreboard extends uvm_scoreboard;
  reg[7:0]mem[15:0];
  
  
  `uvm_component_utils(scoreboard)
  uvm_analysis_imp#(transaction,scoreboard) recv;
  
  function new(string comp="sco",uvm_component parent=null);
    super.new(comp,parent);
    recv=new("recv",this);
    
  for(int i=0;i<16;i++) begin
    mem[i]=0;
  end
  endfunction
  
  transaction tr;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tr=transaction::type_id::create("tr",this);
    endfunction
  
  virtual function void write(input transaction t);
    tr=t;
    `uvm_info("sco",$sformatf("din=%0d r_w_enable=%0d  addr=%0d dout=%0d ",tr.din,tr.rw_n,tr.addr,tr.dout),UVM_NONE);
    if(tr.rw_n==0)
      mem[tr.addr]=tr.din;
    else if(tr.rw_n==1)begin
      if(tr.dout==mem[tr.addr])begin
        `uvm_info("sco","TEST PASSED",UVM_NONE);
      end
      else begin
        `uvm_info("sco","TEST FAILED",UVM_NONE);
      end
    end       
      
  endfunction  
endclass
  
  
  
  
      
    

class agent extends uvm_agent;
        `uvm_component_utils(agent);
        uvm_sequencer#(transaction) sqr;
        driver d;
  		monitor m;
        function new(string comp="agent",uvm_component parent=null);
    super.new(comp,parent);
  endfunction
        virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
          sqr=uvm_sequencer#(transaction)::type_id::create("sqr",this);
          d=driver::type_id::create("d",this);
          m=monitor::type_id::create("m",this);
  endfunction
        
         virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
           d.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

class env extends uvm_env;
  `uvm_component_utils(env);
 agent a;
  scoreboard s;
  function new(string comp="env",uvm_component parent=null);
    super.new(comp,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    a=agent::type_id::create("a",this);
    s=scoreboard::type_id::create("s",this);
  endfunction 
  
 virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
   a.m.send.connect(s.recv);
 endfunction

endclass



class test extends uvm_test;
  `uvm_component_utils(test);
  env e;
  sequence1 s;
  function new(string comp="test",uvm_component  c);
    super.new(comp,c);
  endfunction
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    e=env::type_id::create("e",this);
     s=sequence1::type_id::create("s");
  endfunction
  
  virtual task run_phase(uvm_phase phase);
          super.run_phase(phase);
   phase.raise_objection(this);
    s.start(e.a.sqr);
    #100;
   phase.drop_objection(this);
 endtask
endclass

module tb;
  bit clk=1,rst;
  intf vif(clk,rst);
  ram dut(vif.dout,vif.clk,vif.rst,vif.rw_n,vif.addr,vif.din);
  always #5 clk=~clk;
  initial begin
    uvm_config_db#(virtual intf)::set(null,"uvm_test_top.e.a*","vif",vif);
    run_test("test");
  end
  initial begin
    rst=1;
    #10 rst=0;
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    #300;
    $finish;  
  end
endmodule
  
    
    
  