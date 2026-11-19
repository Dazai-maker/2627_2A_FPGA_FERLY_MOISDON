library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library pll;
use pll.all;

entity telecran is
    port (
        -- FPGA
        i_clk_50 : in std_logic;

        -- HDMI
        io_hdmi_i2c_scl : inout std_logic;
        io_hdmi_i2c_sda : inout std_logic;
        o_hdmi_tx_clk   : out std_logic;
        o_hdmi_tx_d     : out std_logic_vector(23 downto 0);
        o_hdmi_tx_de    : out std_logic;
        o_hdmi_tx_hs    : out std_logic;
        i_hdmi_tx_int   : in std_logic;
        o_hdmi_tx_vs    : out std_logic;

        -- KEYs
        i_rst_n : in std_logic;

        -- LEDs
        o_leds      : out std_logic_vector(9 downto 0);
        o_de10_leds : out std_logic_vector(7 downto 0);

        -- Coder
        i_left_ch_a  : in std_logic;
        i_left_ch_b  : in std_logic;
        i_left_pb    : in std_logic;
        i_right_ch_a : in std_logic;
        i_right_ch_b : in std_logic;
        i_right_pb   : in std_logic
    );
end entity telecran;

architecture rtl of telecran is

    component encodeur
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

    component I2C_HDMI_Config
        port (
            iCLK        : in std_logic;
            iRST_N      : in std_logic;
            I2C_SCLK    : out std_logic;
            I2C_SDAT    : inout std_logic;
            HDMI_TX_INT : in std_logic
        );
    end component;

    component pll
        port (
            refclk   : in std_logic;
            rst      : in std_logic;
            outclk_0 : out std_logic;
            locked   : out std_logic
        );
    end component;

    component hdmi_controler
        generic (
            h_res  : positive := 720;
            v_res  : positive := 480;
            h_sync : positive := 61;
            h_fp   : positive := 58;
            h_bp   : positive := 18;
            v_sync : positive := 5;
            v_fp   : positive := 30;
            v_bp   : positive := 9
        );
        port (
            i_clk           : in std_logic;
            i_rst_n         : in std_logic;
            o_hdmi_hs       : out std_logic;
            o_hdmi_vs       : out std_logic;
            o_hdmi_de       : out std_logic;
            o_pixel_en      : out std_logic;
            o_pixel_address : out natural range 0 to (h_res * v_res - 1);
            o_x_counter     : out natural range 0 to (h_res - 1);
            o_y_counter     : out natural range 0 to (v_res - 1)
        );
    end component;

    constant h_res     : natural := 720;
    constant v_res     : natural := 480;
    constant C_SIZE    : integer := 16;    -- Taille du carre en pixels
    constant C_STEP    : integer := 2;     -- Pas de deplacement par cran
    constant C_ENC_DIV : integer := 27000; -- 27 MHz / 27000 = 1 kHz d'echantillonnage encodeur

    signal s_clk_27 : std_logic;
    signal s_rst_n  : std_logic;

    signal s_enc_cnt : integer range 0 to C_ENC_DIV - 1 := 0;
    signal s_enc_ena : std_logic := '0';

    signal s_hdmi_de   : std_logic;
    signal s_x_counter : natural range 0 to (h_res - 1);
    signal s_y_counter : natural range 0 to (v_res - 1);

    signal s_enc_left_val  : std_logic_vector(9 downto 0);
    signal s_enc_right_val : std_logic_vector(9 downto 0);

    signal s_pos_x : natural range 0 to (h_res - 1) := (h_res / 2) - (C_SIZE / 2);
    signal s_pos_y : natural range 0 to (v_res - 1) := (v_res / 2) - (C_SIZE / 2);

