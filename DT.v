`timescale 1ns/10ps
module DT(
	input 			clk, 
	input			reset,
	output	reg		done ,
	output	reg		sti_rd ,
	output	reg 	[9:0]	sti_addr ,
	input		[0:15]	sti_di,
	output	reg		res_wr ,
	output	reg		res_rd ,
	output	reg 	[13:0]	res_addr ,
	output	reg 	[7:0]	res_do,
	input		[7:0]	res_di,
	output  reg fwpass_finish
	);
    parameter idle = 4'd0;
    parameter read_sti = 4'd1;
    parameter write_sti = 4'd2;
    parameter write_sti_finish = 4'd3;
    parameter read_fw = 4'd4;
    parameter write_fw = 4'd5;
    parameter write_fw_fin = 4'd6;
    parameter read_bw = 4'd7;
    parameter write_bw = 4'd8;
    parameter write_bw_fin = 4'd9;
    reg [4:0]cnt;
    reg [3:0] cs, ns;
    reg [7:0] min;
//=================cs=============================
    always @(posedge clk , negedge reset) begin
        if (!reset) 
            cs <= idle;
        else
            cs <= ns;
    end
//=================ns=============================
    always @(*) begin
        case (cs)
            idle: begin
                if(!reset)
                    ns = idle; 
                else
                    ns = read_sti;
            end
            read_sti:begin
                ns = write_sti;
            end
                
            write_sti:begin
                if(res_addr == 16383)
                    ns = write_sti_finish;
                else begin
                    if(cnt == 16)
                        ns = read_sti;
                    else
                        ns = write_sti; 
                end          
            end
            write_sti_finish:begin
                ns= read_fw;
            end               
            read_fw:begin
                if(cnt == 5)
                    ns = write_fw;
                else begin
                    if(ns == 7)
                        ns = 7;
                    else
                        ns = read_fw;
                end         
            end
            write_fw:begin
               if(res_addr == 16254) 
                    ns = write_fw_fin;
               else 
                    ns = read_fw;
            end        
            write_fw_fin:begin
                ns =  4'b0111;
            end

            read_bw:begin
                if(cnt == 6)
                    ns = write_bw;
                else
                    ns = read_bw;
            end
                     
            write_bw:begin
                if(res_addr == 128) 
                    ns = write_bw_fin;
                else 
                    ns = read_bw;
            end

            write_bw_fin:begin
                ns =  write_bw_fin;
            end                   
            default: 
                ns = idle;
        endcase
    end
//=================cnt=============================
always @(posedge clk, negedge reset) begin
    if(!reset)
        cnt <= 0;
    else if((cnt == 16 && ns == read_sti) || cs == write_fw || cs == write_bw || (cs == read_fw && ns == read_bw))
        cnt <= 0;
    else if (ns==write_sti || (cs == write_sti && cnt !=0) || cs == read_fw|| cs == read_bw) 
        cnt <= cnt + 1;
    else 
        cnt <= cnt;
end
//=================sti_address=============================
always @(posedge clk , negedge reset) begin
    if(!reset)
        sti_addr <= 0;
    else if(cs == read_sti && sti_rd)
        sti_addr <= sti_addr + 1;
    else
        sti_addr <= sti_addr;
end
//=================res_address=============================
always @(posedge clk , negedge reset) begin
    if(!reset)
        res_addr <= 0;
    else if((cs == write_sti && res_addr != 16383 ) ||(cs == write_fw && res_addr <= 16254))
        res_addr <= res_addr + 1;
    else if(cs == write_bw && res_addr >= 129)
        res_addr <= res_addr - 1;
    else if(cs == write_sti_finish)
        res_addr <= 129;
    else if(cs == write_fw_fin)
        res_addr <= 16254;
    else if(cs == read_fw && res_addr <= 16254)begin
        case (cnt)
            0: res_addr <= res_addr - 129;
            1: res_addr <= res_addr + 1;
            2: res_addr <= res_addr + 1;
            3: res_addr <= res_addr + 126;
            4: res_addr <= res_addr + 1;
            default: res_addr <= res_addr;
        endcase
    end
    else if(cs == read_bw && res_addr >= 129)begin
        case (cnt)
            0: res_addr <= res_addr + 129;
            1: res_addr <= res_addr - 1;
            2: res_addr <= res_addr - 1;
            3: res_addr <= res_addr - 126;
            4: res_addr <= res_addr - 1;
            default: res_addr <= res_addr;
        endcase
    end
    else 
        res_addr <= res_addr;
end
//=================sti_wr=============================
always @(posedge clk) begin
    if(ns == read_sti)
        sti_rd <= 1;
    else
        sti_rd <= 0;
end
//=================res_wr=============================
always @(posedge clk , negedge reset) begin
    if(!reset)
        res_wr <= 0;
    else if(ns == write_sti  || ns == write_fw|| ns == write_bw)
        res_wr <= 1;
    else
        res_wr <= 0;
end
//=================res_rd=============================
always @(posedge clk , negedge reset) begin
    if(!reset)
        res_rd <= 0;
    else if(ns == read_fw && cnt <=5 || (ns == read_bw && cnt <=5 && cs!= 4))
        res_rd <= 1;
    else
        res_rd <= 0;
end
//=================res_do=============================
always @(posedge clk, negedge reset) begin
    if(!reset)
        res_do <= 0;
    else if(cs == write_sti || ns ==write_sti)
        res_do <=  sti_di[cnt];
    else if(ns == write_fw && res_di!= 0)
        res_do <= min + 1;
    else if(ns == write_fw)
        res_do <= 0;    
    else if(ns == write_bw && res_di!= 0)
        res_do <= min ;
    else if(ns == write_bw)
        res_do <= 0; 
    else
        res_do <= res_do;
end
//===================min=============================
always @(posedge clk) begin
    if(ns == read_fw && cnt == 1)begin
        if(!res_di)
            min = 0;
        else
            min = res_di;
    end
    else if(cs == read_fw && res_di <= min && cnt<= 4) 
        min = res_di;
    else if(ns == read_bw && cnt == 1)begin
        min = res_di + 1;
    end
    else if(cs == read_bw && ((res_di + 1) <= min) && cnt<= 4 && cnt!=0) 
        min = res_di + 1;
    else if(cs == read_bw && cnt== 5 && res_di != 0) begin
        if(res_di <= min)
            min = res_di;
        else 
            min = min;
    end
    else
        min = min;
end
//=================fwpass_finish=============================
always @(*) begin
    if(cs == write_fw_fin)
        fwpass_finish = 1;
    else 
        fwpass_finish = 0;
end
//=================done=============================
always @(*) begin
    if(cs == write_bw_fin)
        done = 1;
    else 
        done = 0;
end
endmodule