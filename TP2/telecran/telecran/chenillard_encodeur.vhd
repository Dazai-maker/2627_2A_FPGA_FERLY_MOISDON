library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Chenillard_Encodeur is
    port (
        CLK  : in  std_logic;
        rst  : in  std_logic;
        ena  : in  std_logic;
        A    : in  std_logic;
        B    : in  std_logic;
        LEDS : out std_logic_vector(9 downto 0)
    );
end entity Chenillard_Encodeur;

architecture rtl of Chenillard_Encodeur is

    component Encodeur is
        generic (
            N : integer := 10
        );
        port (
            A   : in  std_logic;
            B   : in  std_logic;
            CLK : in  std_logic;
            rst : in  std_logic;
            ena : in  std_logic;
            val : out std_logic_vector(N-1 downto 0)
        );
    end component;

    signal s_val : std_logic_vector(9 downto 0);

begin

    inst_encodeur : Encodeur
        generic map (
            N => 10
        )
        port map (
            A   => A,
            B   => B,
            CLK => CLK,
            rst => rst,
            ena => ena,
            val => s_val
        );

    process(CLK, rst)
        variable v_raw   : integer;
        variable v_index : integer range 0 to 9;
    begin
        if rst = '0' then
            LEDS <= (others => '0');
        elsif rising_edge(CLK) then
            if ena = '1' then
                v_raw := to_integer(unsigned(s_val));

                v_index := v_raw mod 10;

                LEDS          <= (others => '0');
                LEDS(v_index) <= '1';
            end if;
        end if;
    end process;

end architecture rtl;
