library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library pll;
use pll.all;

entity telecran is
    port (
        -- FPGA
        i_clk_50: in std_logic;

        -- HDMI
        io_hdmi_i2c_scl        : inout std_logic;
        io_hdmi_i2c_sda        : inout std_logic;
        o_hdmi_tx_clk          : out std_logic;
        o_hdmi_tx_d            : out std_logic_vector(23 downto 0);
        o_hdmi_tx_de           : out std_logic;
        o_hdmi_tx_hs           : out std_logic;
        i_hdmi_tx_int          : in std_logic;
        o_hdmi_tx_vs           : out std_logic;

        -- KEYs
        i_rst_n : in std_logic;
        
        -- LEDs
        o_leds : out std_logic_vector(9 downto 0);
        o_de10_leds : out std_logic_vector(7 downto 0);

        -- Coder
        i_left_ch_a : in std_logic;
        i_left_ch_b : in std_logic;
        i_left_pb : in std_logic;
        i_right_ch_a : in std_logic;
        i_right_ch_b : in std_logic;
        i_right_pb : in std_logic
    );
end entity telecran;

architecture rtl of telecran is

    -- Correction de la largeur de 'val' (10 bits)
    component encodeur
        port (
            A   : in std_logic;
            B   : in std_logic;
            CLK : in std_logic;
            rst : in std_logic;
            val : out std_logic_vector(9 downto 0)
        );
    end component;

    component I2C_HDMI_Config 
        port (
            iCLK : in std_logic;
            iRST_N : in std_logic;
            I2C_SCLK : out std_logic;
            I2C_SDAT : inout std_logic;
            HDMI_TX_INT  : in std_logic
        );
     end component;
     
    component pll 
        port (
            refclk : in std_logic;
            rst : in std_logic;
            outclk_0 : out std_logic;
            locked : out std_logic
        );
    end component;

    component hdmi_controler
        generic (
            h_res     : positive := 720;
            v_res     : positive := 480;
            h_sync    : positive := 61;
            h_fp      : positive := 58;
            h_bp      : positive := 18;
            v_sync    : positive := 5;
            v_fp      : positive := 30;
            v_bp      : positive := 9
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

    constant h_res : natural := 720;
    constant v_res : natural := 480;

    signal s_clk_27 : std_logic;
    signal s_rst_n  : std_logic;

    -- Compteurs x et y issus du contrôleur HDMI
    signal s_x_counter : natural range 0 to (h_res - 1);
    signal s_y_counter : natural range 0 to (v_res - 1);

    -- Signaux de sortie des encodeurs sur 10 bits
    signal s_enc_left_val  : std_logic_vector(9 downto 0);
    signal s_enc_right_val : std_logic_vector(9 downto 0);

    -- Positions x et y pilotées par les encodeurs
    signal s_pos_x     : natural range 0 to (h_res - 1) := h_res / 2;
    signal s_pos_y     : natural range 0 to (v_res - 1) := v_res / 2;

begin
    o_leds <= (others => '0');
    o_de10_leds <= (others => '0');
    
    -- PLL 27 MHz
    pll0 : component pll 
        port map (
            refclk => i_clk_50,
            rst => not(i_rst_n),
            outclk_0 => s_clk_27,
            locked => s_rst_n
        );

    -- Configuration I2C HDMI
    I2C_HDMI_Config0 : component I2C_HDMI_Config 
        port map (
            iCLK => i_clk_50,
            iRST_N => i_rst_n,
            I2C_SCLK => io_hdmi_i2c_scl,
            I2C_SDAT => io_hdmi_i2c_sda,
            HDMI_TX_INT => i_hdmi_tx_int
        );

    o_hdmi_tx_clk <= s_clk_27;

    -- Contrôleur HDMI
    hdmi_controler0 : component hdmi_controler
        port map (
            i_clk           => s_clk_27,
            i_rst_n         => s_rst_n,
            o_hdmi_hs       => o_hdmi_tx_hs,
            o_hdmi_vs       => o_hdmi_tx_vs,
            o_hdmi_de       => o_hdmi_tx_de,
            o_pixel_en      => open,
            o_pixel_address => open,
            o_x_counter     => s_x_counter,
            o_y_counter     => s_y_counter
        );

    -- Encodeur gauche (horizontal)
    enc_left : component encodeur
        port map (
            A   => i_left_ch_a,
            B   => i_left_ch_b,
            CLK => s_clk_27,
            rst => s_rst_n,
            val => s_enc_left_val
        );

    -- Encodeur droit (vertical)
    enc_right : component encodeur
        port map (
            A   => i_right_ch_a,
            B   => i_right_ch_b,
            CLK => s_clk_27,
            rst => s_rst_n,
            val => s_enc_right_val
        );

    -- Conversion des valeurs des encodeurs en positions (avec limitation aux dimensions de l'écran)
    process(s_clk_27, s_rst_n)
        variable v_x, v_y : integer;
    begin
        if (s_rst_n = '0') then
            s_pos_x <= h_res / 2;
            s_pos_y <= v_res / 2;
        elsif rising_edge(s_clk_27) then
            v_x := to_integer(unsigned(s_enc_left_val));
            v_y := to_integer(unsigned(s_enc_right_val));

            if v_x < h_res then
                s_pos_x <= v_x;
            end if;

            if v_y < v_res then
                s_pos_y <= v_y;
            end if;
        end if;
    end process;

    -- Affichage du pixel unique (Blanc si correspondance, Noir sinon)[cite: 2]
    process(s_x_counter, s_y_counter, s_pos_x, s_pos_y)
    begin
        if (s_x_counter = s_pos_x) and (s_y_counter = s_pos_y) then
            o_hdmi_tx_d <= x"FFFFFF"; -- Blanc[cite: 2]
        else
            o_hdmi_tx_d <= x"000000"; -- Noir[cite: 2]
        end if;
    end process;

end architecture rtl;