begin
    o_leds      <= s_enc_left_val;
    o_de10_leds <= (others => '0');

    -- PLL 27 MHz
    pll0 : component pll
        port map (
            refclk   => i_clk_50,
            rst      => not(i_rst_n),
            outclk_0 => s_clk_27,
            locked   => s_rst_n
        );

    -- Configuration I2C HDMI
    I2C_HDMI_Config0 : component I2C_HDMI_Config
        port map (
            iCLK        => i_clk_50,
            iRST_N      => i_rst_n,
            I2C_SCLK    => io_hdmi_i2c_scl,
            I2C_SDAT    => io_hdmi_i2c_sda,
            HDMI_TX_INT => i_hdmi_tx_int
        );

    o_hdmi_tx_clk <= s_clk_27;

    -- Controleur HDMI
    hdmi_controler0 : component hdmi_controler
        port map (
            i_clk           => s_clk_27,
            i_rst_n         => s_rst_n,
            o_hdmi_hs       => o_hdmi_tx_hs,
            o_hdmi_vs       => o_hdmi_tx_vs,
            o_hdmi_de       => s_hdmi_de,
            o_pixel_en      => open,
            o_pixel_address => open,
            o_x_counter     => s_x_counter,
            o_y_counter     => s_y_counter
        );

    o_hdmi_tx_de <= s_hdmi_de;

    -- Generateur d'impulsion d'echantillonnage (reduit la frequence vue par les encodeurs)
    process(s_clk_27, s_rst_n)
    begin
        if (s_rst_n = '0') then
            s_enc_cnt <= 0;
            s_enc_ena <= '0';
        elsif rising_edge(s_clk_27) then
            if s_enc_cnt = C_ENC_DIV - 1 then
                s_enc_cnt <= 0;
                s_enc_ena <= '1';
            else
                s_enc_cnt <= s_enc_cnt + 1;
                s_enc_ena <= '0';
            end if;
        end if;
    end process;

    -- Encodeur gauche (horizontal)
    enc_left : component encodeur
        generic map (
            N => 10
        )
        port map (
            A   => i_left_ch_a,
            B   => i_left_ch_b,
            CLK => s_clk_27,
            rst => s_rst_n,
            ena => s_enc_ena,
            val => s_enc_left_val
        );

    -- Encodeur droit (vertical)
    enc_right : component encodeur
        generic map (
            N => 10
        )
        port map (
            A   => i_right_ch_a,
            B   => i_right_ch_b,
            CLK => s_clk_27,
            rst => s_rst_n,
            ena => s_enc_ena,
            val => s_enc_right_val
        );

    -- Mise a jour de (s_pos_x, s_pos_y) en fin de trame active
    process(s_clk_27, s_rst_n)
        variable v_raw_x, v_raw_y   : integer;
        variable v_calc_x, v_calc_y : integer;
    begin
        if (s_rst_n = '0') then
            s_pos_x <= (h_res / 2) - (C_SIZE / 2);
            s_pos_y <= (v_res / 2) - (C_SIZE / 2);
        elsif rising_edge(s_clk_27) then
            if (s_x_counter = h_res - 1) and (s_y_counter = v_res - 1) then
                v_raw_x := to_integer(unsigned(s_enc_left_val));
                v_raw_y := to_integer(unsigned(s_enc_right_val));

                if v_raw_x >= 512 then
                    v_raw_x := v_raw_x - 1024;
                end if;

                if v_raw_y >= 512 then
                    v_raw_y := v_raw_y - 1024;
                end if;

                v_calc_x := ((h_res / 2) - (C_SIZE / 2)) + (v_raw_x * C_STEP);
                v_calc_y := ((v_res / 2) - (C_SIZE / 2)) + (v_raw_y * C_STEP);

                if v_calc_x < 0 then
                    s_pos_x <= 0;
                elsif v_calc_x > integer(h_res) - C_SIZE then
                    s_pos_x <= integer(h_res) - C_SIZE;
                else
                    s_pos_x <= v_calc_x;
                end if;

                if v_calc_y < 0 then
                    s_pos_y <= 0;
                elsif v_calc_y > integer(v_res) - C_SIZE then
                    s_pos_y <= integer(v_res) - C_SIZE;
                else
                    s_pos_y <= v_calc_y;
                end if;
            end if;
        end if;
    end process;

    -- Generation synchrone des pixels 
    process(s_clk_27, s_rst_n)
    begin
        if (s_rst_n = '0') then
            o_hdmi_tx_d <= x"000000";
        elsif rising_edge(s_clk_27) then
            if (s_hdmi_de = '1') and
               (s_x_counter >= s_pos_x) and (s_x_counter < s_pos_x + C_SIZE) and
               (s_y_counter >= s_pos_y) and (s_y_counter < s_pos_y + C_SIZE) then
                o_hdmi_tx_d <= x"FFFFFF";
            else
                o_hdmi_tx_d <= x"000000";
            end if;
        end if;
    end process;

end architecture rtl;
