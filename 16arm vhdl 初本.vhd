library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity pc16 is
	 Port (
      DB:inout std_logic_vector(15 downto 0);
      AB:buffer std_logic_vector(15 downto 0);
      MUX: in std_logic_vector(0 to 2);
      --CO: in std_logic_vector(31 downto 0);
	 CI: inout std_logic_vector(31 downto 0);
      MCLK,MRD,IOW,IOR,CTRL4,CTRL3,CTRL2,CTRL1,MWR: buffer std_logic;
	 CLK: in std_logic;
      RUN,RESET: in std_logic;
      PRIX,KRIX:in std_logic
	 );
end pc16;

architecture Behavioral of pc16 is
	signal R0,R1,R2,R3,R4,R5,R6,R7:std_logic_vector(15 downto 0);
	--Registers Write Enable
	signal WRR:std_logic_vector(3 downto 0);
	--ALU operand select
	signal SMA,SMB:std_logic_vector(3 downto 0);
	signal R_outA,R_outB:std_logic_vector(15 downto 0);
	--ALU fuction select
	signal SAL:std_logic_vector(2 downto 0);
	signal FF:std_logic_vector(16 downto 0);
	signal ALUOUT:std_logic_vector(15 downto 0);
	signal CY,CCK:std_logic;
	--PC
	signal WPC,PRST,SMPC:std_logic;
	signal PC:std_logic_vector(15 downto 0);
	--IR
	signal IR:std_logic_vector(15 downto 0);
	signal IRE:std_logic;
	--DIN
	signal DIN:std_logic_vector(15 downto 0);
	signal DNG:std_logic;
	--DOUT
	signal DOUT:std_logic_vector(15 downto 0);
	signal DTG,WRE:std_logic;
	--MUXL
	signal SML:std_logic;
	signal MUXLOUT:std_logic_vector(15 downto 0);
	--MUXD
	signal SMD:std_logic;
	signal MUXDOUT:std_logic_vector(15 downto 0);
	--ADR
	signal ADRG:std_logic;
	signal ADR:std_logic_vector(15 downto 0); 

	signal MUXPCOUT:std_logic_vector(15 downto 0);
	signal T:std_logic_vector(2 downto 0);
	signal LDR,STR,MOVH,MOVL,ADD,SUB,BJ,BC,BNK,BNP:std_logic;
	signal ADRGE,TMP:std_logic;
	signal CWR,CWRX,CRD,CRDX:std_logic;
	signal MIR:std_logic_vector(29 downto 0);

