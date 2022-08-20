-- cpu.vhd: Simple 8-bit CPU (BrainF*ck interpreter)
-- Copyright (C) 2018 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Radek Duchoò
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni z pameti (DATA_RDWR='1') / zapis do pameti (DATA_RDWR='0')
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA obsahuje stisknuty znak klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna pokud IN_VLD='1'
   IN_REQ    : out std_logic;                     -- pozadavek na vstup dat z klavesnice
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- pokud OUT_BUSY='1', LCD je zaneprazdnen, nelze zapisovat,  OUT_WE musi byt '0'
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

 -- zde dopiste potrebne deklarace signalu
    signal pc_mem : std_logic_vector(11 downto 0);
    signal pc_inc : std_logic;
    signal pc_dec : std_logic;
    
    signal ptr_mem : std_logic_vector(9 downto 0);
    signal ptr_inc : std_logic;
    signal ptr_dec : std_logic;

    signal cnt_mem : std_logic_vector(7 downto 0);
    signal cnt_inc : std_logic;
    signal cnt_dec : std_logic;

    signal mux_sel : std_logic_vector(1 downto 0);
    signal mux_mem : std_logic_vector(7 downto 0);

    type fsm_state is (
    FETCH, DECODE,
    INC_PTR, DEC_PTR,
    INC_MEM, INC_MEM2, DEC_MEM, DEC_MEM2,
    WHILE_S, WHILE_S2, WHILE_S3, WHILE_S4,
    WHILE_E, WHILE_E2, WHILE_E3, WHILE_E4, WHILE_E5,
    WRITE, WRITE2, READ,
    COMMENT, COMMENT2, COMMENT3,
    NUM, ABC,
    RET, OTHER
    );
    signal pstate: fsm_state;
    signal nstate: fsm_state;


