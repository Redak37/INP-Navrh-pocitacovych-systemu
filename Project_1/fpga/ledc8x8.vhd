library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity ledc8x8 is
port ( -- Sem doplnte popis rozhrani obvodu.
	RESET : in std_logic;
	SMCLK : in std_logic;
	ROW : out std_logic_vector(7 downto 0);
	LED : out std_logic_vector(7 downto 0)
);
end ledc8x8;

architecture main of ledc8x8 is

    -- Sem doplnte definice vnitrnich signalu.
	signal state_cnt : std_logic_vector(20 downto 0) := (others => '0');
	signal ce_cnt : std_logic_vector(11 downto 0) := (others => '0');
	signal led_state: std_logic_vector(7 downto 0) := (others => '0');
	signal row_state : std_logic_vector(7 downto 0) := "10000000";
	signal state: std_logic_vector(1 downto 0) := "00";
	signal ce: std_logic;

begin

    -- Sem doplnte popis obvodu. Doporuceni: pouzivejte zakladni obvodove prvky
    -- (multiplexory, registry, dekodery,...), jejich funkce popisujte pomoci
    -- procesu VHDL a propojeni techto prvku, tj. komunikaci mezi procesy,
    -- realizujte pomoci vnitrnich signalu deklarovanych vyse.

    -- DODRZUJTE ZASADY PSANI SYNTETIZOVATELNEHO VHDL KODU OBVODOVYCH PRVKU,
    -- JEZ JSOU PROBIRANY ZEJMENA NA UVODNICH CVICENI INP A SHRNUTY NA WEBU:
    -- http://merlin.fit.vutbr.cz/FITkit/docs/navody/synth_templates.html.

    -- Nezapomente take doplnit mapovani signalu rozhrani na piny FPGA
    -- v souboru ledc8x8.ucf.

	ce_citac: process(RESET, SMCLK)
	begin
		if RESET = '1' then
			ce_cnt <= (others => '0');
		elsif rising_edge(SMCLK) then
			ce_cnt <= ce_cnt + 1;
		end if;
	end process ce_citac;
	ce <= '1' when ce_cnt = "111000010000" else '0';

	      
	state_citac: process(RESET, SMCLK)
	begin
		if RESET = '1' then
			state_cnt <= (others => '0');
		elsif rising_edge(SMCLK) then
			state_cnt <= state_cnt + 1;
			if  state_cnt = "111000010000000000000" then
				state <= state + 1;
				state_cnt <= (others => '0');
			end if;
		end if;
	end process state_citac;


	row_xchg: process(RESET, SMCLK, ce)
	begin
		if RESET = '1' then
			row_state <= "10000000";
		elsif rising_edge(SMCLK) and ce = '1' then
			row_state <= row_state(0) & row_state(7 downto 1);
		end if;
	end process row_xchg;


	decoder: process(row_state)
	begin
		if state = "00" then
			case row_state is
				when "00000001" => led_state <= "11111000";
				when "00000010" => led_state <= "11110110";
				when "00000100" => led_state <= "11110110";
				when "00001000" => led_state <= "11111000";
				when "00010000" => led_state <= "11111100";
				when "00100000" => led_state <= "11111010";
				when "01000000" => led_state <= "11110110";
				when "10000000" => led_state <= "11101110";
				when others => led_state <= "11111111";
			end case;
		elsif state = "10" then
			case row_state is
				when "00000001" => led_state <= "11111000";
				when "00000010" => led_state <= "11110110";
				when "00000100" => led_state <= "11101110";
				when "00001000" => led_state <= "11101110";
				when "00010000" => led_state <= "11101110";
				when "00100000" => led_state <= "11101110";
				when "01000000" => led_state <= "11110110";
				when "10000000" => led_state <= "11111000";
				when others => led_state <= "11111111";
			end case;
		else
			led_state <= "11111111";
		end if;
	end process decoder; 


	LED <= led_state;
	ROW <= row_state;

end main;