begin
	AB <= ADR;
   	--Registers
	process (WRR,MCLK)
	begin
		if (MCLK'event and MCLK = '0') then
			case WRR is
					when "0000" => R0 <= ALUOUT;
					when "0001" => R1 <= ALUOUT;
					when "0010" => R2 <= ALUOUT;
					when "0011" => R3 <= ALUOUT;
					when "0100" => R4 <= ALUOUT;
					when "0101" => R5 <= ALUOUT;
					when "0110" => R6 <= ALUOUT;
					when "0111" => R7 <= ALUOUT;
					when others => R0 <= R0;
			end case;
		end if;
	end process;

	--MUXA    select the 1st operand for ALU
	R_outA <= R0 when SMA = "0000" else
	          R1 when SMA = "0001" else
			R2 when SMA = "0010" else
			R3 when SMA = "0011" else
			R4 when SMA = "0100" else
			R5 when SMA = "0101" else
			R6 when SMA = "0110" else
			R7 when SMA = "0111" else
			PC when SMA = "1000" else
			"0000000000000000";

	--MUXB    select the 2nd operand
	R_outB <= R0 when SMB = "0000" else
	          R1 when SMB = "0001" else
			R2 when SMB = "0010" else
			R3 when SMB = "0011" else
			R4 when SMB = "0100" else
			R5 when SMB = "0101" else
			R6 when SMB = "0110" else
			R7 when SMB = "0111" else
			PC when SMB = "1000" else
			DIN when SMB = "1001" else
			IR when SMB ="1010" else
			"0000000000000000";
	
	--ALU
	FF <= ('0'&R_outA) + ('0'&R_outB) when SAL="000" else
		 ('0'&R_outA) - ('0'&R_outB) when SAL="001" else
		 '0'&R_outA(15 downto 8)&R_outB(7 downto 0) when SAL="010" else
		 '0'&R_outB(7 downto 0)&R_outA(7 downto 0) when SAL="011" else
                 ('0'&R_outA)+("000000"&R_outB(10 downto 0)) when (SAL="100" and R_outB(10)='0') else
                 ('0'&R_outA)+("000000"&R_outB(10 downto 0))-"0000100000000000" when (SAL="100" and R_outB(10)='1')
                 ('0'&R_outA)+("000000000000"&R_outB(4 downto 0)) when SAL="101" else
                 ('0'&R_outB) when SAL="111" else
		 "00000000000000000";
	ALUOUT <= FF(15 downto 0);
			
	--CY
	process (MCLK,CCK)
	begin
		if (MCLK'event and MCLK = '0') then
			if (CCK= '1') then
				CY <= FF(16);
			end if;
		end if;
	end process;

	--PC
	process (WPC,MCLK,PRST)
	begin
		if (PRST ='0') then
			PC <= "0000000000000000";
		elsif (MCLK'event and MCLK='0') then
			if (WPC = '1') then
				PC <= MUXPCOUT;
			end if;
		end if;
	end process;
	PRST <= RESET;

	--MUXPC
	MUXPCOUT <= ALUOUT when SMPC = '0' else
			  MUXLOUT;
	
    	--IR
	process (MCLK,IRE)
	begin
		if (MCLK'event and MCLK = '0') then
			if (IRE = '1') then
				IR <= DB;
			end if;
		end if;
	end process;

	--DIN
	DIN <= DB when (DNG and MCLK)='1' else
		  DIN;

    	-- DOUT
	DOUT <= R_outB when (DTG and MCLK)='1' else
		   DOUT;
	DB <= DOUT when WRE = '1' else
	      "ZZZZZZZZZZZZZZZZ";

    	-- MUXL
	MUXLOUT <= AB when SML = '0' else
			 AB + "0000000000000001";
    	
	-- MUXD
	MUXDOUT <= ALUOUT when SMD = '1' else
			 PC;

	-- ADR
	ADR <= MUXDOUT when (ADRG and MCLK)='1' else
		  ADR;

	--MCLK
	process (MCLK,CLK,RUN,RESET)
	begin
		if (RUN = '0') or (RESET = '0') then 
			MCLK <= '0';
		elsif (CLK'event and CLK = '0') then
			MCLK <= not MCLK;
		end if;
	end process;

	-- T
	process (RESET,MCLK)
	begin
		if (RESET	= '0') then
			T <= "001";
		elsif (MCLK'event and MCLK = '0') then
			if (T="100") then 
				T<="001";
			elsif (T = "010" and (LDR or STR)='1') then 
					T <= "100";
				else 
					T <='0'&T(0)&T(1);
			end if;
		end if;
	end process;
	
	--decode
	LDR	<= '1' when IR(15 downto 11)="00000" else '0';
	STR	<= '1' when IR(15 downto 11)="00001" else '0';
        LSLI    <= '1' when IR(15 downto 11)="00010" else '0';
        MOV     <= '1' when IR(15 downto 11)="00011" else '0';
	MOVL	<= '1' when IR(15 downto 11)="00101" else '0';
	MOVH	<= '1' when IR(15 downto 11)="00100" else '0';
	ADD	<= '1' when IR(15 downto 11)="00110" else '0';
	SUB	<= '1' when IR(15 downto 11)="00111" else '0';
        AND     <= '1' when IR(15 downto 11)="01000" else '0';
        ADDI    <= '1' when IR(15 downto 11)="01001" else '0';
        SUBI    <= '1' when IR(15 downto 11)="01010" else '0';
        BP      <= '1' when IR(15 downto 11)="01011" else '0';
        BK      <= '1' when IR(15 downto 11)="01100" else '0';
        BC      <= '1' when IR(15 downto 11)="01101" else '0';
	BN	<= '1' when IR(15 downto 11)="01110" else '0';
	BL	<= '1' when IR(15 downto 11)="01111" else '0';
	
	
	ADRGE<= '1' when (T(1)='1' and (LDR or STR)='1' ) or (T(0)='1') else '0';
	ADRG	<= ADRGE and MCLK;
	SMD	<= '1' when T(0)='1' else '0';
	SML	<= '1' when T(0)='1' else '0';
	WRR	<= '0'&IR(10 downto 8) when (T(2)='1' and (LDR)='1') or (T(1)='1' and (MOVH or MOVL or ADD or SUB or ADDI or SUBI='1')) else '1111'   
	WPC     <= '1' when T(0)='1' or (T(1)='1' and (BP or BK or BN or BC or BL)='1' and CY='1') or (T(1)='1' and (BN or BL or BC or BK or BP)='1');	  
 	SMPC	<= '1' when ((BP or BN or BK or BC or BL)='1' and T(1)='1'else '0';
	SMA	<= '0'&IR(7 downto 5) when (T(1)='1' and (LDR or STR or ADDI or SUBI or ADD or SUB)='1') else
		   "1000" when (T(1)='1' and (BN or BC or BK or BP or BL)='1') else 
		   '0'&IR(10 downto 8) when (T(1)='1' and (MOVL or MOVH or MOV)='1') else
		   "0000";
	SMB	<= '0'&IR(4 downto 2) when T(1)='1' and (ADD or SUB or ADDI or SUBI)='1' else
		   "1010" when (T(1)='1' and  (LDR or STR or MOV or MOVH or MOVL or BL or BN or BK or BP or BL)='1') else
		   '0'&IR(10 downto 8) when (T(2)='1' and STR='1') else
		   "0000";
	IRE	<= '1' when T(0)='1' else '0';
	SAL	<= "000" when (T(1)='1' and (ADD or ADDI)='1') else
		   "001" when (T(1)='1' and (SUB or SUBI)='1') else 
		   "011" when (T(1)='1' and MOVL='1') else
		   "010" when (T(1)='1' and MOVH='1') else
		   "101" when (T(1)='1' and (LDR or STR)='1') else
		   "111" when (T(2)='1' and (LDR or STR)='1') else
		   "100" ;
	DNG	<= '1' when (T(2)='1' and LDR='1') else '0';
	DTG	<= '1' when (T(2)='1' and STR='1') else '0';
	WRE	<= DTG;
	CWRX <= '0' when (T(2)='1' and STR='1') else
		   '1';
	CRDX <= '0' when T(0)='1' or (T(2)='1' and LDR='1') else
		   '1';	   

	CWR <= CWRX or not MCLK;
	CRD <= CRDX or not MCLK;
	CTRL1 <= CWR or AB(15);
	MWR <= CWR or AB(15);
	IOW <= CWR or not AB(15) or not AB(13);
	IOR <= CRD or not AB(15) or not AB(12);
	MRD <= CRD or AB(15);
	
	MIR(0)<= ADRGE;
	MIR(1)<= SMD;
	MIR(2)<= SML;
	MIR(6 downto 3)<=WRR;
	MIR(7)<= SMPC;
	MIR(8)<= WPC;
	MIR(12 downto 9)<=SMA;
	MIR(16 downto 13)<=SMB;
	MIR(17)<=IRE;
	MIR(20 downto 18)<=SAL;	
	MIR(21)<=DNG;
	MIR(22)<=DTG;
	MIR(23)<=TMP;
	MIR(24)<=CRDX;
	MIR(25)<=CWRX;
	MIR(26)<=CCK;
	MIR(29 downto 27)<=T;	

	CTRL2 <= CY;
	CTRL3 <= KRIX;
	CTRL4 <= PRIX; 
	
	CI(31 downto 16) <= IR when MUX="000" else
				     R0 when MUX="001" else
					R2 when MUX="010" else
					R4 when MUX="011" else
					R6 when MUX="100" else
					PC when MUX="101" else
					R_outB when MUX="110" else
					"00"&MIR(29 downto 16);
	CI(15 downto 0)  <= R1 when MUX="000" else
					R3 when MUX="001" else
					R5 when MUX="010" else
					R7 when MUX="011" else
					AB when MUX="100" else
					DB when MUX="101" else
					R_outA when MUX="110" else
					MIR(15 downto 0);					
end Behavioral;