begin

 -- zde dopiste vlastni VHDL kod dle blokoveho schema

 -- inspirujte se kodem procesoru ze cviceni
    --Programovy citac
    PC: process(CLK, RESET, pc_inc, pc_dec, pc_mem)
    begin
	if (RESET = '1') then
	    pc_mem <= (others => '0');
	elsif (rising_edge(CLK)) then
	    if (pc_inc = '1') then
		pc_mem <= pc_mem + 1;
	    elsif (pc_dec = '1') then
		pc_mem <= pc_mem - 1;
	    end if;
	end if;
    	CODE_ADDR <= pc_mem;
    end process;

    --Ukazatel do pameti
    PTR: process(CLK, RESET, ptr_inc, ptr_dec, ptr_mem)
    begin
	if (RESET = '1') then
	    ptr_mem <= (others => '0');
	elsif (rising_edge(CLK)) then
	    if (ptr_inc = '1') then
		ptr_mem <= ptr_mem + 1;
	    elsif (ptr_dec = '1') then
		ptr_mem <= ptr_mem - 1;
	    end if;
	end if;
    	DATA_ADDR <= ptr_mem;
    end process;

    --Citac zavorek
    CNT: process(CLK, RESET, cnt_inc, cnt_dec, cnt_mem)
    begin
	if (RESET = '1') then
	    cnt_mem <= (others => '0');
	elsif (rising_edge(CLK)) then
	    if (cnt_inc = '1') then
		cnt_mem <= cnt_mem + 1;
	    elsif (cnt_dec = '1') then
		cnt_mem <= cnt_mem - 1;
	    end if;
	end if;
    end process;

    --Multiplexor
    MX: process(IN_DATA, DATA_RDATA, mux_mem, mux_sel)
    begin
	case (mux_sel) is
	    when "00" => DATA_WDATA <= IN_DATA;
	    when "01" => DATA_WDATA <= DATA_RDATA + 1;
	    when "10" => DATA_WDATA <= DATA_RDATA - 1;
    	    when "11" => DATA_WDATA <= mux_mem;
	    when others =>
	end case;
    end process;

    STATE: process(CLK, RESET)
    begin
	if (RESET = '1') then
	    pstate <= FETCH;
	elsif (rising_edge(CLK) and EN = '1') then
	    pstate <= nstate;
	end if;
    end process;

    FSM: process(CODE_DATA, DATA_RDATA, IN_VLD, OUT_BUSY, pstate, cnt_mem)
    begin
	CODE_EN <= '1';
	DATA_EN <= '0';
	DATA_RDWR <= '0';
	IN_REQ <= '0';
	OUT_WE <= '0';

	mux_sel <= "00";
	ptr_inc <= '0';
	ptr_dec <= '0';
	cnt_inc <= '0';
	cnt_dec <= '0';
	pc_inc <= '0';
	pc_dec <= '0';

	case (pstate) is
	    when FETCH =>
		CODE_EN <= '1';
		nstate <= DECODE;

	    when DECODE =>
		case (CODE_DATA) is
		    when X"3E" => nstate <= INC_PTR;
		    when X"3C" => nstate <= DEC_PTR;
		    when X"2B" => nstate <= INC_MEM;
		    when X"2D" => nstate <= DEC_MEM;
		    when X"5B" => nstate <= WHILE_S;
		    when X"5D" => nstate <= WHILE_E;
		    when X"2E" => nstate <= WRITE;
		    when X"2C" => nstate <= READ;
		    when X"23" => nstate <= COMMENT;
		    when X"30" => nstate <= NUM;
		    when X"31" => nstate <= NUM;
		    when X"32" => nstate <= NUM;
		    when X"33" => nstate <= NUM;
		    when X"34" => nstate <= NUM;
		    when X"35" => nstate <= NUM;
		    when X"36" => nstate <= NUM;
		    when X"37" => nstate <= NUM;
		    when X"38" => nstate <= NUM;
		    when X"39" => nstate <= NUM;
		    when X"41" => nstate <= ABC;
		    when X"42" => nstate <= ABC;
		    when X"43" => nstate <= ABC;
		    when X"44" => nstate <= ABC;
		    when X"45" => nstate <= ABC;
		    when X"46" => nstate <= ABC;
		    when X"00" => nstate <= RET;
		    when others => nstate <= OTHER;
		end case;

	    when INC_PTR =>
		ptr_inc <= '1';
		pc_inc <= '1';
		nstate <= FETCH;
	    when DEC_PTR =>
		ptr_dec <= '1';
		pc_inc <= '1';
		nstate <= FETCH;

	    when INC_MEM =>
		DATA_EN <= '1';
		DATA_RDWR <= '1';
		nstate <= INC_MEM2;
	    when INC_MEM2 =>
		DATA_EN <= '1';
		mux_sel <= "01";
		pc_inc <= '1';
		nstate <= FETCH;

	    when DEC_MEM =>
		DATA_EN <= '1';
		DATA_RDWR <= '1';
		nstate <= DEC_MEM2;
	    when DEC_MEM2 =>
		DATA_EN <= '1';
		mux_sel <= "10";
		pc_inc <= '1';
		nstate <= FETCH;

	    when WHILE_S =>
		DATA_EN <= '1';
		DATA_RDWR <= '1';
		pc_inc <= '1';
		nstate <= WHILE_S2;
	    when WHILE_S2 =>
		if (DATA_RDATA = 0) then
		    cnt_inc <= '1';
		    nstate <= WHILE_S3;
		else
		    nstate <= FETCH;
		end if;
	    when WHILE_S3 =>
		if (cnt_mem = 0) then
		    nstate <= FETCH;
		else
		    CODE_EN <= '1';
		    nstate <= WHILE_S4;
		end if;
	    when WHILE_S4 =>
		if (CODE_DATA = X"5B") then
		    cnt_inc <= '1';
		elsif (CODE_DATA = X"5D") then
		    cnt_dec <= '1';
		end if;
		pc_inc <= '1';
		nstate <= WHILE_S3;

	    when WHILE_E =>
		DATA_EN <= '1';
		DATA_RDWR <= '1';
		nstate <= WHILE_E2;
	    when WHILE_E2 =>
		if (DATA_RDATA = 0) then
		    pc_inc <= '1';
		    nstate <= FETCH;
		else
		    cnt_inc <= '1';
		    pc_dec <= '1';
		    nstate <= WHILE_E3;
		end if;
	    when WHILE_E3 =>
		if (cnt_mem = 0) then
		    nstate <= FETCH;
		else
		    CODE_EN <= '1';
		    nstate <= WHILE_E4;
		end if;
	    when WHILE_E4 =>
		if (CODE_DATA = X"5B") then
		    cnt_dec <= '1';
		elsif (CODE_DATA = X"5D") then
		    cnt_inc <= '1';
		end if;
		nstate <= WHILE_E5;
	    when WHILE_E5 =>
		if (cnt_mem = 0) then
		    pc_inc <= '1';
		else
		    pc_dec <= '1';
		end if;
		nstate <= WHILE_E3;

	    when WRITE =>
		if (OUT_BUSY = '1') then
		    nstate <= WRITE;
		else
		    DATA_EN <= '1';
		    DATA_RDWR <= '1';
		    nstate <= WRITE2;
		end if;
	    when WRITE2 =>
		    OUT_DATA <= DATA_RDATA;
		    OUT_WE <= '1';
		    pc_inc <= '1';
		    nstate <= FETCH;
	    when READ =>
		IN_REQ <= '1';
		if (IN_VLD = '0') then
		    nstate <= READ;
		else
		    DATA_EN <= '1';
		    mux_sel <= "00";
		    pc_inc <= '1';
		    nstate <= FETCH;
		end if;

	    when COMMENT =>
		pc_inc <= '1';
		nstate <= COMMENT2;
	    when COMMENT2 =>
		nstate <= COMMENT3;
	    when COMMENT3 =>
		if (CODE_DATA = X"23") then
		    pc_inc <= '1';
		    nstate <= FETCH;
		else
		    nstate <= COMMENT;
		end if;

	    when NUM =>
		DATA_EN <= '1';
		pc_inc <= '1';
		mux_sel <= "11";
		mux_mem <= CODE_DATA(3 downto 0) & "0000"; --nasobky 16 maji posledni 4 cifry 0, prvni cifry lze vzit z "0011XXXX", kde se nachazi 0-9
		nstate <= FETCH;
	    when ABC =>
		DATA_EN <= '1';
		pc_inc <= '1';
		mux_sel <= "11";
		 --viz NUM, ale pricte se 144, respektive kvuli posunu se odecte 16 (zacina se od X"41") a pricte se 10*16=160 (10 do leve poloviny)
		mux_mem <= (CODE_DATA(3 downto 0) & "0000") + 144;
		nstate <= FETCH;

	    when RET =>
		nstate <= RET;

	    when OTHER =>
		pc_inc <= '1';
		nstate <= FETCH;

	    when others =>
	end case;
    end process;
end behavioral;
 
