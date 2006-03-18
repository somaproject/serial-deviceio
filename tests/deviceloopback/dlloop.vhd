-------------------------------------------------------------------------------
-- Title      : SerDesLoop
-- Project    : 
-------------------------------------------------------------------------------
-- File       : serdesloop.vhd
-- Author     : Eric Jonas  <jonas@soma.mit.edu>
-- Company    : 
-- Last update: 2006/03/17
-- Platform   : 
-------------------------------------------------------------------------------
-- Description: Loopback test for serdes
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2006/02/28  1.0      jonas   Created
-------------------------------------------------------------------------------



library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;

library UNISIM;
use UNISIM.VComponents.all;


entity dlloop is
  port (
    REFCLKIN_P   : in  std_logic;
    REFCLKIN_N   : in  std_logic;
    REFCLKOUT : out std_logic; 
    TXCLKIN : in std_logic; 
    TXLOCKED : in  std_logic;
    TXDIN    : in  std_logic_vector(9 downto 0);
    RXIO_P   : out std_logic;
    RXIO_N   : out std_logic;
    LEDPOWER : out std_logic;
    LEDLOCKED : out std_logic;
    LEDVALID : out std_logic
    );

end dlloop;

architecture Behavioral of dlloop is

  component devicelink
    port (
      TXCLKIN  : in  std_logic;
      TXLOCKED : in  std_logic;
      TXDIN    : in  std_logic_vector(9 downto 0);
      TXDOUT   : out std_logic_vector(7 downto 0);
      TXKOUT   : out std_logic;
      CLK      : out std_logic;
      CLK2X    : out std_logic;
      RESET    : out std_logic;
      RXDIN    : in  std_logic_vector(7 downto 0);
      RXKIN    : in  std_logic;
      RXIO_P   : out std_logic;
      RXIO_N   : out std_logic
      );

  end component;

  signal data : std_logic_vector(7 downto 0) := (others => '0');
  signal k : std_logic := '0';
  signal clk, clk2x : std_logic := '0';
  signal RESET : std_logic := '0';

  signal pcnt : std_logic_vector(21 downto 0) := (others => '0');
  

begin  -- Behavioral

  
  devicelink_inst: devicelink
    port map (
      TXCLKIN  => TXCLKIN,
      TXLOCKED => TXLOCKED,
      TXDIN    => TXDIN,
      TXDOUT   => data,
      TXKOUT   => k, 
      CLK      => clk,
      CLK2X    => clk2x,
      RESET    => RESET,
      RXDIN    => data,
      RXKIN    => k, 
      RXIO_P   => RXIO_P,
      RXIO_N   => RXIO_N) ; 
  
  CLKIN_ibufds : IBUFDS
    generic map (
      IOSTANDARD => "DEFAULT")
    port map (
      I          => REFCLKIN_P,
      IB         => REFCLKIN_N,
      O          => REFCLKOUT
      );
  
  ledpowerproc: process (clk)
    
  begin  -- process ledpowerproc
    if rising_edge(clk) then
      pcnt <= pcnt + 1;
      LEDPOWER <= pcnt(21); 
    end if;
  end process ledpowerproc;

  LEDVALID <= '0'; 
  LEDLOCKED <= TXLOCKED; 

  input : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        VALID <= '0';
      else
        bin1  <= din;
        bin2  <= bin1;

        kin1 <= kin;
        kin2 <= kin1;

        if kin2 = '1' and bin2 = X"BC" and
          kin1 = '0' and bin1 = X"00" then
          VALID <= '1';
        elsif kin2 = '0' and bin2 = X"FF" and
          kin1 = '1' and bin1 = X"BC" then
          VALID <= '1';
        elsif kin2 = '0' and kin1 = '0' and bin2 +1 = bin1 then
          VALID <= '1';
        else
          VALID <= '0';
        end if;

      end if;

    end if;

  end process input;

end Behavioral;
