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

    signal s_val      : std_logic_vector(9 downto 0);
    signal s_val_prev : unsigned(9 downto 0);
    signal s_led_idx  : integer range 0 to 9;

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
        variable v_cur : unsigned(9 downto 0);
    begin
        if rst = '0' then
            s_val_prev <= (others => '0');
            s_led_idx  <= 0;
        elsif rising_edge(CLK) then
            if ena = '1' then
                v_cur := unsigned(s_val);

                if v_cur /= s_val_prev then
                    if (v_cur = s_val_prev + 1) or ((s_val_prev = to_unsigned(1023, 10)) and (v_cur = 0)) then
                        if s_led_idx = 9 then
                            s_led_idx <= 0;
                        else
                            s_led_idx <= s_led_idx + 1;
                        end if;
                    elsif (v_cur = s_val_prev - 1) or ((s_val_prev = 0) and (v_cur = to_unsigned(1023, 10))) then
                        if s_led_idx = 0 then
                            s_led_idx <= 9;
                        else
                            s_led_idx <= s_led_idx - 1;
                        end if;
                    end if;

                    s_val_prev <= v_cur;
                end if;
            end if;
        end if;
    end process;

    process(s_led_idx, rst)
        variable v_leds : std_logic_vector(9 downto 0);
    begin
        v_leds := (others => '0');
        if rst = '1' then
            v_leds(s_led_idx) := '1';
        end if;
        LEDS <= v_leds;
    end process;

end architecture rtl;
