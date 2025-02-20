module ram(dout,clk,rst,rw_n,addr,din);
input logic clk,rst,rw_n;
input logic [7:0]din;
input logic[3:0]addr;
output logic[7:0]dout;
logic [7:0]ram[15:0];
int i;
always@(posedge clk)
begin
if(rst)
 begin
for(i=0;i<16;i=i+1)
begin
ram[i]=0;
end
end
else
begin
if(!rw_n)
begin
ram[addr]=din;
end
else
dout=ram[addr];
end
end
endmodule